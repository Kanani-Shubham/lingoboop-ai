package com.lingoboop.lingoboop

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.lingoboop.lingoboop.overlay.FloatingPetService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.lingoboop.app/overlay"
    private val EVENT_CHANNEL = "com.lingoboop.app/overlay_events"

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
}
