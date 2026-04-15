package com.fladroid.james

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.fladroid.james/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, JamesService::class.java).apply {
                            action = JamesService.ACTION_START
                        }
                        startService(intent)
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
    }
}
