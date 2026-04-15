package com.fladroid.james

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class JamesService : Service() {

    private lateinit var wakeLock: PowerManager.WakeLock

    companion object {
        const val CHANNEL_ID = "james_fg_channel"
        const val NOTIF_ID = 1001
        const val ACTION_START = "com.fladroid.james.START"
        const val ACTION_STOP = "com.fladroid.james.STOP"
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "James::GuardLock")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIF_ID, buildNotification())
        if (!wakeLock.isHeld) wakeLock.acquire()
        isRunning = true
        android.util.Log.d("James", "JamesService started — keepalive active")
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        if (wakeLock.isHeld) wakeLock.release()
        super.onDestroy()
        android.util.Log.d("James", "JamesService stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("James")
            .setContentText("Armed 🔒 — monitoring active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val ch = NotificationChannel(CHANNEL_ID, "James Guard",
            NotificationManager.IMPORTANCE_LOW).apply {
            description = "James motion guard"
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(ch)
    }
}
