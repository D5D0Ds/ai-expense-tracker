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

    private fun looksFinancial(body: String): Boolean {
        val lower = body.lowercase()
        return listOf("debited", "spent", "paid", "upi", "credited", "received", "deposit", "refund", "rs.", "inr", "₹").any { lower.contains(it) } &&
            !lower.contains("otp")
    }

    private companion object {
        const val KEY = "pending_sms"
    }
}
