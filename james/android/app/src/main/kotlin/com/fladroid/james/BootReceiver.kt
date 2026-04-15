package com.fladroid.james

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wasArmed = prefs.getBoolean("flutter.autostart_on_boot", false)
            if (wasArmed) {
                val serviceIntent = Intent(context, JamesService::class.java).apply {
                    action = JamesService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    context.startForegroundService(serviceIntent)
                else
                    context.startService(serviceIntent)
            }
        }
    }
}
