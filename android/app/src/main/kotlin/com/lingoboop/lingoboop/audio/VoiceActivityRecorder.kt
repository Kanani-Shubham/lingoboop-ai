package com.lingoboop.lingoboop.audio

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.log10
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Shared Voice Activity Detection (VAD) audio recorder.
 * Provides identical automatic speech-end detection inside Flutter and in the floating overlay.
 */
class VoiceActivityRecorder private constructor(private val appContext: Context) {

    companion object {
        private const val TAG = "VoiceActivityRecorder"
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        @Volatile
        private var instance: VoiceActivityRecorder? = null

        fun getInstance(context: Context): VoiceActivityRecorder {
            return instance ?: synchronized(this) {
                instance ?: VoiceActivityRecorder(context.applicationContext).also { instance = it }
            }
        }
    }

    interface VadListener {
        fun onRecordingStarted(startTimeMs: Long)
        fun onFirstSpeechDetected(timeMs: Long, dbfs: Double, rms: Double)
        fun onSpeechActive(timeMs: Long, dbfs: Double, rms: Double)
        fun onSilenceThresholdReached(timeMs: Long, silenceDurationMs: Long)
        fun onRecordingStopped(wavFile: File?, rawPcm: ByteArray, speechDetected: Boolean, durationSec: Double)
        fun onError(message: String)
    }

    private val audioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var isRecording: Boolean = false
        private set

    private var audioRecord: AudioRecord? = null

    // VAD Configuration thresholds
    var silenceThresholdDbfs: Double = -46.0
    var silenceTimeoutMs: Long = 1200L           // 1.2s silence after speech to auto-stop
    var minSpeechDurationMs: Long = 300L         // 300ms minimum speech to prevent false clicks
    var initialSpeechTimeoutMs: Long = 8000L     // 8s timeout if no speech detected at all
    var maxRecordingDurationMs: Long = 35000L    // 35s max duration guard

    init {
        // Pre-warm AudioRecord on background thread in STOPPED state
        audioExecutor.execute {
            getOrCreateAudioRecord()
        }
    }

    @Synchronized
    private fun getOrCreateAudioRecord(): AudioRecord? {
        val existing = audioRecord
        if (existing != null && existing.state == AudioRecord.STATE_INITIALIZED) {
            return existing
        }
        return try {
            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            val bufferSize = maxOf(minBufferSize * 2, 8192)
            @SuppressLint("MissingPermission")
            val record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )
            if (record.state == AudioRecord.STATE_INITIALIZED) {
                audioRecord = record
                Log.i(TAG, "AudioRecord pre-warmed successfully (state=STATE_INITIALIZED, stopped)")
                record
            } else {
                record.release()
                audioRecord = null
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "AudioRecord init failed: ${e.message}")
            audioRecord = null
            null
        }
    }

    /**
     * Start recording with automatic Voice Activity Detection (VAD).
     */
    fun startRecording(listener: VadListener) {
        if (isRecording) {
            Log.w(TAG, "Recording already active, ignoring start request")
            return
        }

        val tMicTap = System.currentTimeMillis()
        Log.i(TAG, "[MIC_BENCHMARK] MIC_TAP: ${tMicTap}ms")
        isRecording = true

        audioExecutor.execute {
            val record = getOrCreateAudioRecord()
            if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
                isRecording = false
                mainHandler.post {
                    listener.onError("AudioRecord initialization failed")
                }
                return@execute
            }

            try {
                record.startRecording()
                val tStarted = System.currentTimeMillis()
                Log.i(TAG, "[MIC_BENCHMARK] RECORDING_STARTED: ${tStarted - tMicTap}ms after tap")
                mainHandler.post {
                    listener.onRecordingStarted(tStarted)
                }

                val shortBuffer = ShortArray(1024)
                val pcmData = ByteArrayOutputStream()
                var speechDetected = false
                var speechStartTime = 0L
                var lastSpeechTime = 0L
                var firstSpeechLogged = false
                val startTime = System.currentTimeMillis()

                while (isRecording) {
                    val read = record.read(shortBuffer, 0, shortBuffer.size)
                    if (read > 0) {
                        val now = System.currentTimeMillis()
                        var sumSquares = 0.0
                        for (i in 0 until read) {
                            val sample = shortBuffer[i].toInt()
                            sumSquares += sample * sample
                            pcmData.write(sample and 0xFF)
                            pcmData.write((sample shr 8) and 0xFF)
                        }

                        val rms = sqrt(sumSquares / read)
                        val dbfs = if (rms > 0) 20.0 * log10(rms / 32768.0) else -999.0

                        mainHandler.post {
                            listener.onSpeechActive(now, dbfs, rms)
                        }

                        if (dbfs > silenceThresholdDbfs) {
                            if (!speechDetected) {
                                if (speechStartTime == 0L) {
                                    speechStartTime = now
                                }
                                if (now - speechStartTime >= minSpeechDurationMs) {
                                    speechDetected = true
                                    if (!firstSpeechLogged) {
                                        firstSpeechLogged = true
                                        Log.i(TAG, "[MIC_BENCHMARK] FIRST_SPEECH_DETECTED: ${now - tMicTap}ms (RMS: ${rms.roundToInt()}, dBFS: ${dbfs.roundToInt()})")
                                        mainHandler.post {
                                            listener.onFirstSpeechDetected(now, dbfs, rms)
                                        }
                                    }
                                }
                            }
                            lastSpeechTime = now
                        } else {
                            if (!speechDetected && speechStartTime > 0L && (now - speechStartTime < minSpeechDurationMs)) {
                                // Transient noise spike (e.g. mic click); reset candidate timer
                                speechStartTime = 0L
                            }

                            // 1. Trailing silence auto-stop after speech
                            if (speechDetected && (now - lastSpeechTime > silenceTimeoutMs)) {
                                val silenceDuration = now - lastSpeechTime
                                Log.i(TAG, "[MIC_BENCHMARK] LAST_SPEECH_DETECTED: ${lastSpeechTime - tMicTap}ms")
                                Log.i(TAG, "[MIC_BENCHMARK] SILENCE_THRESHOLD_REACHED: ${now - tMicTap}ms (silence: ${silenceDuration}ms after last speech)")
                                mainHandler.post {
                                    listener.onSilenceThresholdReached(now, silenceDuration)
                                }
                                break
                            }

                            // 2. Initial silence timeout (no speech detected at all within initial window)
                            if (!speechDetected && (now - startTime > initialSpeechTimeoutMs)) {
                                Log.i(TAG, "No speech detected within ${initialSpeechTimeoutMs}ms, auto-cancelling")
                                break
                            }
                        }

                        // 3. Safety guard against runaway recordings
                        if (now - startTime > maxRecordingDurationMs) {
                            Log.i(TAG, "Max recording duration (${maxRecordingDurationMs}ms) reached")
                            break
                        }
                    }
                }

                // Flush trailing 400ms buffer to preserve complete final consonants/word endings
                try {
                    val flushBuffer = ShortArray(6400)
                    val readFlush = record.read(flushBuffer, 0, flushBuffer.size)
                    if (readFlush > 0) {
                        for (i in 0 until readFlush) {
                            val sample = flushBuffer[i].toInt()
                            pcmData.write(sample and 0xFF)
                            pcmData.write((sample shr 8) and 0xFF)
                        }
                    }
                } catch (_: Exception) {}

                val tStopped = System.currentTimeMillis()
                try {
                    record.stop() // Leaves AudioRecord pre-warmed for next tap!
                } catch (_: Exception) {}
                isRecording = false
                Log.i(TAG, "[MIC_BENCHMARK] RECORDING_STOPPED: ${tStopped - tMicTap}ms after tap")

                val rawPcm = pcmData.toByteArray()
                val durationSec = rawPcm.size / 32000.0

                var wavFile: File? = null
                if (rawPcm.isNotEmpty() && (speechDetected || durationSec >= 0.5)) {
                    val wavBytes = makeWav(rawPcm, SAMPLE_RATE, 1, 16)
                    val cacheFile = File(appContext.cacheDir, "rec_vad_${System.currentTimeMillis()}.wav")
                    cacheFile.writeBytes(wavBytes)
                    wavFile = cacheFile
                }

                mainHandler.post {
                    listener.onRecordingStopped(wavFile, rawPcm, speechDetected, durationSec)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Audio capture error: ${e.message}", e)
                try {
                    record.stop()
                } catch (_: Exception) {}
                isRecording = false
                mainHandler.post {
                    listener.onError(e.message ?: "Audio capture error")
                }
            }
        }
    }

    /**
     * Manually stop recording and finalize audio immediately.
     */
    fun stopRecordingManually() {
        if (!isRecording) return
        isRecording = false
    }

    /**
     * Cancel recording immediately and discard audio.
     */
    fun cancelRecording() {
        isRecording = false
        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
    }

    /**
     * Synthesize standard 44-byte RIFF/WAVE header for raw 16-bit 16kHz mono PCM.
     */
    fun makeWav(pcmData: ByteArray, sampleRate: Int = 16000, channels: Int = 1, bitsPerSample: Int = 16): ByteArray {
        val totalAudioLen = pcmData.size
        val totalDataLen = totalAudioLen + 36
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8

        val header = ByteArray(44)
        ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN).apply {
            put('R'.code.toByte())
            put('I'.code.toByte())
            put('F'.code.toByte())
            put('F'.code.toByte())
            putInt(totalDataLen)
            put('W'.code.toByte())
            put('A'.code.toByte())
            put('V'.code.toByte())
            put('E'.code.toByte())
            put('f'.code.toByte())
            put('m'.code.toByte())
            put('t'.code.toByte())
            put(' '.code.toByte())
            putInt(16) // Subchunk1Size for PCM
            putShort(1.toShort()) // AudioFormat 1 = PCM
            putShort(channels.toShort())
            putInt(sampleRate)
            putInt(byteRate)
            putShort(blockAlign.toShort())
            putShort(bitsPerSample.toShort())
            put('d'.code.toByte())
            put('a'.code.toByte())
            put('t'.code.toByte())
            put('a'.code.toByte())
            putInt(totalAudioLen)
        }

        val wavBytes = ByteArray(header.size + pcmData.size)
        System.arraycopy(header, 0, wavBytes, 0, header.size)
        System.arraycopy(pcmData, 0, wavBytes, header.size, pcmData.size)
        return wavBytes
    }

    fun release() {
        cancelRecording()
        try {
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }
}

