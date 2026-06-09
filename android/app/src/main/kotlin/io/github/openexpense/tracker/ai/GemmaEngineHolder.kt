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

    private companion object {
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
