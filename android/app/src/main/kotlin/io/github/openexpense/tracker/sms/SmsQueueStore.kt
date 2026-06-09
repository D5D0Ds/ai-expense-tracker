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
        // Quick reject: obvious auth messages.
        if (authPatterns.any { it.containsMatchIn(lower) }) return false
        // Layer 1 gate: digits + rupee marker only. The on-device LLM (layer 2)
        // does the real transaction classification.
        return lower.contains(Regex("[0-9]")) &&
            lower.contains(Regex("[₹]|\\b(?:rs\\.?|inr)\\b"))
    }

    private companion object {
        const val KEY = "pending_sms"
        val authPatterns = listOf(
            Regex("\\botp\\b"),
            Regex("one[- ]time password"),
            Regex("verification code"),
        )
    }
}
