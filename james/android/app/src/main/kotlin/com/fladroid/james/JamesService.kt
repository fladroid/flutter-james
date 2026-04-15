package com.fladroid.james

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.PowerManager
import android.os.Build
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

class JamesService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var sensor: Sensor? = null
    private lateinit var wakeLock: PowerManager.WakeLock

    private var threshold = 0.25f
    private var cooldownMs = 30000L
    private var lastAlertTime = 0L

    companion object {
        const val CHANNEL_ID = "james_fg_channel"
        const val NOTIF_ID = 1001
        const val ACTION_START = "com.fladroid.james.START"
        const val ACTION_STOP = "com.fladroid.james.STOP"
        const val EXTRA_THRESHOLD = "threshold"
        const val EXTRA_COOLDOWN = "cooldown"

        // Broadcast back to Flutter
        const val BROADCAST_INTRUSION = "com.fladroid.james.INTRUSION"
        const val EXTRA_MAGNITUDE = "magnitude"

        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "James::GuardLock")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
        }
        threshold = intent?.getFloatExtra(EXTRA_THRESHOLD, 0.25f) ?: 0.25f
        cooldownMs = (intent?.getIntExtra(EXTRA_COOLDOWN, 30) ?: 30) * 1000L

        startForeground(NOTIF_ID, buildNotification("Armed 🔒"))
        if (!wakeLock.isHeld) wakeLock.acquire()
        sensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        isRunning = true
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        sensorManager.unregisterListener(this)
        if (wakeLock.isHeld) wakeLock.release()
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val x = event.values[0]; val y = event.values[1]; val z = event.values[2]
        val mag = sqrt(x*x + y*y + z*z)
        if (mag > threshold) {
            val now = System.currentTimeMillis()
            if (now - lastAlertTime >= cooldownMs) {
                lastAlertTime = now
                // Notify Flutter via broadcast
                val broadcast = Intent(BROADCAST_INTRUSION).apply {
                    putExtra(EXTRA_MAGNITUDE, mag)
                    setPackage(packageName)
                }
                sendBroadcast(broadcast)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("James")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "James Guard",
            NotificationManager.IMPORTANCE_LOW
        ).apply { description = "James motion guard status" }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }
}
