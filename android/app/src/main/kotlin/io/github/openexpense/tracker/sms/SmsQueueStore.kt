package io.github.openexpense.tracker.sms

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class SmsQueueStore(context: Context) {
    private val prefs = context.getSharedPreferences("sms_queue", Context.MODE_PRIVATE)

    @Synchronized
    fun enqueue(sender: String, body: String, receivedAt: Long) {
        if (!looksFinancial(body)) return
        val queue = JSONArray(prefs.getString(KEY, "[]"))
        queue.put(
            JSONObject()
                .put("sender", sender)
                .put("body", body)
                .put("receivedAt", receivedAt),
        )
        prefs.edit().putString(KEY, queue.toString()).apply()
    }

    @Synchronized
    fun drain(): List<Map<String, Any>> {
        val queue = JSONArray(prefs.getString(KEY, "[]"))
        prefs.edit().putString(KEY, "[]").apply()
        return (0 until queue.length()).map { index ->
            val item = queue.getJSONObject(index)
            mapOf(
                "sender" to item.optString("sender", "UNKNOWN"),
                "body" to item.optString("body"),
                "receivedAt" to item.optLong("receivedAt"),
            )
        }
    }

    fun looksFinancial(body: String): Boolean {
        val lower = body.lowercase()
        if (nonTransactionPatterns.any { it.containsMatchIn(lower) }) return false
        return transactionPatterns.any { it.containsMatchIn(lower) }
    }

    private companion object {
        const val KEY = "pending_sms"
        val nonTransactionPatterns = listOf(
            Regex("\\botp\\b"),
            Regex("one[- ]time password"),
            Regex("secret otp"),
            Regex("verification code"),
            Regex("do not share"),
            Regex("statement"),
            Regex("total amt due"),
            Regex("minimum due"),
            Regex("min amt due"),
            Regex("bill .* due"),
            Regex("due by"),
            Regex("eligible"),
            Regex("convert .* emi"),
            Regex("flexipay"),
            Regex("maintenance"),
            Regex("reward points"),
            Regex("cashback"),
            Regex("neucoin"),
            Regex("missed call"),
            Regex("transaction reversed"),
            Regex("\\brefund\\b"),
        )
        val transactionPatterns = listOf(
            Regex("\\b(sent|spent|paid|debited|withdrawn|received)\\b[\\s\\S]{0,80}\\b(rs\\.?|inr|₹)"),
            Regex("\\b(rs\\.?|inr|₹)\\s*[0-9][0-9,.]*[\\s\\S]{0,80}\\b(sent|spent|paid|debited|withdrawn|received)\\b"),
        )
    }
}
