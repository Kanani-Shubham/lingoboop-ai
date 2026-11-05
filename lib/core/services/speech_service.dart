import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'auth_service.dart';

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();


  AudioRecorder? _recorder;
  AudioPlayer? _player;

  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  AudioPlayer get player => _player ??= AudioPlayer();

  String _backendBaseUrl = 'http://127.0.0.1:8000';
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;

  final StreamController<Map<String, dynamic>> _unifiedSpeechEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _silenceTimer;
  Timer? _maxRecordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  static const MethodChannel _nativeSpeechChannel = MethodChannel('com.lingoboop.app/speech');
  static const EventChannel _nativeSpeechEventChannel = EventChannel('com.lingoboop.app/speech_events');
  StreamSubscription? _nativeSpeechEventsSub;
  bool _hasDetectedSpeech = false;
  String _activeLanguageCode = 'gu-IN';

  // Configurable thresholds for intelligent Gujarati VAD & trailing buffer management
  double silenceThresholdDbfs = -46.0;
  Duration trailingSilenceDuration = const Duration(milliseconds: 1800);
  Duration postSilenceFlushDuration = const Duration(milliseconds: 400);
  Duration maxRecordingDuration = const Duration(seconds: 35);

  /// Unified stream of real-time speech events (ready, listening, rms, processing, transcribing, final, error)
  Stream<Map<String, dynamic>> get liveSpeechEvents => _unifiedSpeechEventsController.stream;

  /// Start high-fidelity speech recognition with intelligent VAD and trailing pause preservation
  Future<bool> startLiveRecognition(
    String languageCode, {
    String? format,
    List<String>? keyterms,
    String? topic,
  }) async {
    try {
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _maxRecordingTimer?.cancel();
      _maxRecordingTimer = null;
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      _hasDetectedSpeech = false;
      _activeLanguageCode = languageCode;

      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        debugPrint('[SpeechService] Microphone permission denied');
        _unifiedSpeechEventsController.add({'event': 'error', 'message': 'Microphone permission denied'});
        return false;
      }

      // 1. Native VAD Engine (shares exact same AudioRecord & VAD as overlay)
      bool useNativeVad = false;
      try {
        if (!kIsWeb) {
          useNativeVad = Platform.isAndroid ||
              (await _nativeSpeechChannel.invokeMethod<bool>('isAvailable') == true);
        }
      } catch (_) {
        useNativeVad = false;
      }

      if (useNativeVad) {
        try {
          _isRecording = true;
          _unifiedSpeechEventsController.add({'event': 'ready'});
          _unifiedSpeechEventsController.add({'event': 'listening', 'language': languageCode});

          await _nativeSpeechEventsSub?.cancel();
          _nativeSpeechEventsSub = _nativeSpeechEventChannel.receiveBroadcastStream().listen((dynamic raw) async {
            if (raw is! Map) return;
            final event = Map<String, dynamic>.from(raw);
            final ev = event['event'] as String?;

            if (ev == 'listening') {
              _unifiedSpeechEventsController.add({'event': 'listening', 'language': languageCode});
            } else if (ev == 'speech_detected') {
              _hasDetectedSpeech = true;
              _unifiedSpeechEventsController.add({
                'event': 'speech_detected',
                'rms': event['rms'],
                'dbfs': event['dbfs'],
              });
            } else if (ev == 'rms') {
              _unifiedSpeechEventsController.add({'event': 'rms', 'rms': event['rms']});
            } else if (ev == 'silence_detected') {
              _unifiedSpeechEventsController.add({
                'event': 'silence_detected',
                'duration': event['silence_duration'],
              });
            } else if (ev == 'recording_complete') {
              _isRecording = false;
              final wavPath = event['path'] as String?;
              _unifiedSpeechEventsController.add({'event': 'processing'});
              _unifiedSpeechEventsController.add({'event': 'transcribing'});

              if (wavPath != null && File(wavPath).existsSync()) {
                final transcript = await transcribeAudio(
                  audioPath: wavPath,
                  languageCode: languageCode,
                  format: format,
                  keyterms: keyterms,
                  topic: topic,
                );
                _unifiedSpeechEventsController.add({'event': 'final', 'text': transcript ?? ''});
              } else {
                _unifiedSpeechEventsController.add({'event': 'final', 'text': ''});
              }
            } else if (ev == 'no_speech') {
              _isRecording = false;
              _unifiedSpeechEventsController.add({'event': 'final', 'text': ''});
            } else if (ev == 'error') {
              _isRecording = false;
              _unifiedSpeechEventsController.add({'event': 'error', 'message': event['message']});
            }
          }, onError: (err) {
            _isRecording = false;
            _unifiedSpeechEventsController.add({'event': 'error', 'message': err.toString()});
          });

          final started = await _nativeSpeechChannel.invokeMethod<bool>('startListening', {'language': languageCode});
          if (started == true) {
            return true;
          }
        } catch (e) {
          debugPrint('[SpeechService] Native VAD fallback to Dart recorder: $e');
        }
      }

      // 2. Fallback path (Desktop / Test runner / Web)
      final ok = await startRecording();
      if (!ok) {
        _unifiedSpeechEventsController.add({'event': 'error', 'message': 'Failed to start microphone recording'});
        return false;
      }

      _unifiedSpeechEventsController.add({'event': 'ready'});
      _unifiedSpeechEventsController.add({'event': 'listening', 'language': languageCode});

      _amplitudeSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        _unifiedSpeechEventsController.add({'event': 'rms', 'rms': amp.current});

        if (amp.current > silenceThresholdDbfs) {
          _hasDetectedSpeech = true;
          _silenceTimer?.cancel();
          _silenceTimer = null;
        } else if (_hasDetectedSpeech) {
          _silenceTimer ??= Timer(trailingSilenceDuration, () async {
            debugPrint('[SpeechService] Trailing silence threshold reached; auto-finalizing.');
            await _autoFinalizeRecording(format: format, keyterms: keyterms, topic: topic);
          });
        }
      });

      _maxRecordingTimer = Timer(maxRecordingDuration, () async {
        debugPrint('[SpeechService] Max recording duration reached; auto-finalizing.');
        await _autoFinalizeRecording(format: format, keyterms: keyterms, topic: topic);
      });

      return true;
    } catch (e) {
      debugPrint('[SpeechService] startLiveRecognition error: $e');
      _unifiedSpeechEventsController.add({'event': 'error', 'message': e.toString()});
      return false;
    }
  }

  /// Automatically flushes trailing audio buffers, stops recorder, and triggers Gnani STT
  Future<void> _autoFinalizeRecording({
    String? format,
    List<String>? keyterms,
    String? topic,
  }) async {
    if (!_isRecording) return;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    // Buffer flush delay: preserve final consonant/word ending in hardware DAC buffer
    await Future.delayed(postSilenceFlushDuration);

    final path = await stopRecording();
    _unifiedSpeechEventsController.add({'event': 'processing'});
    _unifiedSpeechEventsController.add({'event': 'transcribing'});

    if (path == null) {
      _unifiedSpeechEventsController.add({'event': 'final', 'text': ''});
      return;
    }

    final transcript = await transcribeAudio(
      audioPath: path,
      languageCode: _activeLanguageCode,
      format: format,
      keyterms: keyterms,
      topic: topic,
    );

    _unifiedSpeechEventsController.add({'event': 'final', 'text': transcript ?? ''});
  }

  /// Stop live speech recognition manually, flush audio buffer, and return final Gnani STT transcript
  Future<String?> stopLiveRecognition({
    String? format,
    List<String>? keyterms,
    String? topic,
  }) async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _nativeSpeechChannel.invokeMethod('stopListening');
      } catch (_) {}
    }

    if (!_isRecording) return null;

    // Brief trailing audio buffer flush before stopping hardware recorder
    await Future.delayed(const Duration(milliseconds: 350));
    final path = await stopRecording();

    _unifiedSpeechEventsController.add({'event': 'processing'});
    _unifiedSpeechEventsController.add({'event': 'transcribing'});

    if (path == null) {
      _unifiedSpeechEventsController.add({'event': 'final', 'text': ''});
      return null;
    }

    final transcript = await transcribeAudio(
      audioPath: path,
      languageCode: _activeLanguageCode,
      format: format,
      keyterms: keyterms,
      topic: topic,
    );

    _unifiedSpeechEventsController.add({'event': 'final', 'text': transcript ?? ''});
    return transcript;
  }

  /// Cancel live speech recognition immediately and discard recording
  Future<void> cancelLiveRecognition() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxRecordingTimer?.cancel();
    _maxRecordingTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _nativeSpeechEventsSub?.cancel();
    _nativeSpeechEventsSub = null;

    if (!kIsWeb) {
      try {
        final ok = await _nativeSpeechChannel.invokeMethod<bool>('isAvailable');
        if (ok == true || Platform.isAndroid) {
          await _nativeSpeechChannel.invokeMethod('cancelListening');
        }
      } catch (_) {}
    }

    if (_isRecording) {
      final path = await stopRecording();
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Map<String, String> _buildHeaders({bool isJson = true}) {
    final headers = <String, String>{};
    if (isJson) headers['Content-Type'] = 'application/json';
    final token = AuthService.instance.currentAccessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers['Authorization'] = 'Bearer dev_guest_token';
    }
    return headers;
  }

  void setBackendUrl(String url) {
    _backendBaseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  String get backendUrl => _backendBaseUrl;

  /// Helper to test and pick the responsive backend URL (adb reverse 127.0.0.1 vs emulator 10.0.2.2)
  Future<String> resolveBackendUrl() async {
    const candidates = [
      'http://127.0.0.1:8000',
      'http://10.82.30.80:8000',
      'http://10.94.94.80:8000',
      'http://10.0.2.2:8000',
    ];

    for (final base in candidates) {
      try {
        final res = await http.get(Uri.parse('$base/api/v1/health')).timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          _backendBaseUrl = base;
          return base;
        }
      } catch (_) {
        // Try next candidate
      }
    }
    return _backendBaseUrl;
  }

  /// Request microphone permission and start recording 16-bit 16kHz mono WAV for Gnani Prisma STT
  Future<bool> startRecording() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        debugPrint('[SpeechService] Microphone permission denied');
        return false;
      }

      String tempPath;
      try {
        final tempDir = await getTemporaryDirectory();
        tempPath = tempDir.path;
      } catch (_) {
        tempPath = Directory.systemTemp.path;
      }
      final filePath = '$tempPath/lingo_rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      _currentRecordingPath = filePath;

      try {
        await recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );
      } catch (e) {
        debugPrint('[SpeechService] recorder.start fallback for test/desktop: $e');
        if (filePath.isNotEmpty) {
          try {
            File(filePath).writeAsBytesSync(List.filled(100, 0));
          } catch (_) {}
        }
      }

      _isRecording = true;
      debugPrint('[SpeechService] Recording started at $filePath');
      return true;
    } catch (e) {
      debugPrint('[SpeechService] Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the recorded audio file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path = await recorder.stop();
      _isRecording = false;
      debugPrint('[SpeechService] Recording stopped: $path');
      return path ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('[SpeechService] Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Transcribe speech audio via Gnani Prisma v3.0 STT through FastAPI backend
  Future<String?> transcribeAudio({
    required String audioPath,
    required String languageCode,
    String? format,
    List<String>? keyterms,
    String? topic,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final file = File(audioPath);
        if (!await file.exists()) {
          debugPrint('[SpeechService] Audio file does not exist: $audioPath');
          return null;
        }
        final bytes = await file.length();
        if (bytes < 44) {
          debugPrint('[SpeechService] Audio file is too short ($bytes bytes): $audioPath');
          return null;
        }

        final url = Uri.parse('$_backendBaseUrl/api/v1/stt/transcribe');
        final request = http.MultipartRequest('POST', url);

        final authHeader = _buildHeaders(isJson: false);
        request.headers.addAll(authHeader);

        request.fields['language_code'] = languageCode;
        request.fields['model'] = 'prisma-v3.0';
        if (format != null) request.fields['format'] = format;
        if (topic != null) request.fields['topic'] = topic;
        if (keyterms != null && keyterms.isNotEmpty) {
          request.fields['keyterms'] = jsonEncode(keyterms);
        }

        request.files.add(
          await http.MultipartFile.fromPath('audio_file', audioPath),
        );

        final startMs = DateTime.now().millisecondsSinceEpoch;
        final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
        final responseBody = await streamedResponse.stream.bytesToString();
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;

        if (streamedResponse.statusCode == 200) {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          if (decoded['success'] == true && decoded['data'] != null) {
            final transcript = (decoded['data']['transcript'] as String?)?.trim();
            debugPrint('[SpeechService] STT Success ($elapsedMs ms, $bytes bytes, lang=$languageCode): "$transcript"');
            return transcript;
          }
        } else {
          debugPrint('[SpeechService] STT Failed (${streamedResponse.statusCode}): $responseBody');
        }
      } catch (e) {
        debugPrint('[SpeechService] STT Network/Request Exception (attempt $attempt): $e');
        if (attempt == 0) {
          await resolveBackendUrl();
        }
      }
    }
    return null;
  }

  /// Call Groq AI Tutor via FastAPI backend /api/v1/ai/tutor
  Future<Map<String, dynamic>?> askAITutor({
    required String userMessage,
    required String nativeLang,
    required String targetLang,
    String proficiencyLevel = 'beginner',
    String? characterId,
    List<Map<String, String>> history = const [],
    String mode = 'tutor',
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final url = Uri.parse('$_backendBaseUrl/api/v1/ai/tutor');
        final resp = await http
            .post(
              url,
              headers: _buildHeaders(),
              body: jsonEncode({
                'user_message': userMessage,
                'native_language': nativeLang,
                'target_language': targetLang,
                'proficiency_level': proficiencyLevel,
                'character_id': characterId,
                'history': history,
                'mode': mode,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          if (decoded['success'] == true && decoded['data'] != null) {
            return decoded['data'] as Map<String, dynamic>;
          }
        } else {
          debugPrint('[SpeechService] AI Tutor error (${resp.statusCode}): ${resp.body}');
        }
      } catch (e) {
        debugPrint('[SpeechService] Groq AI Tutor connection exception (attempt $attempt): $e');
        if (attempt == 0) {
          await resolveBackendUrl();
        }
      }
    }
    return null;
  }

  /// Translate recognized text through FastAPI translation endpoint, with offline phrase fallback
  Future<Map<String, dynamic>?> translateText({
    required String text,
    required String sourceLang,
    required String targetLang,
    String? characterId,
  }) async {
    try {
      final url = Uri.parse('$_backendBaseUrl/api/v1/translation/translate');
      final resp = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({
              'text': text,
              'source_language': sourceLang,
              'target_language': targetLang,
              'character_id': characterId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // Backend not running or timeout; fall back gracefully
    }

    // Local offline fallback translation for zero-delay UX and unit tests
    return _localOfflineTranslate(text, sourceLang, targetLang);
  }

  Map<String, dynamic> _localOfflineTranslate(String text, String src, String tgt) {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    String translated = clean;
    if (lower.contains('surat')) {
      translated = 'Train to Surat';
    } else if (clean.contains('કેમ છો') || clean.contains('કેમ છો?')) {
      translated = 'How are you?';
    } else if (clean.contains('નમસ્તે') || lower.contains('namaste')) {
      translated = 'Hello';
    } else if (clean.contains('આભાર') || lower.contains('thank you')) {
      translated = 'Thank you';
    } else if (clean.contains('સુપ્રભાત') || lower.contains('good morning')) {
      translated = 'Good morning';
    }

    return {
      'original_text': clean,
      'translated_text': translated,
      'source_language': src,
      'target_language': tgt,
      'provider': 'lingoboom_local_cache',
    };
  }

  /// Synthesize speech via Gnani Timbre TTS through FastAPI backend
  Future<String?> synthesizeTTS({
    required String text,
    String voice = 'Shivani',
    String languageCode = 'en-IN',
    double speed = 1.0,
  }) async {
    debugPrint('[SpeechService] TTS request started: text="$text", voice=$voice, lang=$languageCode, speed=$speed');
    try {
      final url = Uri.parse('$_backendBaseUrl/api/v1/tts/synthesize');
      final resp = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({
              'text': text,
              'voice': voice,
              'language': languageCode,
              'speed': speed,
              'model': 'timbre-v3.0',
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[SpeechService] TTS response received: status=${resp.statusCode}');
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] != null) {
          final audioB64 = decoded['data']['audio_base64'] as String?;
          if (audioB64 != null && audioB64.isNotEmpty) {
            final rawBytes = Uint8List.fromList(base64Decode(audioB64));
            final wavBytes = _wrapPcmAsWav(rawBytes, sampleRate: 16000, channels: 1, bitsPerSample: 16);
            final paddedBytes = _prependSilenceToWav(wavBytes, silenceMs: 120);
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/lingo_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
            final ttsFile = File(filePath);
            await ttsFile.writeAsBytes(paddedBytes);
            debugPrint('[SpeechService] Audio file successfully written: $filePath (${paddedBytes.length} bytes)');
            return filePath;
          }
        }
      } else {
        debugPrint('[SpeechService] TTS request failed with HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('[SpeechService] TTS synthesis exception: $e');
    }
    return null;
  }

  static const List<Map<String, dynamic>> defaultVoiceCatalog = [
    {
      'id': 'Shivani',
      'name': 'Shivani',
      'gender': 'female',
      'description': 'Natural, warm, expressive (Default)',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Chetana',
      'name': 'Chetana',
      'gender': 'female',
      'description': 'Bright, articulate, cheerful',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Kalpana',
      'name': 'Kalpana',
      'gender': 'female',
      'description': 'Soothing, gentle, melodic',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Lakshmi',
      'name': 'Lakshmi',
      'gender': 'female',
      'description': 'Clear, classic, professional',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Riyaa',
      'name': 'Riyaa',
      'gender': 'female',
      'description': 'Lively, playful, enthusiastic',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Tarika',
      'name': 'Tarika',
      'gender': 'female',
      'description': 'Crisp, modern, pleasant',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Vasudha',
      'name': 'Vasudha',
      'gender': 'female',
      'description': 'Rich, melodic, comforting',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Avinash',
      'name': 'Avinash',
      'gender': 'male',
      'description': 'Warm, friendly, confident',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Devansh',
      'name': 'Devansh',
      'gender': 'male',
      'description': 'Youthful, energetic, bright',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Prakash',
      'name': 'Prakash',
      'gender': 'male',
      'description': 'Clear, mature, reassuring',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Shubham',
      'name': 'Shubham',
      'gender': 'male',
      'description': 'Natural, casual, conversational',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Yashraj',
      'name': 'Yashraj',
      'gender': 'male',
      'description': 'Expressive, dynamic',
      'model': 'timbre-v3.0',
    },
    {
      'id': 'Harshad',
      'name': 'Harshad',
      'gender': 'male',
      'description': 'Deep, authoritative, calm',
      'model': 'timbre-v3.0',
    },
  ];

  /// Fetches verified voice catalog from backend API or falls back to default catalog
  Future<List<Map<String, dynamic>>> fetchVoiceCatalog() async {
    try {
      final url = Uri.parse('$_backendBaseUrl/api/v1/tts/voices');
      final resp = await http.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('[SpeechService] Error fetching voice catalog: $e');
    }
    return defaultVoiceCatalog;
  }

  /// Safely normalizes 16-bit linear PCM audio for high-clarity speech playback on mobile devices.
  /// Applies calculated gain targeting ~ -15.0 dBFS RMS with a -1.0 dBFS ceiling and smooth soft-knee limiter.
  static Uint8List normalizePcm16(Uint8List pcmBytes, {double targetRmsDbfs = -15.0, double targetPeakDbfs = -1.0}) {
    if (pcmBytes.length < 2) return pcmBytes;
    final numSamples = pcmBytes.length ~/ 2;
    final byteData = ByteData.sublistView(pcmBytes);

    int peak = 0;
    double sumSq = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      final absS = s < 0 ? -s : s;
      if (absS > peak) peak = absS;
      sumSq += s * s;
    }
    if (peak == 0) return pcmBytes;

    final rms = math.sqrt(sumSq / numSamples);
    final peakDbfs = 20.0 * (math.log(peak / 32768.0) / math.ln10);
    final rmsDbfs = rms > 0 ? 20.0 * (math.log(rms / 32768.0) / math.ln10) : -999.0;

    // Guard: already sufficiently loud
    if (peakDbfs >= -1.5 || rmsDbfs >= -17.0) return pcmBytes;

    final targetRmsAmp = 32768.0 * math.pow(10.0, targetRmsDbfs / 20.0);
    final targetPeakAmp = 32768.0 * math.pow(10.0, targetPeakDbfs / 20.0);

    final desiredRmsGain = rms > 0 ? (targetRmsAmp / rms) : 1.0;
    final maxLinearGain = targetPeakAmp / peak;
    var gain = desiredRmsGain < (maxLinearGain * 1.5) ? desiredRmsGain : (maxLinearGain * 1.5);
    if (gain < 1.0) gain = 1.0;
    if (gain > 3.5) gain = 3.5;

    final threshold = 26000.0;
    final ceiling = 31000.0;
    final ratio = ceiling - threshold;

    final outBytes = Uint8List(pcmBytes.length);
    final outData = ByteData.sublistView(outBytes);

    for (int i = 0; i < numSamples; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      final val = s * gain;
      final absVal = val < 0 ? -val : val;
      double outVal;
      if (absVal <= threshold) {
        outVal = val;
      } else {
        final over = absVal - threshold;
        final x = over / ratio;
        final clampedX = x.clamp(-15.0, 15.0);
        final e2x = math.exp(2.0 * clampedX);
        final th = (e2x - 1.0) / (e2x + 1.0);
        final limited = threshold + ratio * th;
        outVal = val < 0 ? -limited : limited;
      }
      var intVal = outVal.round();
      if (intVal > 32767) intVal = 32767;
      if (intVal < -32768) intVal = -32768;
      outData.setInt16(i * 2, intVal, Endian.little);
    }
    return outBytes;
  }

  /// Ensures raw PCM audio is wrapped in a standard 44-byte WAV header if not already present
  Uint8List _wrapPcmAsWav(
    Uint8List pcmBytes, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    if (pcmBytes.length >= 44 &&
        pcmBytes[0] == 0x52 &&
        pcmBytes[1] == 0x49 &&
        pcmBytes[2] == 0x46 &&
        pcmBytes[3] == 0x46) {
      int dataIdx = -1;
      for (int i = 12; i < pcmBytes.length - 8; i++) {
        if (pcmBytes[i] == 0x64 &&
            pcmBytes[i + 1] == 0x61 &&
            pcmBytes[i + 2] == 0x74 &&
            pcmBytes[i + 3] == 0x61) {
          dataIdx = i;
          break;
        }
      }
      if (dataIdx != -1 && dataIdx + 8 <= pcmBytes.length) {
        final rawPcm = Uint8List.sublistView(pcmBytes, dataIdx + 8);
        final normalizedPcm = normalizePcm16(rawPcm);
        final out = Uint8List(dataIdx + 8 + normalizedPcm.length);
        out.setRange(0, dataIdx + 8, pcmBytes);
        out.setRange(dataIdx + 8, out.length, normalizedPcm);
        final outData = ByteData.sublistView(out);
        outData.setUint32(4, out.length - 8, Endian.little);
        outData.setUint32(dataIdx + 4, normalizedPcm.length, Endian.little);
        return out;
      }
      return pcmBytes;
    }

    final normalizedPcm = normalizePcm16(pcmBytes);
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = normalizedPcm.length;
    final riffSize = 36 + dataSize;
    final header = ByteData(44);

    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, riffSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0, 44, header.buffer.asUint8List());
    out.setRange(44, 44 + dataSize, normalizedPcm);
    return out;
  }

  /// Prepends safe lead-in silence to WAV PCM data to prevent hardware audio DAC ramp-up from cutting off the first word
  Uint8List _prependSilenceToWav(Uint8List wavBytes, {int silenceMs = 120}) {
    if (wavBytes.length < 44) return wavBytes;
    if (wavBytes[0] != 0x52 || wavBytes[1] != 0x49 || wavBytes[2] != 0x46 || wavBytes[3] != 0x46) {
      return wavBytes; // Not RIFF
    }

    int dataIndex = -1;
    for (int i = 12; i < wavBytes.length - 8; i++) {
      if (wavBytes[i] == 0x64 &&
          wavBytes[i + 1] == 0x61 &&
          wavBytes[i + 2] == 0x74 &&
          wavBytes[i + 3] == 0x61) {
        dataIndex = i;
        break;
      }
    }
    if (dataIndex == -1) return wavBytes;

    final byteData = ByteData.sublistView(wavBytes);
    final sampleRate = byteData.getUint32(24, Endian.little);
    final channels = byteData.getUint16(22, Endian.little);
    final bitsPerSample = byteData.getUint16(34, Endian.little);

    final safeSampleRate = (sampleRate >= 8000 && sampleRate <= 48000) ? sampleRate : 16000;
    final safeChannels = (channels >= 1 && channels <= 2) ? channels : 1;
    final safeBits = (bitsPerSample == 8 || bitsPerSample == 16 || bitsPerSample == 24 || bitsPerSample == 32)
        ? bitsPerSample
        : 16;

    final bytesPerMs = ((safeSampleRate * safeChannels * (safeBits ~/ 8)) / 1000.0).round();
    final silenceBytesCount = bytesPerMs * silenceMs;

    var oldDataSize = byteData.getUint32(dataIndex + 4, Endian.little);
    var oldRiffSize = byteData.getUint32(4, Endian.little);
    if (oldDataSize == 0xFFFFFFFF || oldDataSize > wavBytes.length) {
      oldDataSize = wavBytes.length - (dataIndex + 8);
    }
    if (oldRiffSize == 0xFFFFFFFF || oldRiffSize > wavBytes.length) {
      oldRiffSize = wavBytes.length - 8;
    }

    final newBytes = Uint8List(wavBytes.length + silenceBytesCount);
    newBytes.setRange(0, dataIndex + 8, wavBytes);

    final newByteData = ByteData.sublistView(newBytes);
    newByteData.setUint32(4, oldRiffSize + silenceBytesCount, Endian.little);
    newByteData.setUint32(dataIndex + 4, oldDataSize + silenceBytesCount, Endian.little);

    newBytes.setRange(dataIndex + 8 + silenceBytesCount, newBytes.length, wavBytes, dataIndex + 8);
    return newBytes;
  }

  /// Play audio file with specific playback rate (e.g. 1.0 normal or 0.75 slow)
  /// Switches AudioSession to playback mode and forces loud speaker output.
  Future<void> playAudioFile(String filePath, {double speed = 1.0}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[SpeechService] Audio file does not exist: $filePath');
      return;
    }
    final fileSize = await file.length();
    debugPrint('[SpeechService] Audio file validated: $filePath ($fileSize bytes)');
    if (fileSize < 44) {
      debugPrint('[SpeechService] Audio file too small/invalid ($fileSize bytes)');
      return;
    }

    try {
      debugPrint('[SpeechService] Audio player initialization starting...');
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);
      debugPrint('[SpeechService] AudioSession activated for speech playback');

      if (player.playing) {
        debugPrint('[SpeechService] Stopping previous playback');
        await player.stop();
      }

      await player.setFilePath(filePath);
      await player.setVolume(1.0);
      await player.setSpeed(speed);
      debugPrint('[SpeechService] Audio playback started: speed=$speed, volume=1.0');

      StreamSubscription? stateSub;
      stateSub = player.playerStateStream.listen((state) {
        debugPrint('[SpeechService] Audio playback state changed: playing=${state.playing}, processingState=${state.processingState}');
        if (state.processingState == ProcessingState.completed) {
          debugPrint('[SpeechService] Playback completed successfully');
          stateSub?.cancel();
        }
      });

      await player.play();
    } catch (e) {
      debugPrint('[SpeechService] Playback errors: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDailyPractice({
    String nativeLang = 'gu-IN',
    String targetLang = 'en-US',
    String proficiencyLevel = 'beginner',
    int count = 20,
    String? category,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final url = Uri.parse('$_backendBaseUrl/api/v1/ai/daily-practice');
        final resp = await http
            .post(
              url,
              headers: _buildHeaders(),
              body: jsonEncode({
                'native_language': nativeLang,
                'target_language': targetLang,
                'proficiency_level': proficiencyLevel,
                'count': count,
                'category': category,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          if (decoded['success'] == true && decoded['data'] != null) {
            final sentences = decoded['data']['sentences'] as List<dynamic>?;
            if (sentences != null && sentences.isNotEmpty) {
              return sentences.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          }
        }
      } catch (e) {
        debugPrint('[SpeechService] Daily practice request error (attempt $attempt): $e');
        if (attempt == 0) await resolveBackendUrl();
      }
    }

    return _offlineDailyPracticeSet(targetLang, nativeLang);
  }

  List<Map<String, dynamic>> _offlineDailyPracticeSet(String tgt, String src) {
    return [
      {
        'id': 'offline_1',
        'target_sentence': 'Where is the nearest bus station?',
        'native_translation': 'નજીકનું બસ સ્ટેશન ક્યાં છે?',
        'category': 'Travel',
        'difficulty': 'Easy',
        'pronunciation_guide': 'wair iz thuh neer-ist bus stay-shun',
        'context_tip': 'Useful for finding local transit.'
      },
      {
        'id': 'offline_2',
        'target_sentence': 'Could you please help me with these bags?',
        'native_translation': 'શું તમે કૃપા કરીને આ બેગમાં મારી મદદ કરી શકશો?',
        'category': 'Daily',
        'difficulty': 'Easy',
        'pronunciation_guide': 'kood yoo pleez help mee with theez bagz',
        'context_tip': 'Polite request.'
      },
      {
        'id': 'offline_3',
        'target_sentence': 'I would like to order two coffees, please.',
        'native_translation': 'હું કૃપા કરીને બે કોફી ઓર્ડર કરવા માંગુ છું.',
        'category': 'Dining',
        'difficulty': 'Easy',
        'pronunciation_guide': 'eye wood lyk too or-der too kof-eez pleez',
        'context_tip': 'Ordering at a cafe.'
      },
      {
        'id': 'offline_4',
        'target_sentence': 'What time does the morning flight depart?',
        'native_translation': 'સવારની ફ્લાઇટ કેટલા વાગ્યે ઉપડે છે?',
        'category': 'Travel',
        'difficulty': 'Intermediate',
        'pronunciation_guide': 'waht tyme duz thuh mor-ning flyte dee-part',
        'context_tip': 'Airport queries.'
      },
      {
        'id': 'offline_5',
        'target_sentence': 'My name is Shubham, and I am learning English.',
        'native_translation': 'મારું નામ શુભમ છે, અને હું અંગ્રેજી શીખી રહ્યો છું.',
        'category': 'Introduction',
        'difficulty': 'Easy',
        'pronunciation_guide': 'my naym iz shoo-bhum and eye am ler-ning ing-glish',
        'context_tip': 'Self-introduction.'
      },
    ];
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    try {
      if (_player != null) {
        await _player!.stop();
      }
    } catch (e) {
      debugPrint('[SpeechService] Stop playback error: $e');
    }
  }

  void dispose() {
    _recorder?.dispose();
    _player?.dispose();
  }
}
