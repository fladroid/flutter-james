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

        // MethodChannel — start/stop service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val threshold = call.argument<Double>("threshold")?.toFloat() ?: 0.25f
                        val cooldown = call.argument<Int>("cooldown") ?: 30
                        val intent = Intent(this, JamesService::class.java).apply {
                            action = JamesService.ACTION_START
                            putExtra(JamesService.EXTRA_THRESHOLD, threshold)
                            putExtra(JamesService.EXTRA_COOLDOWN, cooldown)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(this, JamesService::class.java).apply {
                            action = JamesService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "isRunning" -> result.success(JamesService.isRunning)
                    else -> result.notImplemented()
                }
            }

        // EventChannel — intrusion events from service → Flutter
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
