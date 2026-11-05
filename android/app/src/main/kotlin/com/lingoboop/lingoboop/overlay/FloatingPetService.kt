package com.lingoboop.lingoboop.overlay

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.lingoboop.lingoboop.MainActivity

class FloatingPetService : Service() {

    private var windowManager: FloatingPetWindowManager? = null

    companion object {
        const val CHANNEL_ID = "lingoboom_floating_companion_channel"
        const val NOTIFICATION_ID = 4040

        const val ACTION_START = "com.lingoboop.overlay.ACTION_START"
        const val ACTION_STOP = "com.lingoboop.overlay.ACTION_STOP"
        const val ACTION_SHOW_OVERLAY = "com.lingoboop.overlay.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.lingoboop.overlay.ACTION_HIDE_OVERLAY"
        const val ACTION_UPDATE_PET = "com.lingoboop.overlay.ACTION_UPDATE_PET"
        const val ACTION_UPDATE_LANGUAGES = "com.lingoboop.overlay.ACTION_UPDATE_LANGUAGES"
        const val ACTION_UPDATE_AUTH_TOKEN = "com.lingoboop.overlay.ACTION_UPDATE_AUTH_TOKEN"
        const val ACTION_UPDATE_VOICE = "com.lingoboop.overlay.ACTION_UPDATE_VOICE"
        const val ACTION_UPDATE_CARD_STATE = "com.lingoboop.overlay.ACTION_UPDATE_CARD_STATE"
        const val ACTION_UPDATE_BACKEND_URL = "com.lingoboop.overlay.ACTION_UPDATE_BACKEND_URL"

        const val EXTRA_PET_KEY = "extra_pet_key"
        const val EXTRA_PET_NAME = "extra_pet_name"
        const val EXTRA_PET_COLOR = "extra_pet_color"
        const val EXTRA_SOURCE_LANG = "extra_source_lang"
        const val EXTRA_TARGET_LANG = "extra_target_lang"
        const val EXTRA_AUTH_TOKEN = "extra_auth_token"
        const val EXTRA_VOICE = "extra_voice"

        @Volatile
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        windowManager = FloatingPetWindowManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SHOW_OVERLAY -> {
                windowManager?.setOverlayVisibility(true)
            }
            ACTION_HIDE_OVERLAY -> {
                windowManager?.setOverlayVisibility(false)
            }
            ACTION_UPDATE_PET -> {
                val key = intent?.getStringExtra(EXTRA_PET_KEY) ?: "fox"
                val name = intent?.getStringExtra(EXTRA_PET_NAME) ?: "Maru"
                val color = intent?.getStringExtra(EXTRA_PET_COLOR) ?: "#c4571c"
                windowManager?.updatePet(key, name, color)
            }
            ACTION_UPDATE_LANGUAGES -> {
                val src = intent?.getStringExtra(EXTRA_SOURCE_LANG) ?: "gu-IN"
                val tgt = intent?.getStringExtra(EXTRA_TARGET_LANG) ?: "en-US"
                val srcName = intent?.getStringExtra("extra_source_lang_name")
                val tgtName = intent?.getStringExtra("extra_target_lang_name")
                windowManager?.updateLanguages(src, tgt, srcName, tgtName)
            }
            ACTION_UPDATE_AUTH_TOKEN -> {
                val token = intent?.getStringExtra(EXTRA_AUTH_TOKEN)
                windowManager?.updateAuthToken(token)
            }
            ACTION_UPDATE_VOICE -> {
                val voice = intent?.getStringExtra(EXTRA_VOICE) ?: "Shivani"
                windowManager?.updateVoice(voice)
            }
            ACTION_UPDATE_BACKEND_URL -> {
                val url = intent?.getStringExtra("backend_url") ?: "http://127.0.0.1:8000"
                windowManager?.updateBackendUrl(url)
            }
            ACTION_UPDATE_CARD_STATE -> {
                val petId = intent?.getStringExtra("pet_id") ?: "fox"
                val petName = intent?.getStringExtra("pet_name") ?: "Maru"
                val petColor = intent?.getStringExtra("pet_color") ?: "#c4571c"
                val voiceId = intent?.getStringExtra("voice_id") ?: "Shivani"
                val srcLang = intent?.getStringExtra("source_language") ?: "gu-IN"
                val tgtLang = intent?.getStringExtra("target_language") ?: "en-US"
                val srcLangName = intent?.getStringExtra("source_language_name")
                val tgtLangName = intent?.getStringExtra("target_language_name")
                val orig = intent?.getStringExtra("original_text") ?: ""
                val trans = intent?.getStringExtra("translated_text") ?: ""
                val corr = intent?.getStringExtra("correction")
                val status = intent?.getStringExtra("status_note")
                val words = intent?.getStringExtra("words")
                val score = if (intent?.hasExtra("pronunciation_score") == true) intent.getDoubleExtra("pronunciation_score", 0.0) else null
                val reqId = intent?.getStringExtra("request_id") ?: System.currentTimeMillis().toString()

                windowManager?.updateCardState(
                    petId = petId,
                    petName = petName,
                    petColor = petColor,
                    voiceId = voiceId,
                    sourceLang = srcLang,
                    targetLang = tgtLang,
                    sourceLangName = srcLangName,
                    targetLangName = tgtLangName,
                    originalText = orig,
                    translatedText = trans,
                    correction = corr,
                    statusNote = status,
                    words = words,
                    score = score,
                    requestId = reqId
                )
            }
            ACTION_START -> {
                val token = intent?.getStringExtra(EXTRA_AUTH_TOKEN)
                if (token != null) {
                    windowManager?.updateAuthToken(token)
                }
                val voice = intent?.getStringExtra(EXTRA_VOICE)
                if (voice != null) {
                    windowManager?.updateVoice(voice)
                }
                val key = intent?.getStringExtra(EXTRA_PET_KEY)
                val name = intent?.getStringExtra(EXTRA_PET_NAME)
                val color = intent?.getStringExtra(EXTRA_PET_COLOR)
                if (key != null && name != null && color != null) {
                    windowManager?.updatePet(key, name, color)
                }

                val src = intent?.getStringExtra(EXTRA_SOURCE_LANG)
                val tgt = intent?.getStringExtra(EXTRA_TARGET_LANG)
                if (src != null && tgt != null) {
                    windowManager?.updateLanguages(src, tgt)
                }

                val notification = buildForegroundNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                windowManager?.showPet()
                if (key != null && name != null && color != null) {
                    windowManager?.updatePet(key, name, color)
                }
                if (MainActivity.isAppInForeground) {
                    windowManager?.setOverlayVisibility(false)
                }
            }
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "LingoBoom Floating Buddy"
            val desc = "Keeps your floating companion active over other apps"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = desc
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, FloatingPetService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LingoBoom Buddy is Active")
            .setContentText("Tap your floating buddy anywhere on screen to practice speech.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Buddy", stopPendingIntent)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        windowManager?.destroy()
        windowManager = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

