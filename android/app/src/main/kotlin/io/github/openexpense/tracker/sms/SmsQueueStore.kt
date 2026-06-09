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
        // Quick reject: obvious auth messages that contain digits but no currency.
        if (authPatterns.any { it.containsMatchIn(lower) }) return false
        // Must contain digits and a currency symbol or word to reach the LLM.
        // The LLM then decides whether this is actually a transaction.
        return lower.contains(Regex("[0-9]")) &&
            lower.contains(Regex("[₹$€£¥¢]|\\b(?:rs\\.?|inr|usd|eur|gbp|jpy|yen|yuan|dollar|euro|pound|amount)\\b"))
    }

    private companion object {
        const val KEY = "pending_sms"
        // Only reject obvious auth messages. Real transaction classification
        // is left to the on-device LLM parser.
        val authPatterns = listOf(
            Regex("\\botp\\b"),
            Regex("one[- ]time password"),
            Regex("verification code"),
        )
    }
}
