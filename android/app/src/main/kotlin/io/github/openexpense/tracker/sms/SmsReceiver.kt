package io.github.openexpense.tracker.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val store = SmsQueueStore(context.applicationContext)
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (message in messages) {
            store.enqueue(
                sender = message.displayOriginatingAddress ?: "UNKNOWN",
                body = message.displayMessageBody.orEmpty(),
                receivedAt = message.timestampMillis,
            )
        }
        val serviceIntent = Intent(context, SmsParseService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
