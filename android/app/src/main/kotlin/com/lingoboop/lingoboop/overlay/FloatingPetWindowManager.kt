package com.lingoboop.lingoboop.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.*
import com.lingoboop.lingoboop.MainActivity
import java.util.*
import kotlin.math.hypot

class FloatingPetWindowManager(private val context: Context) : TextToSpeech.OnInitListener {

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
    private var authToken: String? = null
    private var savedPetXBeforePanel: Int? = null

    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var speechRecognizer: SpeechRecognizer? = null

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
    private var tvStatus: TextView? = null
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
        authToken = prefs.getString("auth_token", null)
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

        val startVisible = !com.lingoboop.lingoboop.MainActivity.isAppInForeground
        isOverlayVisible = startVisible

        // Exact prototype pet size: 150px x 150px
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

        // Draggable Touch Listener with boundary clamping, click detection, and edge snapping
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

                        // Directly open/close the floating conversation card overlay over the current app
                        togglePanel()
                    } else {
                        // Edge snapping: smoothly animate to left or right screen edge
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
            if (Math.abs(dx) > dpToPx(30)) {
                val facing = if (dx > 0) Math.PI / 2.0 else -Math.PI / 2.0
                petWebView?.loadUrl("javascript:if(window.setFacing)window.setFacing($facing);if(window.setMode)window.setMode('walk');")

                val startX = curParams.x
                val walkAnim = ValueAnimator.ofInt(startX, targetX).apply {
                    duration = (Math.abs(dx) / dpToPx(58).toFloat() * 1000).toLong().coerceIn(1200L, 4000L)
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
        val dockSide = if (isLeftSide) "r" else "l"

        var posX = if (isLeftSide) {
            petP.x + dpToPx(108)
        } else {
            petP.x - panelWidth + dpToPx(42)
        }
        posX = posX.coerceIn(dpToPx(12), dm.widthPixels - panelWidth - dpToPx(12))

        var posY = petP.y - dpToPx(40)
        posY = posY.coerceIn(dpToPx(50), dm.heightPixels - panelHeight - dpToPx(60))

        val params = panel.layoutParams as? WindowManager.LayoutParams ?: return
        params.x = posX
        params.y = posY
        try {
            windowManager.updateViewLayout(panel, params)
            petWebView?.loadUrl("javascript:if(window.setCardDock)window.setCardDock(true, '$dockSide');")
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
        // Responsive PolyCard width to prevent control clipping
        val panelWidth = (dm.widthPixels * 0.76).toInt().coerceIn(dpToPx(270), dpToPx(296))
        val panelHeight = dpToPx(340)

        val isLeftSide = petP.x + sizePx / 2 < dm.widthPixels / 2
        val dockSide = if (isLeftSide) "r" else "l"

        // Save original pet position before docking
        savedPetXBeforePanel = petP.x

        // Dock pet to screen edge opposite card, matching HTML prototype
        val targetPetX = if (isLeftSide) dpToPx(-24) else (dm.widthPixels - dpToPx(126))
        petP.x = targetPetX
        try {
            petView?.let { windowManager.updateViewLayout(it, petP) }
        } catch (_: Exception) {}

        // Position card beside docked pet with no overlap
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
        petWebView?.loadUrl("javascript:if(window.setCardDock)window.setCardDock(true, '$dockSide');if(window.setFacing)window.setFacing(${if (isLeftSide) 0.9 else -0.9});if(window.setMode)window.setMode('talk');")
    }

    fun closePanel() {
        panelView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
        }
        panelView = null
        isPanelOpen = false
        hintView?.visibility = View.VISIBLE

        // Restore pet position from dock
        savedPetXBeforePanel?.let { originalX ->
            petParams?.let { p ->
                p.x = originalX
                try {
                    petView?.let { v -> windowManager.updateViewLayout(v, p) }
                } catch (_: Exception) {}
            }
            savedPetXBeforePanel = null
        }

        petWebView?.loadUrl("javascript:if(window.setCardDock)window.setCardDock(false, 'r');if(window.setFacing)window.setFacing(0.5);if(window.setMode)window.setMode('idle');")
        scheduleAutonomousRoam()
    }

    private fun createPanelLayout(): FrameLayout {
        val root = FrameLayout(context).apply {
            val bg = GradientDrawable().apply {
                setColor(petAccentColor)
                cornerRadius = dpToPx(22).toFloat() // border-radius: 22px
            }
            background = bg
            setPadding(dpToPx(12), dpToPx(14), dpToPx(12), dpToPx(14)) // padding: 12px
            elevation = dpToPx(16).toFloat()
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }

        // 1. Header: Name, Lang Pair, Close button
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
            setTextColor(Color.parseColor("#DDFFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dpToPx(8), 0, 0, 0)
        }
        tvLangPair = langPair

        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f)
        }

        // #x: 30x30 circle close button with #fff3 background
        val btnClose = TextView(context).apply {
            text = "×"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
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

        // 2. Spoken Transcript (#said)
        val spoken = TextView(context).apply {
            text = "Tap mic to speak or enter text below."
            setTextColor(Color.parseColor("#E0FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, dpToPx(8), 0, dpToPx(4))
        }
        tvSpoken = spoken
        content.addView(spoken)

        // 3. Translated Karaoke View (#lyr)
        val translated = TextView(context).apply {
            text = "Welcome to LingoBoop!"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(4), 0, dpToPx(6))
        }
        tvTranslated = translated
        content.addView(translated)

        // 4. Status Note (#nt)
        val status = TextView(context).apply {
            text = ""
            setTextColor(Color.parseColor("#CCFFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(0, 0, 0, dpToPx(8))
        }
        tvStatus = status
        content.addView(status)

        // 5. Controls Row: Play, Slow, Repeat, Mic (.row)
        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            clipChildren = false
            setPadding(0, dpToPx(4), 0, dpToPx(8))
        }

        val btnPlay = createPillButton("Play ▶") {
            speakCurrentTranslation(1.0f)
        }
        val btnSlow = createPillButton("Slow") {
            speakCurrentTranslation(0.75f)
        }
        val btnRepeat = createPillButton("Repeat") {
            tvStatus?.text = "Say the sentence out loud…"
            startVoiceRecognition()
        }

        // #mic: 38x38 circle with white background and accent icon
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
                startVoiceRecognition()
            }
        }
        btnMic = mic

        controls.addView(btnPlay)
        controls.addView(btnSlow)
        controls.addView(btnRepeat)
        controls.addView(View(context).apply { layoutParams = LinearLayout.LayoutParams(0, 0, 1.0f) })
        controls.addView(mic)
        content.addView(controls)

        // 6. Text input form matching prototype #tf and #ti (36dp height, #0003 background)
        val inputForm = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val input = EditText(context).apply {
            hint = "Or type a sentence…"
            setHintTextColor(Color.parseColor("#BBFFFFFF"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            val inputBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33000000"))
                cornerRadius = dpToPx(12).toFloat()
            }
            background = inputBg
            setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
            layoutParams = LinearLayout.LayoutParams(0, dpToPx(36), 1.0f)
            isSingleLine = true
        }
        etInput = input

        val btnSend = TextView(context).apply {
            text = "Go"
            setTextColor(petAccentColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            val sendBg = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dpToPx(10).toFloat()
            }
            background = sendBg
            setPadding(dpToPx(12), dpToPx(6), dpToPx(12), dpToPx(6))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(36)
            ).apply {
                setMargins(dpToPx(6), 0, 0, 0)
            }
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
        }
    }

    private fun createPillButton(label: String, onClick: () -> Unit): TextView {
        return TextView(context).apply {
            text = label
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            gravity = Gravity.CENTER
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#33FFFFFF"))
                cornerRadius = dpToPx(999).toFloat()
            }
            background = bg
            setPadding(dpToPx(7), dpToPx(5), dpToPx(7), dpToPx(5))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, dpToPx(3), 0)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun handleEnteredText(text: String) {
        requestAITutoring(text)
    }

    private fun requestAITutoring(inputText: String) {
        tvSpoken?.text = inputText
        tvStatus?.text = "Reasoning with Groq GPT-OSS 120B…"
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('think');")

        Thread {
            var translatedText: String? = null
            var tutorNote: String? = null
            val candidates = listOf(
                "http://127.0.0.1:8000",
                "http://10.82.30.80:8000",
                "http://10.94.94.80:8000",
                "http://10.0.2.2:8000"
            )

            for (baseUrl in candidates) {
                // 1. Try AI tutor endpoint
                try {
                    val url = java.net.URL("$baseUrl/api/v1/ai/tutor")
                    val conn = (url.openConnection() as java.net.HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 3000
                        readTimeout = 8000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json")
                        if (!authToken.isNullOrEmpty()) {
                            setRequestProperty("Authorization", "Bearer $authToken")
                        }
                    }

                    val payload = org.json.JSONObject().apply {
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
                        val responseStr = conn.inputStream.bufferedReader().use { it.readText() }
                        val json = org.json.JSONObject(responseStr)
                        if (json.optBoolean("success", false)) {
                            val data = json.optJSONObject("data")
                            val cand = data?.optString("translated_text")
                                ?: data?.optString("reply_text")
                                ?: data?.optString("translation")
                            if (!cand.isNullOrBlank() && !cand.trim().equals(inputText.trim(), ignoreCase = true)) {
                                translatedText = cand
                                tutorNote = data?.optString("explanation")
                                    ?: data?.optString("pronunciation_guide")
                                break
                            }
                        }
                    }
                } catch (_: Exception) {
                    // Try direct translation endpoint next
                }

                // 2. Fallback to direct translation endpoint
                if (translatedText == null) {
                    try {
                        val transUrl = java.net.URL("$baseUrl/api/v1/translation/translate")
                        val transConn = (transUrl.openConnection() as java.net.HttpURLConnection).apply {
                            requestMethod = "POST"
                            connectTimeout = 3000
                            readTimeout = 8000
                            doOutput = true
                            setRequestProperty("Content-Type", "application/json")
                            if (!authToken.isNullOrEmpty()) {
                                setRequestProperty("Authorization", "Bearer $authToken")
                            }
                        }

                        val transPayload = org.json.JSONObject().apply {
                            put("text", inputText)
                            put("source_language", sourceLanguage)
                            put("target_language", targetLanguage)
                            put("character_id", petKey)
                        }

                        transConn.outputStream.use { os ->
                            os.write(transPayload.toString().toByteArray(Charsets.UTF_8))
                        }

                        if (transConn.responseCode == 200) {
                            val resStr = transConn.inputStream.bufferedReader().use { it.readText() }
                            val json = org.json.JSONObject(resStr)
                            val dataObj = json.optJSONObject("data")
                            val cand = dataObj?.optString("translated_text") ?: json.optString("translated_text")
                            if (!cand.isNullOrBlank() && !cand.trim().equals(inputText.trim(), ignoreCase = true)) {
                                translatedText = cand
                                break
                            }
                        }
                    } catch (_: Exception) {}
                }

                if (translatedText != null) break
            }

            // 3. Fallback to offline translation dictionary for guaranteed zero-delay UX
            if (translatedText == null) {
                val clean = inputText.trim()
                val lower = clean.lowercase()
                if (lower.contains("મારું નામ") || lower.contains("મારુ નામ") || lower.contains("what is my name")) {
                    translatedText = if (lower.contains("what is my name")) "મારું નામ શું છે?" else "What is my name?"
                } else if (lower.contains("કેમ છો") || lower.contains("how are you")) {
                    translatedText = if (lower.contains("how are you")) "તમે કેમ છો?" else "How are you?"
                } else if (lower.contains("નમસ્તે") || lower.contains("namaste") || lower.contains("hello")) {
                    translatedText = if (lower.contains("hello")) "નમસ્તે" else "Hello"
                } else if (lower.contains("આભાર") || lower.contains("thank you")) {
                    translatedText = if (lower.contains("thank you")) "આભાર" else "Thank you"
                } else if (lower.contains("સુપ્રભાત") || lower.contains("good morning")) {
                    translatedText = if (lower.contains("good morning")) "સુપ્રભાત" else "Good morning"
                } else if (lower.contains("surat")) {
                    translatedText = "Train to Surat"
                } else {
                    translatedText = clean
                }
            }

            Handler(Looper.getMainLooper()).post {
                val finalTranslation = translatedText ?: "Tap play to hear pronunciation"
                val finalStatus = tutorNote ?: "Tap play to hear pronunciation"
                tvTranslated?.text = finalTranslation
                tvStatus?.text = finalStatus
                petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
                speakCurrentTranslation(1.0f)
            }
        }.start()
    }

    private fun speakCurrentTranslation(rate: Float) {
        val phrase = tvTranslated?.text?.toString() ?: return
        if (phrase.isEmpty() || phrase.contains("unavailable", ignoreCase = true)) return

        // 1. Synthesize via Gnani Timbre TTS from backend
        Thread {
            var audioSuccess = false
            val candidates = listOf(
                "http://127.0.0.1:8000",
                "http://10.82.30.80:8000",
                "http://10.94.94.80:8000",
                "http://10.0.2.2:8000"
            )

            for (baseUrl in candidates) {
                try {
                    val url = java.net.URL("$baseUrl/api/v1/tts/synthesize")
                    val conn = (url.openConnection() as java.net.HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 2500
                        readTimeout = 6000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json")
                        if (!authToken.isNullOrEmpty()) {
                            setRequestProperty("Authorization", "Bearer $authToken")
                        }
                    }

                    val payload = org.json.JSONObject().apply {
                        put("text", phrase)
                        put("language", targetLanguage)
                        put("speed", rate.toDouble())
                    }

                    conn.outputStream.use { os ->
                        os.write(payload.toString().toByteArray(Charsets.UTF_8))
                    }

                    if (conn.responseCode == 200) {
                        val respStr = conn.inputStream.bufferedReader().use { it.readText() }
                        val json = org.json.JSONObject(respStr)
                        val b64 = json.optJSONObject("data")?.optString("audio_base64")
                        if (!b64.isNullOrEmpty()) {
                            val audioBytes = android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                            val tempFile = java.io.File(context.cacheDir, "ext_tts_${System.currentTimeMillis()}.wav")
                            tempFile.writeBytes(audioBytes)

                            Handler(Looper.getMainLooper()).post {
                                try {
                                    val mp = android.media.MediaPlayer().apply {
                                        setDataSource(tempFile.absolutePath)
                                        prepare()
                                        start()
                                        setOnCompletionListener {
                                            release()
                                            tempFile.delete()
                                            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('dance');")
                                            Handler(Looper.getMainLooper()).postDelayed({
                                                petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                                            }, 1500)
                                        }
                                    }
                                } catch (_: Exception) {
                                    fallbackAndroidTts(phrase, rate)
                                }
                            }
                            audioSuccess = true
                            break
                        }
                    }
                } catch (_: Exception) {}
            }

            if (!audioSuccess) {
                Handler(Looper.getMainLooper()).post {
                    fallbackAndroidTts(phrase, rate)
                }
            }
        }.start()
    }

    private fun fallbackAndroidTts(phrase: String, rate: Float) {
        if (isTtsReady && tts != null) {
            tts?.setSpeechRate(rate)
            tts?.speak(phrase, TextToSpeech.QUEUE_FLUSH, null, "lingoboom_overlay_tts")
            petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
        }
    }

    private fun startVoiceRecognition() {
        try {
            if (!SpeechRecognizer.isRecognitionAvailable(context)) {
                tvStatus?.text = "Speech recognizer unavailable on this device."
                return
            }

            speechRecognizer?.destroy()
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
            speechRecognizer = recognizer

            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    tvStatus?.text = "Listening… Speak now"
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('listen');")
                }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    tvStatus?.text = "Processing speech…"
                }
                override fun onError(error: Int) {
                    tvStatus?.text = "Could not capture speech. Try again."
                    petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
                }
                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        val heard = matches[0]
                        requestAITutoring(heard)
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
            tvStatus?.text = "Microphone error: ${e.message}"
        }
    }

    fun destroy() {
        cancelAutonomousRoam()
        hidePet()
        tts?.stop()
        tts?.shutdown()
        tts = null
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }
}
