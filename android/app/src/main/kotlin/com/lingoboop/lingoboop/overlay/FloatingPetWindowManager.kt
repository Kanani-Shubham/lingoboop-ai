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
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.*
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.*
import java.util.*
import kotlin.math.hypot

class FloatingPetWindowManager(private val context: Context) : TextToSpeech.OnInitListener {

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val prefs: SharedPreferences =
        context.getSharedPreferences("lingoboom_overlay_prefs", Context.MODE_PRIVATE)

    private var petView: FrameLayout? = null
    private var petWebView: WebView? = null
    private var petParams: WindowManager.LayoutParams? = null

    private var panelView: FrameLayout? = null
    private var isPanelOpen = false

    private var petKey: String = "fox"
    private var petName: String = "Maru"
    private var petAccentColor: Int = Color.parseColor("#c4571c")
    private var sourceLanguage: String = "gu-IN"
    private var targetLanguage: String = "en-US"

    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var speechRecognizer: SpeechRecognizer? = null

    // UI elements in floating panel
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

        petWebView?.post {
            petWebView?.loadUrl("javascript:if(window.setPet)window.setPet('$petKey');")
        }

        updatePanelTheme()
    }

    fun updateLanguages(src: String, tgt: String) {
        sourceLanguage = src
        targetLanguage = tgt
        prefs.edit().putString("source_lang", src)
            .putString("target_lang", tgt)
            .apply()

        tvLangPair?.text = "$sourceLanguage → $targetLanguage"
    }

    @SuppressLint("SetJavaScriptEnabled", "ClickableViewAccessibility")
    fun showPet() {
        if (petView != null) return

        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)

        val sizePx = dpToPx(130)
        val initialX = prefs.getInt("pos_x", dm.widthPixels - sizePx - dpToPx(16))
        val initialY = prefs.getInt("pos_y", dpToPx(180))

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = initialX.coerceIn(0, dm.widthPixels - sizePx)
            y = initialY.coerceIn(dpToPx(40), dm.heightPixels - sizePx - dpToPx(60))
        }
        petParams = params

        val container = FrameLayout(context).apply {
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
                cacheMode = WebSettings.LOAD_DEFAULT
            }
            loadUrl("file:///android_asset/flutter_assets/assets/web/pet_viewer.html")
        }
        petWebView = webView

        container.addView(
            webView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // Draggable Touch Listener with boundary clamping and click detection
        var touchStartX = 0f
        var touchStartY = 0f
        var viewStartX = 0
        var viewStartY = 0

        container.setOnTouchListener { _, event ->
            val curParams = petParams ?: return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
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
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val totalDist = hypot((event.rawX - touchStartX).toDouble(), (event.rawY - touchStartY).toDouble())
                    webView.loadUrl("javascript:if(window.setMode)window.setMode('idle');")

                    // Save position
                    prefs.edit().putInt("pos_x", curParams.x).putInt("pos_y", curParams.y).apply()

                    if (totalDist < dpToPx(12)) {
                        togglePanel()
                    }
                    true
                }
                else -> false
            }
        }

        petView = container
        windowManager.addView(container, params)
    }

    fun hidePet() {
        closePanel()
        petView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
        }
        petView = null
        petWebView = null
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

        val dm = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(dm)

        val petP = petParams ?: return
        val panelWidth = dpToPx(270)
        val panelHeight = dpToPx(340)

        // Docking positioning matching HTML prototype
        var posX = if (petP.x + dpToPx(65) < dm.widthPixels / 2) {
            petP.x + dpToPx(130)
        } else {
            petP.x - panelWidth
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
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
    }

    fun closePanel() {
        panelView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
        }
        panelView = null
        isPanelOpen = false
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('idle');")
    }

    private fun createPanelLayout(): FrameLayout {
        val root = FrameLayout(context).apply {
            val bg = GradientDrawable().apply {
                setColor(petAccentColor)
                cornerRadius = dpToPx(22).toFloat()
            }
            background = bg
            setPadding(dpToPx(14), dpToPx(14), dpToPx(14), dpToPx(14))
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

        val btnClose = TextView(context).apply {
            text = "×"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            gravity = Gravity.CENTER
            val circle = GradientDrawable().apply {
                setColor(Color.parseColor("#33FFFFFF"))
                shape = GradientDrawable.OVAL
            }
            background = circle
            layoutParams = LinearLayout.LayoutParams(dpToPx(28), dpToPx(28))
            setOnClickListener { closePanel() }
        }

        header.addView(title)
        header.addView(langPair)
        header.addView(spacer)
        header.addView(btnClose)
        content.addView(header)

        // 2. Spoken Transcript
        val spoken = TextView(context).apply {
            text = "Tap mic to speak or enter text below."
            setTextColor(Color.parseColor("#E0FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(0, dpToPx(8), 0, dpToPx(4))
        }
        tvSpoken = spoken
        content.addView(spoken)

        // 3. Translated Lyrics View
        val translated = TextView(context).apply {
            text = "Welcome to LingoBoom!"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(0, dpToPx(4), 0, dpToPx(6))
        }
        tvTranslated = translated
        content.addView(translated)

        // 4. Status Note
        val status = TextView(context).apply {
            text = ""
            setTextColor(Color.parseColor("#CCFFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(0, 0, 0, dpToPx(8))
        }
        tvStatus = status
        content.addView(status)

        // 5. Controls Row: Play, Slow, Repeat, Mic
        val controls = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dpToPx(4), 0, dpToPx(8))
        }

        val btnPlay = createPillButton("Play ▶") {
            speakCurrentTranslation(1.0f)
        }
        val btnSlow = createPillButton("Slow") {
            speakCurrentTranslation(0.7f)
        }
        val btnRepeat = createPillButton("Repeat") {
            tvStatus?.text = "Say the sentence out loud…"
            startVoiceRecognition()
        }

        val mic = ImageButton(context).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            val micBg = GradientDrawable().apply {
                setColor(Color.WHITE)
                shape = GradientDrawable.OVAL
            }
            background = micBg
            setColorFilter(petAccentColor)
            layoutParams = LinearLayout.LayoutParams(dpToPx(42), dpToPx(42)).apply {
                setMargins(dpToPx(8), 0, 0, 0)
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

        // 6. Text input form matching prototype #tf
        val inputForm = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val input = EditText(context).apply {
            hint = "Or type a sentence…"
            setHintTextColor(Color.parseColor("#99FFFFFF"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            val inputBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33000000"))
                cornerRadius = dpToPx(10).toFloat()
            }
            background = inputBg
            setPadding(dpToPx(10), dpToPx(8), dpToPx(10), dpToPx(8))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
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
            setPadding(dpToPx(12), dpToPx(8), dpToPx(12), dpToPx(8))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
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
            setPadding(dpToPx(10), dpToPx(6), dpToPx(10), dpToPx(6))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, dpToPx(6), 0)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun handleEnteredText(text: String) {
        tvSpoken?.text = text
        tvTranslated?.text = text
        tvStatus?.text = "Playing speech…"
        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('talk');")
        speakCurrentTranslation(1.0f)
    }

    private fun speakCurrentTranslation(rate: Float) {
        val phrase = tvTranslated?.text?.toString() ?: return
        if (phrase.isEmpty()) return

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
                        tvSpoken?.text = heard
                        tvTranslated?.text = heard
                        tvStatus?.text = "Speech recognized!"
                        petWebView?.loadUrl("javascript:if(window.setMode)window.setMode('dance');")
                        speakCurrentTranslation(1.0f)
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
