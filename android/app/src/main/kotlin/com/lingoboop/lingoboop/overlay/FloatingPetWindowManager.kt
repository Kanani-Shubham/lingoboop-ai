package com.lingoboop.lingoboop.overlay

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Base64
import android.util.DisplayMetrics
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import com.lingoboop.lingoboop.MainActivity
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.roundToInt

class FloatingPetWindowManager(private val context: Context) : TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "FloatingPetOverlay"
    }

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val prefs: SharedPreferences =
        context.getSharedPreferences("lingoboom_overlay_prefs", Context.MODE_PRIVATE)

    private var petView: FrameLayout? = null
    private var petWebView: WebView? = null
    private var hintView: TextView? = null
    private var petParams: WindowManager.LayoutParams? = null

    private var panelView: FrameLayout? = null
    private var isPanelOpen = false

    private var petKey: String = "fox"
    private var petName: String = "Maru"
    private var petAccentColor: Int = Color.parseColor("#c4571c")
    private var sourceLanguage: String = "gu-IN"
    private var targetLanguage: String = "en-US"
    private var selectedVoice: String = "Devansh"
    private var authToken: String? = null
    private var backendBaseUrl: String = "http://127.0.0.1:8000"
    private var savedPetXBeforePanel: Int? = null

    // Authoritative Card State
    private var spokenText: String = ""
    private var translatedText: String = ""
    private var correctionTip: String? = null
    private var statusNote: String = "Tap the mic and speak."
    private var isRepeatMode: Boolean = false
    private var isListening: Boolean = false
    private var lastRequestId: String = ""

    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var activeMediaPlayer: MediaPlayer? = null

    // Autonomous wandering handler
    private val roamHandler = Handler(Looper.getMainLooper())
    private var roamRunnable: Runnable? = null
    private var isOverlayVisible = true
    private var currentWalkAnim: ValueAnimator? = null
    private var currentSnapAnim: ValueAnimator? = null

    // UI elements in floating PolyCard
    private var tvPanelTitle: TextView? = null
    private var tvLangPair: TextView? = null
    private var tvSpoken: TextView? = null
    private var tvTranslated: TextView? = null
    private var tvCorrection: TextView? = null
    private var tvStatus: TextView? = null
    private var btnPlayView: View? = null
    private var btnSlowView: View? = null
    private var btnRepeatView: TextView? = null
    private var btnMic: ImageButton? = null
    private var etInput: EditText? = null

    init {
        tts = TextToSpeech(context.applicationContext, this)
        loadSavedSettings()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.ENGLISH
            isTtsReady = true
        }
    }

    private fun loadSavedSettings() {
        petKey = prefs.getString("pet_key", "fox") ?: "fox"
        petName = prefs.getString("pet_name", "Maru") ?: "Maru"
        val savedColor = prefs.getString("pet_color", "#c4571c") ?: "#c4571c"
        try {
            petAccentColor = Color.parseColor(savedColor)
        } catch (_: Exception) {
            petAccentColor = Color.parseColor("#c4571c")
        }
        sourceLanguage = prefs.getString("source_lang", "gu-IN") ?: "gu-IN"
        targetLanguage = prefs.getString("target_lang", "en-US") ?: "en-US"
        selectedVoice = prefs.getString("selected_tts_voice", "Devansh") ?: "Devansh"
        authToken = prefs.getString("auth_token", null)
        backendBaseUrl = prefs.getString("backend_base_url", "http://127.0.0.1:8000") ?: "http://127.0.0.1:8000"

        spokenText = prefs.getString("saved_spoken_text", "") ?: ""
        translatedText = prefs.getString("saved_translated_text", "") ?: ""
        correctionTip = prefs.getString("saved_correction", null)
        statusNote = prefs.getString("saved_status_note", "Tap the mic and speak.") ?: "Tap the mic and speak."
    }

    fun updateVoice(voice: String) {
        selectedVoice = voice
        prefs.edit().putString("selected_tts_voice", voice).apply()
        Log.i(TAG, "Authoritative TTS Voice updated to: $voice")
    }

    fun updateBackendUrl(url: String) {
        val clean = url.trimEnd('/')
        backendBaseUrl = clean
        prefs.edit().putString("backend_base_url", clean).apply()
        Log.i(TAG, "Authoritative Backend URL updated to: $clean")
    }

    fun updateAuthToken(token: String?) {
        authToken = token
        prefs.edit().putString("auth_token", token).apply()
    }

    fun updatePet(key: String, name: String, colorHex: String) {
        petKey = key
        petName = name
        try {
            petAccentColor = Color.parseColor(colorHex)
        } catch (_: Exception) {}

        prefs.edit().putString("pet_key", key)
            .putString("pet_name", name)
            .putString("pet_color", colorHex)
            .apply()

        Handler(Looper.getMainLooper()).post {
            petWebView?.loadUrl("javascript:if(window.setPet)window.setPet('$petKey');")
            updatePanelTheme()
        }
    }

    fun updateLanguages(src: String, tgt: String) {
        sourceLanguage = src
        targetLanguage = tgt
        prefs.edit().putString("source_lang", src)
            .putString("target_lang", tgt)
            .apply()

        tvLangPair?.text = "$sourceLanguage → $targetLanguage"
    }

    fun updateCardState(
        petId: String,
        petName: String,
        petColor: String,
        voiceId: String,
        sourceLang: String,
        targetLang: String,
        originalText: String,
        translatedText: String,
        correction: String?,
        statusNote: String?,
        words: String?,
        score: Double?,
        requestId: String
    ) {
        this.petKey = petId
        this.petName = petName
        try {
            this.petAccentColor = Color.parseColor(petColor)
        } catch (_: Exception) {}
        this.selectedVoice = voiceId
        this.sourceLanguage = sourceLang
        this.targetLanguage = targetLang
        this.spokenText = originalText
        this.translatedText = translatedText
        this.correctionTip = if (!correction.isNullOrBlank() && correction != "null") correction else null
        this.statusNote = statusNote ?: if (translatedText.isNotEmpty()) "Tap Repeat to test your pronunciation!" else "Tap the mic and speak."
        this.lastRequestId = requestId

        prefs.edit()
            .putString("pet_key", petId)
            .putString("pet_name", petName)
            .putString("pet_color", petColor)
            .putString("selected_tts_voice", voiceId)
            .putString("source_lang", sourceLang)
            .putString("target_lang", targetLang)
            .putString("saved_spoken_text", originalText)
            .putString("saved_translated_text", translatedText)
            .putString("saved_correction", correction)
            .putString("saved_status_note", this.statusNote)
            .apply()

        Handler(Looper.getMainLooper()).post {
            updatePanelTheme()
            tvSpoken?.text = this.spokenText.ifEmpty { "Tap mic to speak or enter text below." }
            tvTranslated?.text = this.translatedText.ifEmpty { "Welcome to LingoBoop!" }
            if (this.correctionTip != null && this.correctionTip != "null") {
                tvCorrection?.visibility = View.VISIBLE
                tvCorrection?.text = "💡 ${this.correctionTip}"
            } else {
                tvCorrection?.visibility = View.GONE
            }
            tvStatus?.text = this.statusNote
        }
    }

    fun setOverlayVisibility(visible: Boolean) {
        Handler(Looper.getMainLooper()).post {
            isOverlayVisible = visible
            if (visible) {
                petParams?.let { params ->
                    val sizePx = dpToPx(150)
                    params.width = sizePx
                    params.height = sizePx
                    params.alpha = 1.0f
                    params.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    try {
                        petView?.let { windowManager.updateViewLayout(it, params) }
                    } catch (_: Exception) {}
                }
                petView?.visibility = View.VISIBLE
                petWebView?.visibility = View.VISIBLE
                hintView?.visibility = if (isPanelOpen) View.GONE else View.VISIBLE
                scheduleAutonomousRoam()
            } else {
                cancelAutonomousRoam()
                closePanel()
                petView?.visibility = View.GONE
                petWebView?.visibility = View.GONE
                hintView?.visibility = View.GONE
                petParams?.let { params ->
                    params.width = 0
                    params.height = 0
                    params.alpha = 0.0f
                    params.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    try {
                        petView?.let { windowManager.updateViewLayout(it, params) }
                    } catch (_: Exception) {}
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "ClickableViewAccessibility")
    fun showPet() {
        if (petView != null) return

        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)

        val startVisible = !MainActivity.isAppInForeground
        isOverlayVisible = startVisible

        val sizePx = dpToPx(150)
        val initialX = prefs.getInt("pos_x", dm.widthPixels - sizePx - dpToPx(16))
        val initialY = prefs.getInt("pos_y", dm.heightPixels - sizePx - dpToPx(100))

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            if (startVisible) sizePx else 0,
            if (startVisible) sizePx else 0,
            layoutFlag,
            if (startVisible) {
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            } else {
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            },
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX.coerceIn(0, dm.widthPixels - sizePx)
            y = initialY.coerceIn(dpToPx(40), dm.heightPixels - sizePx - dpToPx(60))
            alpha = if (startVisible) 1.0f else 0.0f
        }
        petParams = params

        val container = object : FrameLayout(context) {
            override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
                return true
            }
        }.apply {
            setBackgroundColor(Color.TRANSPARENT)
        }

        val webView = WebView(context).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                allowFileAccessFromFileURLs = true
                allowUniversalAccessFromFileURLs = true
                cacheMode = WebSettings.LOAD_DEFAULT
            }
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    view?.loadUrl("javascript:if(window.setPet)window.setPet('$petKey');")
                }
            }
            loadUrl("file:///android_asset/flutter_assets/assets/web/pet_viewer.html?pet=$petKey")
        }
        petWebView = webView

        container.addView(
            webView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // "Tap me to talk" Hint pill matching prototype .hint
        val hint = TextView(context).apply {
            text = "Tap me to talk"
            setTextColor(Color.parseColor("#1D2B29"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            val hintBg = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadii = floatArrayOf(
                    dpToPx(14).toFloat(), dpToPx(14).toFloat(),
                    dpToPx(14).toFloat(), dpToPx(14).toFloat(),
                    dpToPx(14).toFloat(), dpToPx(14).toFloat(),
                    dpToPx(3).toFloat(), dpToPx(3).toFloat()
                )
            }
            background = hintBg
            setPadding(dpToPx(10), dpToPx(4), dpToPx(10), dpToPx(4))
            elevation = dpToPx(4).toFloat()
            visibility = if (startVisible && !isPanelOpen) View.VISIBLE else View.GONE
        }
        hintView = hint
        container.visibility = if (startVisible) View.VISIBLE else View.GONE
        webView.visibility = if (startVisible) View.VISIBLE else View.GONE
        val hintParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            topMargin = dpToPx(4)
        }
        container.addView(hint, hintParams)

        var touchStartX = 0f
        var touchStartY = 0f
        var viewStartX = 0
        var viewStartY = 0

        container.setOnTouchListener { _, event ->
            val curParams = petParams ?: return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    cancelAutonomousRoam()
                    touchStartX = event.rawX
                    touchStartY = event.rawY
                    viewStartX = curParams.x
                    viewStartY = curParams.y
                    webView.loadUrl("javascript:if(window.setMode)window.setMode('drag');")
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchStartX).toInt()
                    val dy = (event.rawY - touchStartY).toInt()

                    val maxX = dm.widthPixels - sizePx
                    val maxY = dm.heightPixels - sizePx - dpToPx(50)

                    curParams.x = (viewStartX + dx).coerceIn(0, maxX)
                    curParams.y = (viewStartY + dy).coerceIn(dpToPx(40), maxY)

                    windowManager.updateViewLayout(container, curParams)
                    if (isPanelOpen) {
                        updatePanelPosition()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val totalDist = hypot((event.rawX - touchStartX).toDouble(), (event.rawY - touchStartY).toDouble())
                    webView.loadUrl("javascript:if(window.setMode)window.setMode('idle');")

                    if (totalDist < dpToPx(12)) {
                        try {
                            MainActivity.eventSink?.success(
                                mapOf("event" to "pet_tapped", "petKey" to petKey, "petName" to petName)
                            )
                        } catch (_: Exception) {}

                        togglePanel()
                    } else {
                        val screenWidth = dm.widthPixels
                        val snapLeftX = dpToPx(8)
                        val snapRightX = screenWidth - sizePx - dpToPx(8)
                        val targetX = if (curParams.x + sizePx / 2 < screenWidth / 2) snapLeftX else snapRightX

                        val snapAnimator = ValueAnimator.ofInt(curParams.x, targetX)
                        currentSnapAnim = snapAnimator
                        snapAnimator.duration = 200
                        snapAnimator.interpolator = DecelerateInterpolator()
                        snapAnimator.addUpdateListener { anim ->
                            curParams.x = anim.animatedValue as Int
                            try {
                                windowManager.updateViewLayout(container, curParams)
                                if (isPanelOpen) updatePanelPosition()
                            } catch (_: Exception) {}
                        }
                        snapAnimator.addListener(object : AnimatorListenerAdapter() {
                            override fun onAnimationEnd(animation: Animator) {
                                prefs.edit().putInt("pos_x", curParams.x).putInt("pos_y", curParams.y).apply()
                                if (!isPanelOpen) {
                                    scheduleAutonomousRoam()
                                }
                            }
                        })
                        snapAnimator.start()
                    }
                    true
                }
                else -> false
            }
        }

        petView = container
        windowManager.addView(container, params)
        if (startVisible) {
            scheduleAutonomousRoam()
        }
    }

    private fun scheduleAutonomousRoam() {
        cancelAutonomousRoam()
        if (!isOverlayVisible || isPanelOpen || petView == null || petView?.visibility != View.VISIBLE) return

        roamRunnable = Runnable {
            if (!isOverlayVisible || isPanelOpen || petView == null || petView?.visibility != View.VISIBLE) return@Runnable
            val dm = DisplayMetrics()
            windowManager.defaultDisplay.getMetrics(dm)
            val curParams = petParams ?: return@Runnable
            val sizePx = dpToPx(150)
            val screenWidth = dm.widthPixels

            val targetX = (Math.random() * (screenWidth - sizePx - dpToPx(24)) + dpToPx(12)).toInt()
            val dx = targetX - curParams.x
            if (abs(dx) > dpToPx(30)) {
                val facing = if (dx > 0) Math.PI / 2.0 else -Math.PI / 2.0
                petWebView?.loadUrl("javascript:if(window.setFacing)window.setFacing($facing);if(window.setMode)window.setMode('walk');")

                val startX = curParams.x
                val walkAnim = ValueAnimator.ofInt(startX, targetX).apply {
                    duration = (abs(dx) / dpToPx(58).toFloat() * 1000).toLong().coerceIn(1200L, 4000L)
                    interpolator = LinearInterpolator()
                    addUpdateListener { anim ->
                        curParams.x = anim.animatedValue as Int
                        try {
                            petView?.let { windowManager.updateViewLayout(it, curParams) }
                        } catch (_: Exception) {}
                    }
                    addListener(object : AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: Animator) {
                            currentWalkAnim = null
                            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                            prefs.edit().putInt("pos_x", curParams.x).apply()
                            if (isOverlayVisible && !isPanelOpen) {
                                scheduleAutonomousRoam()
                            }
                        }
                    })
                }
                currentWalkAnim = walkAnim
                walkAnim.start()
            } else {
                if (Math.random() < 0.25) {
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('dance');")
                    roamHandler.postDelayed({
                        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                        if (isOverlayVisible && !isPanelOpen) {
                            scheduleAutonomousRoam()
                        }
                    }, 2600)
                } else {
                    if (isOverlayVisible && !isPanelOpen) {
                        scheduleAutonomousRoam()
                    }
                }
            }
        }
        roamHandler.postDelayed(roamRunnable!!, (6000 + Math.random() * 6000).toLong())
    }

    private fun cancelAutonomousRoam() {
        roamHandler.removeCallbacksAndMessages(null)
        roamRunnable = null
        currentWalkAnim?.cancel()
        currentWalkAnim = null
        currentSnapAnim?.cancel()
        currentSnapAnim = null
    }

    fun hidePet() {
        cancelAutonomousRoam()
        closePanel()
        petView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
        }
        petView = null
        petWebView = null
        hintView = null
    }

    private fun updatePanelPosition() {
        val panel = panelView ?: return
        val petP = petParams ?: return
        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)

        val sizePx = dpToPx(150)
        val panelWidth = (dm.widthPixels * 0.76).toInt().coerceIn(dpToPx(270), dpToPx(296))
        val panelHeight = dpToPx(340)

        val isLeftSide = petP.x + sizePx / 2 < dm.widthPixels / 2
        var posX = if (isLeftSide) {
            petP.x + sizePx - dpToPx(42)
        } else {
            petP.x - panelWidth + dpToPx(42)
        }
        posX = posX.coerceIn(dpToPx(12), dm.widthPixels - panelWidth - dpToPx(12))

        var posY = petP.y - dpToPx(40)
        posY = posY.coerceIn(dpToPx(50), dm.heightPixels - panelHeight - dpToPx(60))

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            panelWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = posX
            y = posY
        }
        try {
            windowManager.updateViewLayout(panel, params)
        } catch (_: Exception) {}
    }

    private fun togglePanel() {
        if (isPanelOpen) {
            closePanel()
        } else {
            openPanel()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun openPanel() {
        if (isPanelOpen || panelView != null) return
        cancelAutonomousRoam()

        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)

        val petP = petParams ?: return
        val sizePx = dpToPx(150)
        val panelWidth = (dm.widthPixels * 0.76).toInt().coerceIn(dpToPx(270), dpToPx(296))
        val panelHeight = dpToPx(340)

        val isLeftSide = petP.x + sizePx / 2 < dm.widthPixels / 2
        val dockSide = if (isLeftSide) "r" else "l"

        savedPetXBeforePanel = petP.x

        val targetPetX = if (isLeftSide) dpToPx(-24) else (dm.widthPixels - dpToPx(126))
        petP.x = targetPetX
        try {
            petView?.let { windowManager.updateViewLayout(it, petP) }
        } catch (_: Exception) {}

        var posX = if (isLeftSide) {
            dpToPx(108)
        } else {
            targetPetX - panelWidth + dpToPx(4)
        }
        posX = posX.coerceIn(dpToPx(12), dm.widthPixels - panelWidth - dpToPx(12))

        var posY = petP.y - dpToPx(40)
        posY = posY.coerceIn(dpToPx(50), dm.heightPixels - panelHeight - dpToPx(60))

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            panelWidth,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = posX
            y = posY
        }

        val panel = createPanelLayout()
        panelView = panel

        panel.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                closePanel()
                true
            } else {
                false
            }
        }

        windowManager.addView(panel, params)
        isPanelOpen = true
        hintView?.visibility = View.GONE

        petWebView?.loadUrl("javascript:if(window.setCardDock)window.setCardDock(true, '$dockSide');if(window.setMode)window.setMode('talk');")
    }

    fun closePanel() {
        if (!isPanelOpen && panelView == null) return
        stopVoiceRecognition()
        stopAudioPlayback()
        isRepeatMode = false

        panelView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
        }
        panelView = null
        isPanelOpen = false

        if (isOverlayVisible) {
            hintView?.visibility = View.VISIBLE
        }

        val petP = petParams
        val savedX = savedPetXBeforePanel
        if (petP != null && savedX != null) {
            petP.x = savedX
            try {
                petView?.let { windowManager.updateViewLayout(it, petP) }
            } catch (_: Exception) {}
            savedPetXBeforePanel = null
        }

        petWebView?.loadUrl("javascript:if(window.setCardDock)window.setCardDock(false, 'r');if(window.setFacing)window.setFacing(0.5);if(window.setMode)window.setMode('idle');")
        scheduleAutonomousRoam()
    }

    private fun createPanelLayout(): FrameLayout {
        val root = FrameLayout(context).apply {
            val bg = GradientDrawable().apply {
                setColor(petAccentColor)
                cornerRadius = dpToPx(22).toFloat()
            }
            background = bg
            setPadding(dpToPx(14), dpToPx(14), dpToPx(14), dpToPx(14))
            elevation = dpToPx(16).toFloat()
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // 1. Header: Name, Lang Pair, Close button (x)
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(context).apply {
            text = petName
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        tvPanelTitle = title

        val langPair = TextView(context).apply {
            text = "$sourceLanguage → $targetLanguage"
            setTextColor(Color.parseColor("#D9FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dpToPx(8), 0, 0, 0)
        }
        tvLangPair = langPair

        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f)
        }

        val btnClose = TextView(context).apply {
            text = "×"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
            val circle = GradientDrawable().apply {
                setColor(Color.parseColor("#33FFFFFF"))
                shape = GradientDrawable.OVAL
            }
            background = circle
            layoutParams = LinearLayout.LayoutParams(dpToPx(30), dpToPx(30))
            setOnClickListener { closePanel() }
        }

        header.addView(title)
        header.addView(langPair)
        header.addView(spacer)
        header.addView(btnClose)
        content.addView(header)

        // 2. Spoken Transcript (italic)
        val spoken = TextView(context).apply {
            text = spokenText.ifEmpty { "Tap mic to speak or enter text below." }
            setTextColor(Color.parseColor("#D9FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.ITALIC)
            setPadding(0, dpToPx(8), 0, dpToPx(4))
        }
        tvSpoken = spoken
        content.addView(spoken)

        // 3. Translated Karaoke View (bold prominent)
        val translated = TextView(context).apply {
            text = translatedText.ifEmpty { "Welcome to LingoBoop!" }
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(4), 0, dpToPx(6))
        }
        tvTranslated = translated
        content.addView(translated)

        // 4. Grammar / AI Correction Tip (dark pill container)
        val correction = TextView(context).apply {
            text = if (!correctionTip.isNullOrBlank() && correctionTip != "null") "💡 $correctionTip" else ""
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            val corrBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33000000"))
                cornerRadius = dpToPx(8).toFloat()
            }
            background = corrBg
            setPadding(dpToPx(8), dpToPx(4), dpToPx(8), dpToPx(4))
            visibility = if (!correctionTip.isNullOrBlank() && correctionTip != "null") View.VISIBLE else View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(4))
            }
        }
        tvCorrection = correction
        content.addView(correction)

        // 5. Status Note
        val status = TextView(context).apply {
            text = statusNote
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, 0, 0, dpToPx(8))
        }
        tvStatus = status
        content.addView(status)

        // 6. Controls Row: Play, Slow, Repeat, Mic
        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            clipChildren = false
            setPadding(0, dpToPx(4), 0, dpToPx(8))
        }

        // Circular Play button matching #play in Flutter
        val btnPlay = TextView(context).apply {
            text = "▶"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            val playBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33FFFFFF"))
                shape = GradientDrawable.OVAL
            }
            background = playBg
            layoutParams = LinearLayout.LayoutParams(dpToPx(34), dpToPx(34)).apply {
                setMargins(0, 0, dpToPx(6), 0)
            }
            setOnClickListener {
                speakCurrentTranslation(1.0f)
            }
        }
        btnPlayView = btnPlay

        // Pill Slow button
        val btnSlow = createPillButton("Slow") {
            speakCurrentTranslation(0.75f)
        }
        btnSlowView = btnSlow

        // Pill Repeat button
        val btnRepeat = createPillButton(if (isRepeatMode) "Done" else "Repeat") {
            if (isRepeatMode) {
                stopRepeatPractice()
            } else {
                startRepeatPractice()
            }
        }
        btnRepeatView = btnRepeat

        // Circular 38x38 white mic button with accent icon
        val mic = ImageButton(context).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            val micBg = GradientDrawable().apply {
                setColor(Color.WHITE)
                shape = GradientDrawable.OVAL
            }
            background = micBg
            setColorFilter(petAccentColor)
            layoutParams = LinearLayout.LayoutParams(dpToPx(38), dpToPx(38)).apply {
                setMargins(dpToPx(4), 0, dpToPx(2), 0)
            }
            setOnClickListener {
                if (isListening) {
                    if (isRepeatMode) {
                        stopRepeatPractice()
                    } else {
                        stopVoiceRecognition()
                    }
                } else {
                    startVoiceRecognition()
                }
            }
        }
        btnMic = mic

        controls.addView(btnPlay)
        controls.addView(btnSlow)
        controls.addView(btnRepeat)
        controls.addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f) })
        controls.addView(mic)
        content.addView(controls)

        // 7. Input Form matching Flutter PolyCard 36dp container with arrow button
        val inputForm = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val inputBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33000000"))
                cornerRadius = dpToPx(12).toFloat()
            }
            background = inputBg
            setPadding(dpToPx(12), 0, dpToPx(6), 0)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(36)
            )
        }

        val input = EditText(context).apply {
            hint = "Or type a sentence…"
            setHintTextColor(Color.parseColor("#BBFFFFFF"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            background = null
            setPadding(0, 0, dpToPx(8), 0)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1.0f)
            isSingleLine = true
            setOnEditorActionListener { _, _, _ ->
                val txt = text.toString().trim()
                if (txt.isNotEmpty()) {
                    setText("")
                    handleEnteredText(txt)
                }
                true
            }
        }
        etInput = input

        val btnSend = TextView(context).apply {
            text = "↑"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dpToPx(28), dpToPx(28))
            setOnClickListener {
                val txt = input.text.toString().trim()
                if (txt.isNotEmpty()) {
                    input.setText("")
                    handleEnteredText(txt)
                }
            }
        }

        inputForm.addView(input)
        inputForm.addView(btnSend)
        content.addView(inputForm)

        root.addView(content)
        return root
    }

    private fun updatePanelTheme() {
        panelView?.let { panel ->
            val bg = GradientDrawable().apply {
                setColor(petAccentColor)
                cornerRadius = dpToPx(22).toFloat()
            }
            panel.background = bg
            tvPanelTitle?.text = petName
            tvLangPair?.text = "$sourceLanguage → $targetLanguage"
            btnMic?.setColorFilter(petAccentColor)
            if (isRepeatMode) {
                btnRepeatView?.setTextColor(petAccentColor)
            }
        }
    }

    private fun createPillButton(label: String, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            text = label
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
            gravity = Gravity.CENTER
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#33FFFFFF"))
                cornerRadius = dpToPx(999).toFloat()
            }
            background = bg
            setPadding(dpToPx(10), dpToPx(6), dpToPx(10), dpToPx(6))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(34)
            ).apply {
                setMargins(0, 0, dpToPx(4), 0)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun handleEnteredText(text: String) {
        spokenText = text
        tvSpoken?.text = text
        requestAITutoring(text)
    }

    private fun requestAITutoring(inputText: String) {
        val reqId = System.currentTimeMillis().toString()
        lastRequestId = reqId

        tvSpoken?.text = inputText
        tvTranslated?.text = "Translating…"
        tvStatus?.text = "Reasoning with Groq GPT-OSS 120B…"
        tvCorrection?.visibility = View.GONE
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('think');")

        Thread {
            var finalTranslation: String? = null
            var finalCorrection: String? = null
            var finalNote: String? = null

            val endpoints = linkedSetOf(
                backendBaseUrl,
                "http://127.0.0.1:8000",
                "http://10.0.2.2:8000",
                "http://10.82.30.80:8000",
                "http://10.94.94.80:8000"
            )

            for (baseUrl in endpoints) {
                // 1. Try central AI tutor endpoint
                try {
                    val url = URL("$baseUrl/api/v1/ai/tutor")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 3000
                        readTimeout = 8000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json; charset=utf-8")
                        val authHeader = if (!authToken.isNullOrEmpty()) "Bearer $authToken" else "Bearer dev_guest_token"
                        setRequestProperty("Authorization", authHeader)
                    }

                    val payload = JSONObject().apply {
                        put("user_message", inputText)
                        put("native_language", sourceLanguage)
                        put("target_language", targetLanguage)
                        put("character_id", petKey)
                        put("mode", "tutor")
                    }

                    conn.outputStream.use { os ->
                        os.write(payload.toString().toByteArray(Charsets.UTF_8))
                    }

                    if (conn.responseCode == 200) {
                        val responseStr = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                        val json = JSONObject(responseStr)
                        if (json.optBoolean("success", false)) {
                            val data = json.optJSONObject("data")
                            val cand = data?.optString("translated_text")
                                ?: data?.optString("reply_text")
                            if (!cand.isNullOrBlank() && !cand.trim().equals(inputText.trim(), ignoreCase = true)) {
                                finalTranslation = cand.trim()
                                finalCorrection = data?.optString("correction")
                                finalNote = data?.optString("explanation")
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Tutor endpoint at $baseUrl failed: ${e.message}")
                }

                // 2. Fallback to direct translation endpoint
                if (finalTranslation == null) {
                    try {
                        val transUrl = URL("$baseUrl/api/v1/translation/translate")
                        val transConn = (transUrl.openConnection() as HttpURLConnection).apply {
                            requestMethod = "POST"
                            connectTimeout = 3000
                            readTimeout = 8000
                            doOutput = true
                            setRequestProperty("Content-Type", "application/json; charset=utf-8")
                            val authHeader = if (!authToken.isNullOrEmpty()) "Bearer $authToken" else "Bearer dev_guest_token"
                            setRequestProperty("Authorization", authHeader)
                        }

                        val transPayload = JSONObject().apply {
                            put("text", inputText)
                            put("source_language", sourceLanguage)
                            put("target_language", targetLanguage)
                            put("character_id", petKey)
                        }

                        transConn.outputStream.use { os ->
                            os.write(transPayload.toString().toByteArray(Charsets.UTF_8))
                        }

                        if (transConn.responseCode == 200) {
                            val resStr = transConn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                            val json = JSONObject(resStr)
                            val dataObj = json.optJSONObject("data")
                            val cand = dataObj?.optString("translated_text") ?: json.optString("translated_text")
                            if (!cand.isNullOrBlank() && !cand.trim().equals(inputText.trim(), ignoreCase = true)) {
                                finalTranslation = cand.trim()
                                break
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Translate endpoint at $baseUrl failed: ${e.message}")
                    }
                }

                if (finalTranslation != null) break
            }

            // Post back to main thread
            Handler(Looper.getMainLooper()).post {
                if (lastRequestId != reqId) return@post // Ignore stale responses

                if (finalTranslation != null) {
                    spokenText = inputText
                    translatedText = finalTranslation
                    correctionTip = if (!finalCorrection.isNullOrBlank() && finalCorrection != "null") finalCorrection else null
                    statusNote = "Tap Repeat to test your pronunciation!"

                    tvSpoken?.text = spokenText
                    tvTranslated?.text = translatedText
                    if (correctionTip != null && correctionTip != "null") {
                        tvCorrection?.visibility = View.VISIBLE
                        tvCorrection?.text = "💡 $correctionTip"
                    } else {
                        tvCorrection?.visibility = View.GONE
                    }
                    tvStatus?.text = statusNote

                    prefs.edit()
                        .putString("saved_spoken_text", spokenText)
                        .putString("saved_translated_text", translatedText)
                        .putString("saved_correction", correctionTip)
                        .putString("saved_status_note", statusNote)
                        .apply()

                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")

                    // Automatically speak the translated text with authoritative selected voice
                    speakCurrentTranslation(1.0f)

                    // Synchronize state back to Flutter app if running
                    try {
                        MainActivity.eventSink?.success(
                            mapOf(
                                "event" to "card_state_updated",
                                "spokenText" to spokenText,
                                "translatedText" to translatedText,
                                "correction" to correctionTip,
                                "sourceLanguage" to sourceLanguage,
                                "targetLanguage" to targetLanguage
                            )
                        )
                    } catch (_: Exception) {}
                } else {
                    // Translation failed: NEVER substitute the original sentence!
                    tvTranslated?.text = "Translation unavailable"
                    tvStatus?.text = "Tap to retry or check connection"
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('oops');")
                }
            }
        }.start()
    }

    private fun speakCurrentTranslation(rate: Float) {
        val phrase = translatedText.ifEmpty { tvTranslated?.text?.toString() ?: "" }
        if (phrase.isEmpty() || phrase.contains("unavailable", ignoreCase = true) ||
            phrase == "Translating…" || phrase == "Welcome to LingoBoop!"
        ) {
            return
        }

        stopAudioPlayback()

        Log.i(TAG, "[SpeechService] Overlay TTS request started: text=\"$phrase\", voice=$selectedVoice, lang=$targetLanguage, speed=$rate")
        tvStatus?.text = if (rate < 1.0f) "Playing slow audio (0.75x)…" else "Speaking…"

        Thread {
            var audioSuccess = false
            val endpoints = linkedSetOf(
                backendBaseUrl,
                "http://127.0.0.1:8000",
                "http://10.0.2.2:8000",
                "http://10.82.30.80:8000",
                "http://10.94.94.80:8000"
            )

            for (baseUrl in endpoints) {
                try {
                    val url = URL("$baseUrl/api/v1/tts/synthesize")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 3000
                        readTimeout = 8000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json; charset=utf-8")
                        val authHeader = if (!authToken.isNullOrEmpty()) "Bearer $authToken" else "Bearer dev_guest_token"
                        setRequestProperty("Authorization", authHeader)
                    }

                    val payload = JSONObject().apply {
                        put("text", phrase)
                        put("voice", selectedVoice)
                        put("language", targetLanguage)
                        put("speed", rate.toDouble())
                    }

                    conn.outputStream.use { os ->
                        os.write(payload.toString().toByteArray(Charsets.UTF_8))
                    }

                    if (conn.responseCode == 200) {
                        val respStr = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                        val json = JSONObject(respStr)
                        val b64 = json.optJSONObject("data")?.optString("audio_base64")
                        if (!b64.isNullOrEmpty()) {
                            val rawBytes = Base64.decode(b64, Base64.DEFAULT)
                            val normalizedBytes = normalizeWavBytes(rawBytes)
                            val tempFile = File(context.cacheDir, "ext_tts_${System.currentTimeMillis()}.wav")
                            tempFile.writeBytes(normalizedBytes)

                            Handler(Looper.getMainLooper()).post {
                                playAudioFile(tempFile, rate)
                            }
                            audioSuccess = true
                            break
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "TTS request failed at $baseUrl: ${e.message}")
                }
            }

            if (!audioSuccess) {
                Handler(Looper.getMainLooper()).post {
                    fallbackAndroidTts(phrase, rate)
                }
            }
        }.start()
    }

    private fun normalizeWavBytes(pcmBytes: ByteArray): ByteArray {
        if (pcmBytes.size < 44) return pcmBytes
        if (pcmBytes[0] != 'R'.code.toByte() || pcmBytes[1] != 'I'.code.toByte() ||
            pcmBytes[2] != 'F'.code.toByte() || pcmBytes[3] != 'F'.code.toByte()
        ) {
            return pcmBytes
        }
        var dataIdx = -1
        for (i in 12 until pcmBytes.size - 8) {
            if (pcmBytes[i] == 'd'.code.toByte() && pcmBytes[i + 1] == 'a'.code.toByte() &&
                pcmBytes[i + 2] == 't'.code.toByte() && pcmBytes[i + 3] == 'a'.code.toByte()
            ) {
                dataIdx = i
                break
            }
        }
        if (dataIdx == -1) return pcmBytes

        val pcmStart = dataIdx + 8
        val rawPcmLen = pcmBytes.size - pcmStart
        val numSamples = rawPcmLen / 2
        if (numSamples <= 0) return pcmBytes

        val byteBuf = ByteBuffer.wrap(pcmBytes).order(ByteOrder.LITTLE_ENDIAN)
        var peak = 0
        var sumSq = 0.0
        val samples = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val s = byteBuf.getShort(pcmStart + i * 2).toInt()
            samples[i] = s.toShort()
            val absS = kotlin.math.abs(s)
            if (absS > peak) peak = absS
            sumSq += s.toDouble() * s.toDouble()
        }
        if (peak == 0) return pcmBytes

        val rms = kotlin.math.sqrt(sumSq / numSamples)
        val peakDbfs = 20.0 * kotlin.math.log10(peak / 32768.0)
        val rmsDbfs = if (rms > 0) 20.0 * kotlin.math.log10(rms / 32768.0) else -999.0

        if (peakDbfs >= -1.5 || rmsDbfs >= -17.0) {
            val copy = pcmBytes.copyOf()
            ByteBuffer.wrap(copy).order(ByteOrder.LITTLE_ENDIAN).apply {
                putInt(4, copy.size - 8)
                putInt(dataIdx + 4, rawPcmLen)
            }
            return copy
        }

        val targetRmsAmp = 32768.0 * Math.pow(10.0, -15.0 / 20.0)
        val targetPeakAmp = 32768.0 * Math.pow(10.0, -1.0 / 20.0)

        val desiredRmsGain = if (rms > 0) targetRmsAmp / rms else 1.0
        val maxLinearGain = targetPeakAmp / peak
        var gain = kotlin.math.min(desiredRmsGain, maxLinearGain * 1.5)
        gain = kotlin.math.max(1.0, kotlin.math.min(gain, 3.5))

        val threshold = 26000.0
        val ceiling = 31000.0
        val ratio = ceiling - threshold

        val outBytes = ByteArray(pcmStart + numSamples * 2)
        System.arraycopy(pcmBytes, 0, outBytes, 0, pcmStart)
        val outBuf = ByteBuffer.wrap(outBytes).order(ByteOrder.LITTLE_ENDIAN)

        outBuf.putInt(4, outBytes.size - 8)
        outBuf.putInt(dataIdx + 4, numSamples * 2)

        for (i in 0 until numSamples) {
            val s = samples[i].toDouble()
            val v = s * gain
            val absV = kotlin.math.abs(v)
            val outVal = if (absV <= threshold) {
                v
            } else {
                val over = absV - threshold
                val limited = threshold + ratio * kotlin.math.tanh(over / ratio)
                if (v < 0) -limited else limited
            }
            var intVal = kotlin.math.round(outVal).toInt()
            if (intVal > 32767) intVal = 32767
            if (intVal < -32768) intVal = -32768
            outBuf.putShort(pcmStart + i * 2, intVal.toShort())
        }
        return outBytes
    }

    private fun playAudioFile(file: File, rate: Float) {
        stopAudioPlayback()
        try {
            val mp = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setVolume(1.0f, 1.0f)
                setDataSource(file.absolutePath)
                prepare()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && rate != 1.0f) {
                    try {
                        playbackParams = playbackParams.setSpeed(rate)
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not set playback speed: ${e.message}")
                    }
                }
                start()
                setOnCompletionListener {
                    release()
                    file.delete()
                    activeMediaPlayer = null
                    tvStatus?.text = "Tap Repeat to test your pronunciation!"
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                    Log.i(TAG, "[SpeechService] Playback completed successfully")
                }
            }
            activeMediaPlayer = mp
            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
            Log.i(TAG, "[SpeechService] Audio playback started: speed=$rate, volume=1.0")
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer error: ${e.message}", e)
            fallbackAndroidTts(translatedText, rate)
        }
    }

    private fun stopAudioPlayback() {
        try {
            activeMediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (_: Exception) {}
        activeMediaPlayer = null
    }

    private fun fallbackAndroidTts(phrase: String, rate: Float) {
        if (isTtsReady && tts != null) {
            tts?.setSpeechRate(rate)
            tts?.speak(phrase, TextToSpeech.QUEUE_FLUSH, null, "lingoboom_overlay_tts")
            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
        }
    }

    private fun startVoiceRecognition() {
        stopVoiceRecognition()
        isRepeatMode = false
        updateRepeatButtonUI()

        try {
            if (!SpeechRecognizer.isRecognitionAvailable(context)) {
                tvStatus?.text = "Speech recognizer unavailable on this device."
                return
            }

            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer = recognizer
            isListening = true

            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    tvStatus?.text = "Listening… speak in $sourceLanguage"
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('listen');")
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    tvStatus?.text = "Processing speech…"
                }
                override fun onError(error: Int) {
                    isListening = false
                    tvStatus?.text = "Could not capture speech. Tap mic to try again."
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                }
                override fun onResults(results: Bundle?) {
                    isListening = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        val heard = matches[0]
                        handleEnteredText(heard)
                    } else {
                        tvStatus?.text = "Nothing heard. Tap mic and try again."
                        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                    }
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, sourceLanguage)
            }
            recognizer.startListening(intent)
        } catch (e: Exception) {
            isListening = false
            tvStatus?.text = "Microphone error: ${e.message}"
        }
    }

    private fun startRepeatPractice() {
        if (translatedText.isBlank() || translatedText.contains("unavailable", ignoreCase = true)) {
            tvStatus?.text = "Translate a sentence first before repeat practice."
            return
        }

        stopVoiceRecognition()
        stopAudioPlayback()

        isRepeatMode = true
        updateRepeatButtonUI()

        tvStatus?.text = "Say the target sentence out loud now…"
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('listen');")

        try {
            if (!SpeechRecognizer.isRecognitionAvailable(context)) {
                tvStatus?.text = "Speech recognizer unavailable on this device."
                isRepeatMode = false
                updateRepeatButtonUI()
                return
            }

            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer = recognizer
            isListening = true

            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    tvStatus?.text = "Say: $translatedText"
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    tvStatus?.text = "Analyzing pronunciation…"
                }
                override fun onError(error: Int) {
                    isListening = false
                    isRepeatMode = false
                    updateRepeatButtonUI()
                    tvStatus?.text = "Could not capture clear speech. Tap Repeat to try again."
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                }
                override fun onResults(results: Bundle?) {
                    isListening = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val heard = if (!matches.isNullOrEmpty()) matches[0] else ""
                    evaluatePronunciation(heard)
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            // Listen in targetLanguage (e.g. en-US) for repeat pronunciation assessment
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, targetLanguage)
            }
            recognizer.startListening(intent)
        } catch (e: Exception) {
            isListening = false
            isRepeatMode = false
            updateRepeatButtonUI()
            tvStatus?.text = "Microphone error: ${e.message}"
        }
    }

    private fun stopRepeatPractice() {
        stopVoiceRecognition()
        isRepeatMode = false
        updateRepeatButtonUI()
    }

    private fun updateRepeatButtonUI() {
        btnRepeatView?.let { btn ->
            if (isRepeatMode) {
                btn.text = "Done"
                val activeBg = GradientDrawable().apply {
                    setColor(Color.WHITE)
                    cornerRadius = dpToPx(999).toFloat()
                }
                btn.background = activeBg
                btn.setTextColor(petAccentColor)
            } else {
                btn.text = "Repeat"
                val defaultBg = GradientDrawable().apply {
                    setColor(Color.parseColor("#33FFFFFF"))
                    cornerRadius = dpToPx(999).toFloat()
                }
                btn.background = defaultBg
                btn.setTextColor(Color.WHITE)
            }
        }
    }

    private fun evaluatePronunciation(userSpoken: String) {
        isRepeatMode = false
        updateRepeatButtonUI()

        if (userSpoken.isBlank()) {
            tvStatus?.text = "Could not capture clear speech. Tap Repeat to try again."
            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
            return
        }

        tvSpoken?.text = "Heard: $userSpoken"

        val expected = translatedText
        val result = OverlayPronunciationScorer.evaluate(expectedSentence = expected, spokenTranscript = userSpoken)

        tvStatus?.text = result.feedback
        statusNote = result.feedback

        val score = result.matchPercentage
        val petMode = if (score >= 80) "dance" else if (score >= 50) "talk" else "oops"
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('$petMode');")

        Handler(Looper.getMainLooper()).postDelayed({
            if (isPanelOpen) {
                petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
            }
        }, 2200)

        // Sync pronunciation result to Flutter
        try {
            MainActivity.eventSink?.success(
                mapOf(
                    "event" to "pronunciation_evaluated",
                    "heard" to userSpoken,
                    "score" to score,
                    "feedback" to result.feedback
                )
            )
        } catch (_: Exception) {}
    }

    private fun stopVoiceRecognition() {
        isListening = false
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        speechRecognizer = null
    }

    fun destroy() {
        cancelAutonomousRoam()
        hidePet()
        stopAudioPlayback()
        stopVoiceRecognition()
        tts?.stop()
        tts?.shutdown()
        tts = null
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }
}

/**
 * Mathematically identical token alignment & Levenshtein distance pronunciation scoring,
 * matching `PronunciationScorer` in Flutter.
 */
object OverlayPronunciationScorer {
    private val punctRegex = Regex("""[.,\/#!$%\^&\*;:{}=\-_`~()?"।॥]""")
    private val multiSpaceRegex = Regex("""\s+""")

    fun tokenize(text: String): List<String> {
        val clean = text.replace(punctRegex, " ")
            .replace(multiSpaceRegex, " ")
            .trim()
            .lowercase()
        if (clean.isEmpty()) return emptyList()
        return clean.split(" ").filter { it.isNotEmpty() }
    }

    fun levenshteinDistance(s1: String, s2: String): Int {
        if (s1 == s2) return 0
        if (s1.isEmpty()) return s2.length
        if (s2.isEmpty()) return s1.length

        val v0 = IntArray(s2.length + 1) { it }
        val v1 = IntArray(s2.length + 1)

        for (i in s1.indices) {
            v1[0] = i + 1
            for (j in s2.indices) {
                val cost = if (s1[i] == s2[j]) 0 else 1
                v1[j + 1] = minOf(v1[j] + 1, minOf(v0[j + 1] + 1, v0[j] + cost))
            }
            for (j in 0..s2.length) v0[j] = v1[j]
        }
        return v0[s2.length]
    }

    fun wordSimilarity(w1: String, w2: String): Double {
        if (w1 == w2) return 1.0
        val maxLen = maxOf(w1.length, w2.length)
        if (maxLen == 0) return 1.0
        val dist = levenshteinDistance(w1, w2)
        return ((maxLen - dist).toDouble() / maxLen).coerceIn(0.0, 1.0)
    }

    data class ScoringResult(
        val matchPercentage: Int,
        val feedback: String
    )

    fun evaluate(expectedSentence: String, spokenTranscript: String): ScoringResult {
        val expectedWords = tokenize(expectedSentence)
        val spokenWords = tokenize(spokenTranscript)

        if (spokenWords.isEmpty()) {
            return ScoringResult(0, "Could not capture clear speech. Tap Repeat to try again.")
        }
        if (expectedWords.isEmpty()) {
            return ScoringResult(100, "Great job!")
        }

        val m = expectedWords.size
        val n = spokenWords.size
        val dp = Array(m + 1) { DoubleArray(n + 1) }

        for (i in 1..m) {
            for (j in 1..n) {
                val sim = wordSimilarity(expectedWords[i - 1], spokenWords[j - 1])
                val matchScore = dp[i - 1][j - 1] + (if (sim >= 0.65) sim else 0.0)
                dp[i][j] = maxOf(matchScore, maxOf(dp[i - 1][j], dp[i][j - 1]))
            }
        }

        var i = m
        var j = n
        var earnedScore = 0.0

        while (i > 0 || j > 0) {
            if (i > 0 && j > 0) {
                val sim = wordSimilarity(expectedWords[i - 1], spokenWords[j - 1])
                if (sim >= 0.65 && abs(dp[i][j] - (dp[i - 1][j - 1] + sim)) < 1e-4) {
                    val isExact = sim >= 0.85
                    earnedScore += if (isExact) 1.0 else sim.coerceIn(0.5, 0.85)
                    i--
                    j--
                    continue
                }
            }

            if (i > 0 && (j == 0 || dp[i][j] == dp[i - 1][j])) {
                i--
            } else if (j > 0) {
                j--
            }
        }

        val pct = ((earnedScore / expectedWords.size) * 100.0).roundToInt().coerceIn(0, 100)

        val feedback = when {
            pct >= 85 -> "Excellent pronunciation! Perfect flow. ($pct%)"
            pct >= 70 -> "Great job! ($pct% matched). Practice highlighted words."
            pct >= 40 -> "$pct% matched. Check missed words and try again."
            else -> "Keep practicing! ($pct% matched). Tap Slow to hear each word."
        }

        return ScoringResult(pct, feedback)
    }
}
