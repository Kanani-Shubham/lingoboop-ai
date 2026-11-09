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

    // VAD Configuration thresholds (Dynamic & Adaptive)
    var silenceThresholdDbfs: Double = -42.0
    var silenceTimeoutMs: Long = 850L            // 850ms silence after speech to auto-stop (between 700-1000ms)
    var minSpeechDurationMs: Long = 280L         // 280ms minimum speech to prevent false clicks (250-350ms)
    var initialSpeechTimeoutMs: Long = 7000L     // 7s timeout if no speech detected at all
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
        Log.i(TAG, "[MIC_START] timestamp=${tMicTap}ms")
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
                val preSpeechRing = ArrayDeque<ByteArray>(4) // 4 frames * 64ms = ~256ms pre-speech buffer
                var speechDetected = false
                var speechStartTime = 0L
                var lastSpeechTime = 0L
                var firstSpeechLogged = false
                val startTime = System.currentTimeMillis()

                // Adaptive Noise Floor calibration
                var ambientDbfsSum = 0.0
                var ambientFramesCount = 0
                var currentSpeechThreshold = silenceThresholdDbfs
                var currentSilenceThreshold = silenceThresholdDbfs - 4.0

                while (isRecording) {
                    val read = record.read(shortBuffer, 0, shortBuffer.size)
                    if (read > 0) {
                        val now = System.currentTimeMillis()
                        var sumSquares = 0.0
                        val frameBytes = ByteArray(read * 2)
                        var bIdx = 0
                        for (i in 0 until read) {
                            val sample = shortBuffer[i].toInt()
                            sumSquares += sample * sample
                            val b1 = (sample and 0xFF).toByte()
                            val b2 = ((sample shr 8) and 0xFF).toByte()
                            frameBytes[bIdx++] = b1
                            frameBytes[bIdx++] = b2
                        }

                        val rms = sqrt(sumSquares / read)
                        val dbfs = if (rms > 0) 20.0 * log10(rms / 32768.0) else -999.0

                        mainHandler.post {
                            listener.onSpeechActive(now, dbfs, rms)
                        }

                        // Calibrate noise floor on initial 4 frames (~256ms)
                        if (ambientFramesCount < 4) {
                            if (dbfs > -900.0) {
                                ambientDbfsSum += dbfs
                                ambientFramesCount++
                                if (ambientFramesCount == 4) {
                                    val avgAmbient = ambientDbfsSum / 4.0
                                    currentSpeechThreshold = maxOf(avgAmbient + 6.0, -42.0).coerceIn(-44.0, -28.0)
                                    currentSilenceThreshold = currentSpeechThreshold - 4.0
                                    Log.i(TAG, "[VAD_CALIBRATION] Ambient: ${avgAmbient.roundToInt()} dBFS, SpeechThreshold: ${currentSpeechThreshold.roundToInt()} dBFS, SilenceThreshold: ${currentSilenceThreshold.roundToInt()} dBFS")
                                }
                            }
                        }

                        if (!speechDetected) {
                            if (preSpeechRing.size >= 4) preSpeechRing.removeFirst()
                            preSpeechRing.addLast(frameBytes)

                            if (dbfs > currentSpeechThreshold) {
                                if (speechStartTime == 0L) {
                                    speechStartTime = now
                                }
                                if (now - speechStartTime >= minSpeechDurationMs) {
                                    speechDetected = true
                                    // Flush pre-speech buffer to capture initial consonants/syllables cleanly
                                    for (fb in preSpeechRing) {
                                        pcmData.write(fb)
                                    }
                                    preSpeechRing.clear()

                                    if (!firstSpeechLogged) {
                                        firstSpeechLogged = true
                                        Log.i(TAG, "[SPEECH_DETECTED] timestamp=${now}ms dbfs=${dbfs.roundToInt()} rms=${rms.roundToInt()}")
                                        mainHandler.post {
                                            listener.onFirstSpeechDetected(now, dbfs, rms)
                                        }
                                    }
                                    lastSpeechTime = now
                                }
                            } else {
                                if (speechStartTime > 0L && (now - speechStartTime < minSpeechDurationMs)) {
                                    speechStartTime = 0L // Discard transient click/pop
                                }
                                if (now - startTime > initialSpeechTimeoutMs) {
                                    Log.i(TAG, "[SPEECH_END_DETECTED] No speech detected within ${initialSpeechTimeoutMs}ms, auto-cancelling")
                                    break
                                }
                            }
                        } else {
                            // Speech active or trailing
                            pcmData.write(frameBytes)

                            if (dbfs > currentSilenceThreshold) {
                                lastSpeechTime = now
                            } else {
                                // Trailing silence check
                                if (now - lastSpeechTime > silenceTimeoutMs) {
                                    val silenceDuration = now - lastSpeechTime
                                    Log.i(TAG, "[SPEECH_END_DETECTED] timestamp=${now}ms silenceDuration=${silenceDuration}ms")
                                    mainHandler.post {
                                        listener.onSilenceThresholdReached(now, silenceDuration)
                                    }
                                    break
                                }
                            }
                        }

                        // Safety guard against runaway recordings
                        if (now - startTime > maxRecordingDurationMs) {
                            Log.i(TAG, "[SPEECH_END_DETECTED] Max recording duration (${maxRecordingDurationMs}ms) reached")
                            break
                        }
                    }
                }

                // Flush trailing 300ms buffer to preserve complete final consonants/word endings
                try {
                    val flushBuffer = ShortArray(4800)
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

                Log.i(TAG, "[RECORDING_FINALIZED] timestamp=${System.currentTimeMillis()}ms duration=${durationSec}s path=${wavFile?.absolutePath}")

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

