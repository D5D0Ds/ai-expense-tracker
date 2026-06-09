package io.github.openexpense.tracker.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val store = SmsQueueStore(context.applicationContext)
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        messages?.forEach { message ->
            store.enqueue(
                sender = message.displayOriginatingAddress ?: "UNKNOWN",
                body = message.displayMessageBody.orEmpty(),
                receivedAt = message.timestampMillis,
            )
        }
        // All work is already done above; the foreground service was a no-op
        // that caused notification flashes on Android 12+. Removed to comply
        // with foreground service reliability guidelines.
    }
}
