package com.lingoboop.lingoboop

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.lingoboop.lingoboop.audio.VoiceActivityRecorder
import com.lingoboop.lingoboop.overlay.FloatingPetService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.lingoboop.app/overlay"
    private val EVENT_CHANNEL = "com.lingoboop.app/overlay_events"
    private val SPEECH_CHANNEL = "com.lingoboop.app/speech"
    private val SPEECH_EVENT_CHANNEL = "com.lingoboop.app/speech_events"

    private var speechEventSink: EventChannel.EventSink? = null

    companion object {
        var eventSink: EventChannel.EventSink? = null
        var isAppInForeground: Boolean = false
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        isAppInForeground = true
    }

    override fun onDestroy() {
        isAppInForeground = false
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    speechEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    speechEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    val lang = call.argument<String>("language") ?: "gu-IN"
                    startSpeechListening(lang)
                    result.success(true)
                }
                "stopListening" -> {
                    stopSpeechListening()
                    result.success(true)
                }
                "cancelListening" -> {
                    cancelSpeechListening()
                    result.success(true)
                }
                "isAvailable" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPerm)
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "startOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        result.error("PERMISSION_DENIED", "Display over other apps permission not granted", null)
                        return@setMethodCallHandler
                    }

                    val petKey = call.argument<String>("petKey") ?: "fox"
                    val petName = call.argument<String>("petName") ?: "Maru"
                    val petColor = call.argument<String>("petColor") ?: "#c4571c"
                    val sourceLang = call.argument<String>("sourceLang") ?: "gu-IN"
                    val targetLang = call.argument<String>("targetLang") ?: "en-US"
                    val voice = call.argument<String>("voice") ?: "Shivani"
                    val authToken = call.argument<String>("authToken")
                    val backendUrl = call.argument<String>("backendUrl") ?: "https://lingoboop-ai.onrender.com"

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_START
                        putExtra(FloatingPetService.EXTRA_PET_KEY, petKey)
                        putExtra(FloatingPetService.EXTRA_PET_NAME, petName)
                        putExtra(FloatingPetService.EXTRA_PET_COLOR, petColor)
                        putExtra(FloatingPetService.EXTRA_SOURCE_LANG, sourceLang)
                        putExtra(FloatingPetService.EXTRA_TARGET_LANG, targetLang)
                        putExtra(FloatingPetService.EXTRA_VOICE, voice)
                        putExtra("backend_url", backendUrl)
                        if (authToken != null) {
                            putExtra(FloatingPetService.EXTRA_AUTH_TOKEN, authToken)
                        }
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    if (isAppInForeground) {
                        val hideIntent = Intent(this, FloatingPetService::class.java).apply {
                            action = FloatingPetService.ACTION_HIDE_OVERLAY
                        }
                        startService(hideIntent)
                    }
                    result.success(true)
                }
                "stopOverlay" -> {
                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "isOverlayRunning" -> {
                    result.success(FloatingPetService.isRunning)
                }
                "updatePet" -> {
                    val petKey = call.argument<String>("petKey") ?: "fox"
                    val petName = call.argument<String>("petName") ?: "Maru"
                    val petColor = call.argument<String>("petColor") ?: "#c4571c"

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_PET
                        putExtra(FloatingPetService.EXTRA_PET_KEY, petKey)
                        putExtra(FloatingPetService.EXTRA_PET_NAME, petName)
                        putExtra(FloatingPetService.EXTRA_PET_COLOR, petColor)
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateLanguages" -> {
                    val sourceLang = call.argument<String>("sourceLang") ?: "gu-IN"
                    val targetLang = call.argument<String>("targetLang") ?: "en-US"
                    val sourceLangName = call.argument<String>("sourceLangName")
                    val targetLangName = call.argument<String>("targetLangName")

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_LANGUAGES
                        putExtra(FloatingPetService.EXTRA_SOURCE_LANG, sourceLang)
                        putExtra(FloatingPetService.EXTRA_TARGET_LANG, targetLang)
                        if (sourceLangName != null) {
                            putExtra("extra_source_lang_name", sourceLangName)
                        }
                        if (targetLangName != null) {
                            putExtra("extra_target_lang_name", targetLangName)
                        }
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateAuthToken" -> {
                    val authToken = call.argument<String>("authToken")
                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_AUTH_TOKEN
                        if (authToken != null) {
                            putExtra(FloatingPetService.EXTRA_AUTH_TOKEN, authToken)
                        }
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateVoice" -> {
                    val voice = call.argument<String>("voice") ?: "Shivani"
                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_VOICE
                        putExtra(FloatingPetService.EXTRA_VOICE, voice)
                    }
                    startService(intent)
                    result.success(true)
                }
                "updateBackendUrl" -> {
                    val backendUrl = call.argument<String>("backendUrl") ?: "https://lingoboop-ai.onrender.com"
                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_BACKEND_URL
                        putExtra("backend_url", backendUrl)
                    }
                    startService(intent)
                    result.success(true)
                }
                "getLatestCardState" -> {
                    val prefs = getSharedPreferences("lingoboop_overlay_prefs", Context.MODE_PRIVATE)
                    val map = mapOf(
                        "petId" to prefs.getString("pet_key", "fox"),
                        "petName" to prefs.getString("pet_name", "Maru"),
                        "petColorHex" to prefs.getString("pet_color", "#c4571c"),
                        "voiceId" to prefs.getString("selected_tts_voice", "Shivani"),
                        "sourceLanguage" to prefs.getString("source_lang", "gu-IN"),
                        "targetLanguage" to prefs.getString("target_lang", "en-US"),
                        "originalText" to prefs.getString("saved_spoken_text", ""),
                        "translatedText" to prefs.getString("saved_translated_text", ""),
                        "correction" to prefs.getString("saved_correction", null),
                        "statusNote" to prefs.getString("saved_status_note", null)
                    )
                    result.success(map)
                }
                "updateCardState" -> {
                    val petId = call.argument<String>("petId") ?: "fox"
                    val petName = call.argument<String>("petName") ?: "Maru"
                    val petColor = call.argument<String>("petColorHex") ?: "#c4571c"
                    val voiceId = call.argument<String>("voiceId") ?: "Shivani"
                    val sourceLang = call.argument<String>("sourceLanguage") ?: "gu-IN"
                    val targetLang = call.argument<String>("targetLanguage") ?: "en-US"
                    val sourceLangName = call.argument<String>("sourceLanguageName") ?: ""
                    val targetLangName = call.argument<String>("targetLanguageName") ?: ""
                    val originalText = call.argument<String>("originalText") ?: ""
                    val translatedText = call.argument<String>("translatedText") ?: ""
                    val correction = call.argument<String>("correction")
                    val statusNote = call.argument<String>("statusNote")
                    val words = call.argument<String>("words")
                    val pronunciationScore = call.argument<Double>("pronunciationScore")
                    val requestId = call.argument<String>("requestId") ?: System.currentTimeMillis().toString()

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_CARD_STATE
                        putExtra("pet_id", petId)
                        putExtra("pet_name", petName)
                        putExtra("pet_color", petColor)
                        putExtra("voice_id", voiceId)
                        putExtra("source_language", sourceLang)
                        putExtra("target_language", targetLang)
                        putExtra("source_language_name", sourceLangName)
                        putExtra("target_language_name", targetLangName)
                        putExtra("original_text", originalText)
                        putExtra("translated_text", translatedText)
                        if (correction != null) putExtra("correction", correction)
                        if (statusNote != null) putExtra("status_note", statusNote)
                        if (words != null) putExtra("words", words)
                        if (pronunciationScore != null) putExtra("pronunciation_score", pronunciationScore)
                        putExtra("request_id", requestId)
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_card", false)) {
            try {
                eventSink?.success(mapOf("event" to "open_card_requested"))
            } catch (_: Exception) {}
        }
    }

    override fun onStart() {
        super.onStart()
        isAppInForeground = true
        if (FloatingPetService.isRunning) {
            val intent = Intent(this, FloatingPetService::class.java).apply {
                action = FloatingPetService.ACTION_HIDE_OVERLAY
            }
            startService(intent)
        }
    }

    override fun onStop() {
        super.onStop()
        isAppInForeground = false
        if (FloatingPetService.isRunning) {
            val intent = Intent(this, FloatingPetService::class.java).apply {
                action = FloatingPetService.ACTION_SHOW_OVERLAY
            }
            startService(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        isAppInForeground = true
        if (FloatingPetService.isRunning) {
            val intent = Intent(this, FloatingPetService::class.java).apply {
                action = FloatingPetService.ACTION_HIDE_OVERLAY
            }
            startService(intent)
        }
    }

    override fun onPause() {
        super.onPause()
        isAppInForeground = false
        if (FloatingPetService.isRunning) {
            val intent = Intent(this, FloatingPetService::class.java).apply {
                action = FloatingPetService.ACTION_SHOW_OVERLAY
            }
            startService(intent)
        }
    }

    private fun startSpeechListening(language: String) {
        // Prevent concurrent microphone access between in-app and overlay
        FloatingPetService.stopOverlayAudioCapture()

        val recorder = VoiceActivityRecorder.getInstance(this)
        recorder.startRecording(object : VoiceActivityRecorder.VadListener {
            override fun onRecordingStarted(startTimeMs: Long) {
                speechEventSink?.success(mapOf("event" to "listening", "language" to language))
            }

            override fun onFirstSpeechDetected(timeMs: Long, dbfs: Double, rms: Double) {
                speechEventSink?.success(
                    mapOf(
                        "event" to "speech_detected",
                        "time" to timeMs,
                        "dbfs" to dbfs,
                        "rms" to rms
                    )
                )
            }

            override fun onSpeechActive(timeMs: Long, dbfs: Double, rms: Double) {
                speechEventSink?.success(mapOf("event" to "rms", "rms" to dbfs))
            }

            override fun onSilenceThresholdReached(timeMs: Long, silenceDurationMs: Long) {
                speechEventSink?.success(
                    mapOf(
                        "event" to "silence_detected",
                        "silence_duration" to silenceDurationMs
                    )
                )
            }

            override fun onRecordingStopped(
                wavFile: File?,
                rawPcm: ByteArray,
                speechDetected: Boolean,
                durationSec: Double
            ) {
                if (wavFile != null && speechDetected && wavFile.exists()) {
                    speechEventSink?.success(
                        mapOf(
                            "event" to "recording_complete",
                            "path" to wavFile.absolutePath,
                            "speech_detected" to true,
                            "duration" to durationSec
                        )
                    )
                } else {
                    speechEventSink?.success(
                        mapOf(
                            "event" to "no_speech",
                            "speech_detected" to false,
                            "duration" to durationSec
                        )
                    )
                }
            }

            override fun onError(message: String) {
                speechEventSink?.success(mapOf("event" to "error", "message" to message))
            }
        })
    }

    private fun stopSpeechListening() {
        VoiceActivityRecorder.getInstance(this).stopRecordingManually()
    }

    private fun cancelSpeechListening() {
        VoiceActivityRecorder.getInstance(this).cancelRecording()
    }
}
