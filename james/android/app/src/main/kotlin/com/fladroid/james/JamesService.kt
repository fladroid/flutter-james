package com.fladroid.james

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.io.File

class JamesService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val CHANNEL_ID = "james_fg_channel"
        const val NOTIF_ID = 1001
        const val ACTION_START = "com.fladroid.james.START"
        const val ACTION_STOP = "com.fladroid.james.STOP"
        var isRunning = false
    }

    private fun log(msg: String) {
        try {
            val f = File(getExternalFilesDir(null), "james_debug.txt")
            f.appendText("${System.currentTimeMillis()} $msg\n")
        } catch (e: Exception) { /* ignore */ }
    }

    override fun onCreate() {
        log("onCreate START")
        super.onCreate()
        log("onCreate super done")
        try {
            createNotificationChannel()
            log("channel created")
        } catch (e: Exception) {
            log("channel ERROR: ${e.message}")
        }
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "James::GuardLock")
            log("wakelock created")
        } catch (e: Exception) {
            log("wakelock ERROR: ${e.message}")
        }
        log("onCreate DONE")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        log("onStartCommand action=${intent?.action}")
        if (intent?.action == ACTION_STOP) {
            log("STOP received")
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startForeground(NOTIF_ID, buildNotification())
            log("startForeground OK")
        } catch (e: Exception) {
            log("startForeground ERROR: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            wakeLock?.let { if (!it.isHeld) it.acquire() }
            log("wakelock acquired")
        } catch (e: Exception) {
            log("wakelock acquire ERROR: ${e.message}")
        }
        isRunning = true
        log("onStartCommand DONE isRunning=true")
        return START_STICKY
    }

    override fun onDestroy() {
        log("onDestroy")
        isRunning = false
        try { wakeLock?.let { if (it.isHeld) it.release() } } catch (e: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        log("buildNotification")
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("James")
            .setContentText("Armed 🔒")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val ch = NotificationChannel(CHANNEL_ID, "James Guard",
            NotificationManager.IMPORTANCE_LOW)
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(ch)
    }
}
