package com.fladroid.james

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.fladroid.james/service"
    private val EVENT_CHANNEL = "com.fladroid.james/intrusion"
    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, JamesService::class.java).apply {
                            action = JamesService.ACTION_START
                            putExtra(JamesService.EXTRA_THRESHOLD,
                                call.argument<Double>("threshold")?.toFloat() ?: 0.25f)
                            putExtra(JamesService.EXTRA_COOLDOWN,
                                call.argument<Int>("cooldown") ?: 30)
                            putExtra(JamesService.EXTRA_NTFY_URL,
                                call.argument<String>("ntfy_url") ?: "")
                            putExtra(JamesService.EXTRA_NTFY_TOKEN,
                                call.argument<String>("ntfy_token") ?: "")
                            putExtra(JamesService.EXTRA_TELEGRAM_TOKEN,
                                call.argument<String>("telegram_token") ?: "")
                            putExtra(JamesService.EXTRA_TELEGRAM_CHAT_ID,
                                call.argument<String>("telegram_chat_id") ?: "")
                            putExtra(JamesService.EXTRA_WEBHOOK_URL,
                                call.argument<String>("webhook_url") ?: "")
                            putExtra(JamesService.EXTRA_CHANNEL,
                                call.argument<String>("notification_channel") ?: "ntfy")
                            putExtra(JamesService.EXTRA_WHAT_GUARDING,
                                call.argument<String>("what_guarding") ?: "")
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    }
                    "stopService" -> {
                        startService(Intent(this, JamesService::class.java).apply {
                            action = JamesService.ACTION_STOP
                        })
                        result.success(true)
                    }
                    "isRunning" -> result.success(JamesService.isRunning)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    receiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context, intent: Intent) {
                            val mag = intent.getFloatExtra(JamesService.EXTRA_MAGNITUDE, 0f)
                            eventSink?.success(mag.toDouble())
                        }
                    }
                    val filter = IntentFilter(JamesService.BROADCAST_INTRUSION)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                        registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    else
                        registerReceiver(receiver, filter)
                }
                override fun onCancel(args: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                    eventSink = null
                }
            })
    }
}
