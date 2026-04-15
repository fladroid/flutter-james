package com.fladroid.james

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import java.io.File

class JamesService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val ACTION_START = "com.fladroid.james.START"
        const val ACTION_STOP = "com.fladroid.james.STOP"
        var isRunning = false
    }

    private fun log(msg: String) {
        try {
            File(getExternalFilesDir(null), "james_debug.txt")
                .appendText("${System.currentTimeMillis()} $msg\n")
        } catch (e: Exception) {}
    }

    override fun onCreate() {
        super.onCreate()
        log("onCreate OK")
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "James::GuardLock")
            log("wakelock created")
        } catch (e: Exception) {
            log("wakelock ERROR: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        log("onStartCommand action=${intent?.action}")
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            wakeLock?.let { if (!it.isHeld) it.acquire() }
            log("wakelock acquired")
        } catch (e: Exception) {
            log("wakelock ERROR: ${e.message}")
        }
        isRunning = true
        log("running=true")
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        try { wakeLock?.let { if (it.isHeld) it.release() } } catch (e: Exception) {}
        log("onDestroy")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
