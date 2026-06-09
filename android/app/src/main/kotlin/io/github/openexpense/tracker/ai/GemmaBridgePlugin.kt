package io.github.openexpense.tracker.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.openexpense.tracker.sms.SmsQueueStore

class GemmaBridgePlugin private constructor(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val engineHolder = GemmaEngineHolder(context.applicationContext)
    private val gemmaChannel = MethodChannel(messenger, "ai_expense_tracker/gemma")
    private val smsChannel = MethodChannel(messenger, "ai_expense_tracker/sms")

    init {
        gemmaChannel.setMethodCallHandler(this)
        smsChannel.setMethodCallHandler { call, result -> onSmsMethod(call, result) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("missing_path", "Model path is required.", null)
                    return
                }
                engineHolder.loadModel(path, result)
            }
            "parseSms" -> {
                val smsBody = call.argument<String>("smsBody")
                if (smsBody.isNullOrBlank()) {
                    result.error("missing_sms", "SMS body is required.", null)
                    return
                }
                engineHolder.parseSms(smsBody, result)
            }
            "diagnostics" -> engineHolder.diagnostics(result)
            else -> result.notImplemented()
        }
    }

    private fun onSmsMethod(call: MethodCall, result: MethodChannel.Result) {
        val store = SmsQueueStore(context.applicationContext)
        when (call.method) {
            "drainPending" -> result.success(store.drain())
            "injectFakeSms" -> {
                val body = call.argument<String>("body").orEmpty()
                store.enqueue("TESTUPI", body, System.currentTimeMillis())
                result.success(null)
            }
            "queryInbox" -> {
                val start = call.argument<Number>("startTimestamp")?.toLong() ?: 0L
                val end = call.argument<Number>("endTimestamp")?.toLong() ?: System.currentTimeMillis()
                try {
                    val messages = querySmsInbox(start, end)
                    result.success(messages)
                } catch (e: Exception) {
                    result.error("query_failed", e.message, null)
                }
            }
            "showSyncNotification" -> {
                val title = call.argument<String>("title").orEmpty()
                val message = call.argument<String>("message").orEmpty()
                val progress = call.argument<Int>("progress") ?: 0
                val max = call.argument<Int>("max") ?: 100
                showSyncNotification(title, message, progress, max)
                result.success(null)
            }
            "cancelSyncNotification" -> {
                cancelSyncNotification()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun showSyncNotification(title: String, message: String, progress: Int, max: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "sms_sync_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SMS Sync Progress",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder.setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(message)
            .setOngoing(progress < max)
            .setProgress(max, progress, false)

        manager.notify(1001, builder.build())
    }

    private fun cancelSyncNotification() {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(1001)
    }

    private fun querySmsInbox(startTimestamp: Long, endTimestamp: Long): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val store = SmsQueueStore(context.applicationContext)
        var scanned = 0
        val cursor = context.contentResolver.query(
            android.net.Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date >= ? AND date <= ?",
            arrayOf(startTimestamp.toString(), endTimestamp.toString()),
            "date DESC"
        )
        cursor?.use { c ->
            val addressIdx = c.getColumnIndex("address")
            val bodyIdx = c.getColumnIndex("body")
            val dateIdx = c.getColumnIndex("date")
            
            if (addressIdx != -1 && bodyIdx != -1 && dateIdx != -1) {
                while (c.moveToNext()) {
                    scanned += 1
                    val sender = c.getString(addressIdx).orEmpty()
                    val body = c.getString(bodyIdx).orEmpty()
                    if (!store.looksFinancial(body)) continue
                    val date = c.getLong(dateIdx)
                    list.add(mapOf(
                        "sender" to sender,
                        "body" to body,
                        "receivedAt" to date
                    ))
                }
            }
        }
        Log.i(TAG, "querySmsInbox scanned=$scanned accepted=${list.size}")
        return list
    }

    companion object {
        private const val TAG = "GemmaBridgePlugin"

        fun register(context: Context, messenger: BinaryMessenger) {
            GemmaBridgePlugin(context, messenger)
        }
    }
}
