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
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.sqrt

class JamesService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var sensor: Sensor? = null
    private lateinit var wakeLock: PowerManager.WakeLock
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var threshold = 0.25f
    private var cooldownMs = 30000L
    private var lastAlertTime = 0L

    // ntfy config — set from Flutter via startService intent
    private var ntfyUrl = ""
    private var ntfyToken = ""
    private var telegramToken = ""
    private var telegramChatId = ""
    private var webhookUrl = ""
    private var channel = "ntfy"
    private var whatGuarding = ""

    companion object {
        const val CHANNEL_ID = "james_fg_channel"
        const val NOTIF_ID = 1001
        const val ACTION_START = "com.fladroid.james.START"
        const val ACTION_STOP = "com.fladroid.james.STOP"
        const val EXTRA_THRESHOLD = "threshold"
        const val EXTRA_COOLDOWN = "cooldown"
        const val EXTRA_NTFY_URL = "ntfy_url"
        const val EXTRA_NTFY_TOKEN = "ntfy_token"
        const val EXTRA_TELEGRAM_TOKEN = "telegram_token"
        const val EXTRA_TELEGRAM_CHAT_ID = "telegram_chat_id"
        const val EXTRA_WEBHOOK_URL = "webhook_url"
        const val EXTRA_CHANNEL = "notification_channel"
        const val EXTRA_WHAT_GUARDING = "what_guarding"

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
        if (intent?.action == ACTION_STOP) { stopSelf(); return START_NOT_STICKY }

        threshold = intent?.getFloatExtra(EXTRA_THRESHOLD, 0.25f) ?: 0.25f
        cooldownMs = (intent?.getIntExtra(EXTRA_COOLDOWN, 30) ?: 30) * 1000L
        ntfyUrl = intent?.getStringExtra(EXTRA_NTFY_URL) ?: ""
        ntfyToken = intent?.getStringExtra(EXTRA_NTFY_TOKEN) ?: ""
        telegramToken = intent?.getStringExtra(EXTRA_TELEGRAM_TOKEN) ?: ""
        telegramChatId = intent?.getStringExtra(EXTRA_TELEGRAM_CHAT_ID) ?: ""
        webhookUrl = intent?.getStringExtra(EXTRA_WEBHOOK_URL) ?: ""
        channel = intent?.getStringExtra(EXTRA_CHANNEL) ?: "ntfy"
        whatGuarding = intent?.getStringExtra(EXTRA_WHAT_GUARDING) ?: ""

        startForeground(NOTIF_ID, buildNotification("Armed 🔒"))
        if (!wakeLock.isHeld) wakeLock.acquire()
        sensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        isRunning = true

        // Debug log — what did we receive?
        android.util.Log.d("James", "=== SERVICE START ===")
        android.util.Log.d("James", "channel=$channel")
        android.util.Log.d("James", "ntfyUrl=$ntfyUrl")
        android.util.Log.d("James", "ntfyToken=${if (ntfyToken.isNotEmpty()) "SET(${ntfyToken.length}ch)" else "EMPTY"}")
        android.util.Log.d("James", "threshold=$threshold cooldown=${cooldownMs}ms")

        // Send armed notification directly from Kotlin
        val guardMsg = if (whatGuarding.isNotEmpty()) " · $whatGuarding" else ""
        sendAlert("James Armed 🔒$guardMsg", "low", "lock")

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        sensorManager.unregisterListener(this)
        if (wakeLock.isHeld) wakeLock.release()
        serviceScope.cancel()
        sendAlert("James Disarmed 🔓", "low", "unlock")
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val x = event.values[0]; val y = event.values[1]; val z = event.values[2]
        val mag = sqrt(x*x + y*y + z*z)

        if (mag > threshold) {
            val now = System.currentTimeMillis()
            if (now - lastAlertTime >= cooldownMs) {
                lastAlertTime = now

                // Send intrusion alert directly from Kotlin
                val guardMsg = if (whatGuarding.isNotEmpty()) "\nGuarding: $whatGuarding" else ""
                sendAlert(
                    "⚠️ Intrusion! ${String.format("%.2f", mag)} m/s²$guardMsg",
                    "urgent", "warning,bell"
                )

                // Also broadcast to Flutter for UI update
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

    // --- Notification sending directly from Kotlin ---

    private fun sendAlert(message: String, priority: String, tags: String) {
        serviceScope.launch {
            try {
                when (channel) {
                    "ntfy" -> sendNtfy(message, priority, tags)
                    "telegram" -> sendTelegram(message)
                    "webhook" -> sendWebhook(message, priority)
                }
            } catch (e: Exception) {
                // Silent fail — log only
                android.util.Log.e("James", "Alert send failed: ${e.message}")
            }
        }
    }

    private fun sendNtfy(message: String, priority: String, tags: String) {
        android.util.Log.d("James", "sendNtfy: url=$ntfyUrl token=${if (ntfyToken.isNotEmpty()) "SET" else "EMPTY"} msg=$message")
        if (ntfyUrl.isEmpty()) { android.util.Log.w("James", "ntfyUrl EMPTY — skip"); return }
        val conn = URL(ntfyUrl).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 5000
        conn.readTimeout = 5000
        conn.setRequestProperty("Priority", priority)
        if (tags.isNotEmpty()) conn.setRequestProperty("Tags", tags)
        if (ntfyToken.isNotEmpty()) conn.setRequestProperty("Authorization", "Bearer $ntfyToken")
        conn.doOutput = true
        conn.outputStream.write(message.toByteArray())
        conn.responseCode // execute
        conn.disconnect()
    }

    private fun sendTelegram(message: String) {
        if (telegramToken.isEmpty() || telegramChatId.isEmpty()) return
        val url = "https://api.telegram.org/bot$telegramToken/sendMessage"
        val body = """{"chat_id":"$telegramChatId","text":"$message"}"""
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 5000
        conn.readTimeout = 5000
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.outputStream.write(body.toByteArray())
        conn.responseCode
        conn.disconnect()
    }

    private fun sendWebhook(message: String, priority: String) {
        if (webhookUrl.isEmpty()) return
        val body = """{"message":"$message","priority":"$priority"}"""
        val conn = URL(webhookUrl).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 5000
        conn.readTimeout = 5000
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.outputStream.write(body.toByteArray())
        conn.responseCode
        conn.disconnect()
    }

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
            CHANNEL_ID, "James Guard", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "James motion guard status" }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }
}
