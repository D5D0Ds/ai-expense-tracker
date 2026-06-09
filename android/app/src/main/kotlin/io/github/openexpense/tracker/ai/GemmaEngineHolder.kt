package io.github.openexpense.tracker.ai

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.BenchmarkInfo
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject

class GemmaEngineHolder(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val mutex = Mutex()

    private var engine: Engine? = null
    @Volatile private var modelPath: String? = null
    @Volatile private var backendName: String? = null
    @Volatile private var initTimeMs: Long? = null
    @Volatile private var lastParseTimeMs: Long? = null
    @Volatile private var lastTimeToFirstTokenSeconds: Double? = null
    @Volatile private var lastDecodeTokensPerSecond: Double? = null
    @Volatile private var lastError: String? = null

    fun loadModel(path: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                val file = File(path)
                if (!file.exists()) {
                    fail(result, "missing_model", "Model file does not exist.")
                    return@launch
                }

                mutex.withLock {
                    if (modelPath == path) {
                        return@withLock
                    }

                    engine?.close()
                    engine = null

                    // Validate the model by creating and immediately closing the engine.
                    // Do not keep it resident in memory; load on-demand during parse.
                    val (validatedEngine, validatedBackend) = createEngine(path)
                    validatedEngine.close()

                    modelPath = path
                    backendName = validatedBackend
                    lastError = null
                }
                ok(result, true)
            } catch (error: Throwable) {
                lastError = error.message ?: "Model initialization failed."
                fail(
                    result,
                    "model_init_failed",
                    error.message ?: "Model initialization failed.",
                )
            }
        }
    }

    fun parseSms(smsBody: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                val parsed = mutex.withLock {
                    // Load engine on-demand so it is only resident while parsing.
                    val activeEngine = engine ?: run {
                        val path = modelPath
                        if (path != null) {
                            try {
                                val (loadedEngine, loadedBackend) = createEngine(path)
                                engine = loadedEngine
                                backendName = loadedBackend
                                loadedEngine
                            } catch (e: Throwable) {
                                throw IllegalStateException(
                                    e.message ?: "Failed to load model for parsing.",
                                    e,
                                )
                            }
                        } else null
                    }

                    if (activeEngine == null) {
                        throw IllegalStateException("Gemma model is not loaded.")
                    }

                    val parseResult = runCatching {
                        parseWithGemma(activeEngine, smsBody)
                    }.getOrElse { error ->
                        lastError = error.message ?: "Gemma parsing failed."
                        throw error
                    }

                    // Release engine memory immediately after parsing.
                    engine?.close()
                    engine = null

                    parseResult
                }
                ok(result, parsed.toString())
            } catch (error: Throwable) {
                lastError = error.message ?: "Unable to parse SMS."
                fail(result, "parse_failed", error.message ?: "Unable to parse SMS.")
            }
        }
    }

    fun diagnostics(result: MethodChannel.Result) {
        scope.launch {
            val payload = mutex.withLock {
                hashMapOf(
                    "loaded" to (modelPath != null),
                    "backend" to backendName,
                    "modelPath" to modelPath,
                    "initTimeMs" to initTimeMs,
                    "lastParseTimeMs" to lastParseTimeMs,
                    "timeToFirstTokenSeconds" to lastTimeToFirstTokenSeconds,
                    "decodeTokensPerSecond" to lastDecodeTokensPerSecond,
                    "lastError" to lastError,
                )
            }
            ok(result, payload)
        }
    }

    private fun createEngine(path: String): Pair<Engine, String> {
        val cacheDirectory = File(context.cacheDir, "litertlm").apply {
            mkdirs()
        }
        val backend = Backend.GPU()
        val created = Engine(
            EngineConfig(
                        modelPath = path,
                        backend = backend,
                        visionBackend = backend,
                        audioBackend = Backend.CPU(),
                        maxNumTokens = 512,
                        maxNumImages = null,
                        cacheDir = cacheDirectory.absolutePath,
                    ),
        )
        val startedAt = SystemClock.elapsedRealtime()
        created.initialize()
        initTimeMs = SystemClock.elapsedRealtime() - startedAt
        return created to "GPU"
    }

    @OptIn(ExperimentalApi::class)
    private fun parseWithGemma(engine: Engine, smsBody: String): JSONObject {
        val conversation = engine.createConversation(
            ConversationConfig(
                systemInstruction = Contents.of(systemPrompt),
                samplerConfig = SamplerConfig(
                    topK = 1,
                    topP = 0.0,
                    temperature = 0.0,
                    seed = 7,
                ),
                automaticToolCalling = false,
            ),
        )
        try {
            val startedAt = SystemClock.elapsedRealtime()
            val message = conversation.sendMessage(buildUserPrompt(smsBody))
            lastParseTimeMs = SystemClock.elapsedRealtime() - startedAt
            runCatching {
                val benchmark: BenchmarkInfo = conversation.getBenchmarkInfo()
                lastTimeToFirstTokenSeconds = benchmark.timeToFirstTokenInSecond
                lastDecodeTokensPerSecond = benchmark.lastDecodeTokensPerSecond
            }.onFailure {
                lastTimeToFirstTokenSeconds = null
                lastDecodeTokensPerSecond = null
            }
            val rendered = conversation.renderMessageIntoString(message, emptyMap())
            lastError = null
            return mergeGemmaOutput(
                listOf(
                    rendered,
                    message.contents.toString(),
                    message.channels.values.joinToString("\n"),
                ),
            )
        } finally {
            conversation.close()
        }
    }

    private fun mergeGemmaOutput(modelTexts: List<String>): JSONObject {
        val jsonText = modelTexts.firstNotNullOfOrNull { extractJson(it) }
            ?: run {
                val preview = modelTexts.joinToString(" | ")
                    .replace(Regex("\\s+"), " ")
                    .take(180)
                Log.w(TAG, "Gemma did not return JSON. Output preview: $preview")
                throw IllegalStateException("Gemma did not return strict JSON.")
            }

        return runCatching {
            JSONObject(jsonText)
        }.getOrElse {
            Log.w(TAG, "Gemma returned invalid JSON: ${jsonText.take(180)}", it)
            throw IllegalStateException("Gemma returned invalid JSON.", it)
        }
    }

    private fun extractJson(text: String): String? {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        if (start == -1 || end <= start) return null
        return text.substring(start, end + 1)
    }

    private fun parseWithHeuristics(smsBody: String): JSONObject {
        val normalized = smsBody.replace(",", " ")
        val amount = extractAmount(normalized)
        val direction = directionFor(normalized)
        val payee = extractPayee(normalized, direction)
        val isPersonLike = looksLikePerson(payee)
        val transactionKind = transactionKindFor(payee, normalized, direction, isPersonLike)
        val paymentMethod = paymentMethodFor(normalized)
        val bank = detectBank(normalized)
        val suffix = extractSuffix(normalized)
        val upiHandle = upiHandlePattern.find(normalized)?.value
        val account = accountPattern.find(normalized)?.value
        val sourceLabel = sourceLabelFor(paymentMethod, bank, suffix, upiHandle)
        val fundingSourceLabel = fundingSourceLabelFor(paymentMethod, bank, suffix, sourceLabel)
        return JSONObject()
            .put("amount", amount)
            .put("currency", "INR")
            .put("date", java.time.Instant.now().toString())
            .put("payee", payee)
            .put("category", categoryFor(payee, normalized, transactionKind))
            .put("transactionKind", transactionKind)
            .put("paymentMethod", paymentMethod)
            .put("confidence", confidenceFor(sourceLabel, account, direction))
            .put("reason", reasonFor(transactionKind, paymentMethod, sourceLabel))
            .put("isPersonLike", isPersonLike)
            .put("accountHint", account)
            .put("sourceLabel", sourceLabel)
            .put("fundingSourceLabel", fundingSourceLabel)
    }

    private fun extractAmount(text: String): Double {
        return amountPattern.find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.replace(Regex("[^0-9.]"), "")
            ?.toDoubleOrNull() ?: 0.0
    }

    private fun directionFor(text: String): MoneyDirection {
        val lower = text.lowercase()
        return when {
            hasAny(lower, "credited", "credit for", "received", "deposit", "refund", "reversal") -> MoneyDirection.Incoming
            hasAny(lower, "debited", "paid", "spent", "withdrawn", "sent", "purchase", "transferred to", "upi") -> MoneyDirection.Outgoing
            else -> MoneyDirection.Unknown
        }
    }

    private fun extractPayee(text: String, direction: MoneyDirection): String {
        val patterns = when (direction) {
            MoneyDirection.Incoming -> listOf(
                Regex("(?:from|received from|credited by)\\s+([A-Z0-9 .&@_-]{3,40})", RegexOption.IGNORE_CASE),
                Regex("(?:UPI|IMPS|NEFT)\\s+from\\s+([A-Z0-9 .&@_-]{3,40})", RegexOption.IGNORE_CASE),
            )
            MoneyDirection.Outgoing -> listOf(
                Regex("(?:to|at|paid to|sent to|towards)\\s+([A-Z0-9 .&@_-]{3,40})", RegexOption.IGNORE_CASE),
                Regex("(?:UPI/P2M|UPI/P2A|UPI)\\s+([A-Z0-9 .&@_-]{3,40})", RegexOption.IGNORE_CASE),
            )
            MoneyDirection.Unknown -> listOf(
                Regex("(?:to|at|paid to|sent to|towards|from|received from)\\s+([A-Z0-9 .&@_-]{3,40})", RegexOption.IGNORE_CASE),
            )
        }
        for (pattern in patterns) {
            val value = pattern.find(text)?.groupValues?.getOrNull(1)?.trim()
            if (!value.isNullOrBlank()) {
                return value
                    .split(Regex("\\s+(?:on|ref|txn|upi|from|via|avl|bal|info|id)\\s+", RegexOption.IGNORE_CASE))
                    .first()
                    .replace(Regex("\\s+"), " ")
                    .trim()
            }
        }
        return "Unknown payee"
    }

    private fun transactionKindFor(
        payee: String,
        body: String,
        direction: MoneyDirection,
        isPersonLike: Boolean,
    ): String {
        val text = "$payee $body".lowercase()
        return when {
            direction == MoneyDirection.Incoming && (isPersonLike || hasAny(text, "friend", "family", "loan")) -> "Borrowed"
            direction == MoneyDirection.Outgoing && (isPersonLike || hasAny(text, "friend", "family")) -> "Lent"
            else -> "Expense"
        }
    }

    private fun paymentMethodFor(body: String): String {
        val text = body.lowercase()
        return when {
            upiHandlePattern.containsMatchIn(body) || text.contains("upi") -> "UPI"
            text.contains("credit card") || text.contains("creditcard") -> "Credit card"
            text.contains("debit card") || text.contains("debitcard") -> "Debit card"
            accountPattern.containsMatchIn(body) || text.contains("account") -> "Account"
            text.contains("cash") -> "Cash"
            else -> "Other"
        }
    }

    private fun categoryFor(payee: String, body: String, transactionKind: String): String {
        if (transactionKind != "Expense") return "Transfer"
        val text = "$payee $body".lowercase()
        return when {
            hasAny(text, "swiggy", "zomato", "restaurant", "cafe", "food", "grocery") -> "Food"
            hasAny(text, "amazon", "flipkart", "myntra", "shopping", "store") -> "Shopping"
            hasAny(text, "uber", "ola", "metro", "irctc", "fuel", "petrol", "travel") -> "Travel"
            hasAny(text, "airtel", "jio", "electricity", "bill", "recharge") -> "Bills"
            hasAny(text, "apollo", "pharmacy", "hospital", "clinic", "medicine") -> "Health"
            else -> "Other"
        }
    }

    private fun detectBank(body: String): String? {
        val lower = body.lowercase()
        return bankKeywords.entries.firstOrNull { (_, keywords) ->
            keywords.any(lower::contains)
        }?.key
    }

    private fun extractSuffix(body: String): String? {
        return cardSuffixPattern.find(body)?.groupValues?.getOrNull(1)
            ?: accountSuffixPattern.find(body)?.groupValues?.getOrNull(1)
    }

    private fun sourceLabelFor(
        paymentMethod: String,
        bank: String?,
        suffix: String?,
        upiHandle: String?,
    ): String? {
        val maskedSuffix = suffix?.let { "•$it" }
        return when (paymentMethod) {
            "Credit card" -> listOfNotNull(bank, "Credit card", maskedSuffix).joinToString(" ")
            "Debit card" -> listOfNotNull(bank, "Debit card", maskedSuffix).joinToString(" ")
            "Account" -> listOfNotNull(bank, "Account", maskedSuffix).joinToString(" ")
            "UPI" -> listOfNotNull(bank, "UPI", upiHandle?.lowercase()?.let { "· $it" }).joinToString(" ")
            "Cash" -> "Cash"
            else -> bank
        }?.takeIf { it.isNotBlank() }
    }

    private fun fundingSourceLabelFor(
        paymentMethod: String,
        bank: String?,
        suffix: String?,
        sourceLabel: String?,
    ): String? {
        val maskedSuffix = suffix?.let { "•$it" }
        return when (paymentMethod) {
            "UPI", "Debit card", "Account" -> listOfNotNull(bank, "Account", maskedSuffix).joinToString(" ")
            "Credit card" -> sourceLabel
            "Cash" -> "Cash wallet"
            else -> sourceLabel
        }?.takeIf { it.isNotBlank() }
    }

    private fun confidenceFor(
        sourceLabel: String?,
        accountHint: String?,
        direction: MoneyDirection,
    ): Double {
        return when {
            sourceLabel != null && accountHint != null -> 0.76
            sourceLabel != null || accountHint != null -> 0.69
            direction != MoneyDirection.Unknown -> 0.63
            else -> 0.56
        }
    }

    private fun reasonFor(
        transactionKind: String,
        paymentMethod: String,
        sourceLabel: String?,
    ): String {
        val subject = when (transactionKind) {
            "Lent" -> "person-to-person transfer"
            "Borrowed" -> "borrowed money"
            else -> "expense"
        }
        return if (sourceLabel != null) {
            "Fallback parser matched a $subject on $paymentMethod using $sourceLabel."
        } else {
            "Fallback parser matched a $subject on $paymentMethod."
        }
    }

    private fun hasAny(text: String, vararg keywords: String): Boolean {
        return keywords.any(text::contains)
    }

    private fun looksLikePerson(payee: String): Boolean {
        val words = payee.split(Regex("\\s+")).filter { Regex("^[A-Za-z]+$").matches(it) }
        val business = Regex("(PVT|LTD|STORE|MART|BANK)", RegexOption.IGNORE_CASE).containsMatchIn(payee)
        return words.size in 2..4 && !business
    }

    private enum class MoneyDirection {
        Outgoing,
        Incoming,
        Unknown,
    }

    private companion object {
        private val amountPattern =
            Regex("(?:INR|Rs\\.?|₹)\\s*([0-9][0-9, ]*(?:\\.[0-9]{1,2})?)", RegexOption.IGNORE_CASE)
        private val accountPattern =
            Regex("(?:A/c|Acct|account)\\s*(?:no\\.?\\s*)?(?:ending|XX|xx|X+|x+|\\*+)?\\s*[0-9]{2,6}", RegexOption.IGNORE_CASE)
        private val accountSuffixPattern =
            Regex("(?:A/c|Acct|account)\\s*(?:no\\.?\\s*)?(?:ending|XX|xx|X+|x+|\\*+)?\\s*([0-9]{2,6})", RegexOption.IGNORE_CASE)
        private val cardSuffixPattern =
            Regex("(?:credit|debit)?\\s*card(?:\\s*(?:ending|xx|XX|x+|\\*+))?\\s*([0-9]{2,6})", RegexOption.IGNORE_CASE)
        private val upiHandlePattern =
            Regex("[A-Za-z0-9._-]{2,}@[A-Za-z]{2,}", RegexOption.IGNORE_CASE)
        private val bankKeywords =
            mapOf(
                "HDFC" to listOf("hdfc"),
                "Axis" to listOf("axis"),
                "SBI" to listOf("sbi", "state bank"),
                "HSBC" to listOf("hsbc"),
                "Federal" to listOf("federal"),
                "Kotak" to listOf("kotak"),
                "ICICI" to listOf("icici"),
                "Yes Bank" to listOf("yes bank"),
            )
        private val systemPrompt =
            """
            Non-thinking mode. Do not analyze out loud. Do not write thoughts, explanations, markdown, or prose.
            Parse Indian bank/UPI SMS and output exactly one minified JSON object.
            Keys: amount,currency,date,payee,category,transactionKind,paymentMethod,confidence,reason,isPersonLike,accountHint,sourceLabel,fundingSourceLabel.
            Enums: category Food|Shopping|Travel|Bills|Health|Entertainment|Transfer|Other; transactionKind Expense|Lent|Borrowed; paymentMethod Credit card|Debit card|Account|UPI|Cash|Other.
            Use INR unless explicit. Use null for unknown optional fields. Keep reason under 8 words. Person transfers use Transfer.
            """.trimIndent()

        private const val TAG = "GemmaEngineHolder"
    }

    private fun buildUserPrompt(smsBody: String): String {
        return buildString {
            appendLine("Current time: ${java.time.OffsetDateTime.now()}")
            appendLine("Return JSON only. Begin with { and end with }.")
            appendLine("SMS:")
            append(smsBody)
        }
    }

    private fun ok(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun fail(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }
}
