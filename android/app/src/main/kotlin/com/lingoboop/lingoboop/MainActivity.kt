package com.lingoboop.lingoboop

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.lingoboop.lingoboop.overlay.FloatingPetService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.lingoboop.app/overlay"
    private val EVENT_CHANNEL = "com.lingoboop.app/overlay_events"
    private val SPEECH_CHANNEL = "com.lingoboop.app/speech"
    private val SPEECH_EVENT_CHANNEL = "com.lingoboop.app/speech_events"

    private var speechRecognizer: SpeechRecognizer? = null
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
                    result.success(SpeechRecognizer.isRecognitionAvailable(this))
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
                    val authToken = call.argument<String>("authToken")

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_START
                        putExtra(FloatingPetService.EXTRA_PET_KEY, petKey)
                        putExtra(FloatingPetService.EXTRA_PET_NAME, petName)
                        putExtra(FloatingPetService.EXTRA_PET_COLOR, petColor)
                        putExtra(FloatingPetService.EXTRA_SOURCE_LANG, sourceLang)
                        putExtra(FloatingPetService.EXTRA_TARGET_LANG, targetLang)
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

                    val intent = Intent(this, FloatingPetService::class.java).apply {
                        action = FloatingPetService.ACTION_UPDATE_LANGUAGES
                        putExtra(FloatingPetService.EXTRA_SOURCE_LANG, sourceLang)
                        putExtra(FloatingPetService.EXTRA_TARGET_LANG, targetLang)
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
        Handler(Looper.getMainLooper()).post {
            try {
                speechRecognizer?.destroy()
                val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
                speechRecognizer = recognizer

                recognizer.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        speechEventSink?.success(mapOf("event" to "ready"))
                    }

                    override fun onBeginningOfSpeech() {
                        speechEventSink?.success(mapOf("event" to "speech_started"))
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        speechEventSink?.success(mapOf("event" to "rms", "rms" to rmsdB))
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        speechEventSink?.success(mapOf("event" to "end_of_speech"))
                    }

                    override fun onError(error: Int) {
                        speechEventSink?.success(mapOf("event" to "error", "error" to error))
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = if (!matches.isNullOrEmpty()) matches[0] else ""
                        speechEventSink?.success(mapOf("event" to "final", "text" to text))
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = if (!matches.isNullOrEmpty()) matches[0] else ""
                        if (text.isNotEmpty()) {
                            speechEventSink?.success(mapOf("event" to "partial", "text" to text))
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                recognizer.startListening(intent)
            } catch (e: Exception) {
                speechEventSink?.success(mapOf("event" to "error", "message" to (e.message ?: "Failed to start speech recognizer")))
            }
        }
    }

    private fun stopSpeechListening() {
        Handler(Looper.getMainLooper()).post {
            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {}
        }
    }

    private fun cancelSpeechListening() {
        Handler(Looper.getMainLooper()).post {
            try {
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (_: Exception) {}
        }
    }
}
