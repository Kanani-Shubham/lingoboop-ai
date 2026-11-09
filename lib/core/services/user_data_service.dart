import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  final _storage = const FlutterSecureStorage();
  String _cachedVoice = 'Shivani';
  String? _cachedCharacter;
  String? _cachedSourceLang;
  String? _cachedTargetLang;

  // Active conversation session state for reusing sessions within 30 min
  String? _activeConversationId;
  String? _activeConversationCharId;
  String? _activeConversationSrcLang;
  String? _activeConversationTgtLang;
  DateTime? _lastConversationTime;

  Future<String> getSelectedVoice() async {
    try {
      final v = await _storage.read(key: 'selected_tts_voice');
      if (v != null && v.isNotEmpty) {
        _cachedVoice = v;
        return v;
      }
    } catch (_) {}
    return _cachedVoice;
  }

  Future<void> saveSelectedVoice(String voice) async {
    _cachedVoice = voice;
    try {
      await _storage.write(key: 'selected_tts_voice', value: voice);
    } catch (_) {}
    savePreferences(selectedVoiceId: voice);
  }

  Future<String?> getCachedCharacter() async {
    if (_cachedCharacter != null) return _cachedCharacter;
    try {
      final c = await _storage.read(key: 'active_character_id');
      if (c != null && c.isNotEmpty) {
        _cachedCharacter = c;
        return c;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveCachedCharacter(String charId) async {
    _cachedCharacter = charId;
    try {
      await _storage.write(key: 'active_character_id', value: charId);
    } catch (_) {}
  }

  Future<Map<String, String>?> getCachedLanguages() async {
    if (_cachedSourceLang != null && _cachedTargetLang != null) {
      return {'source': _cachedSourceLang!, 'target': _cachedTargetLang!};
    }
    try {
      final src = await _storage.read(key: 'source_language_code');
      final tgt = await _storage.read(key: 'target_language_code');
      if (src != null && tgt != null) {
        _cachedSourceLang = src;
        _cachedTargetLang = tgt;
        return {'source': src, 'target': tgt};
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveCachedLanguages({required String sourceCode, required String targetCode}) async {
    _cachedSourceLang = sourceCode;
    _cachedTargetLang = targetCode;
    try {
      await _storage.write(key: 'source_language_code', value: sourceCode);
      await _storage.write(key: 'target_language_code', value: targetCode);
    } catch (_) {}
  }

  SupabaseClient? get _client {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Fetch user profile from public.profiles
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return null;

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({String? fullName, String? avatarUrl}) async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return false;

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await client.from('profiles').update(updates).eq('id', uid);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// Fetch user preferences
  Future<Map<String, dynamic>?> getPreferences() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return null;

    try {
      final data = await client
          .from('user_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('Error fetching preferences: $e');
      return null;
    }
  }

  /// Upsert user preferences
  Future<bool> savePreferences({
    String? activeCharacterId,
    String? selectedVoiceId,
    String? selectedVoiceProvider,
    String? selectedVoiceLanguage,
    double? audioSpeed,
    int? dailyGoalMinutes,
    bool? overlayEnabled,
    double? overlayPositionX,
    double? overlayPositionY,
  }) async {
    if (activeCharacterId != null) {
      saveCachedCharacter(activeCharacterId);
    }
    if (selectedVoiceId != null) {
      _cachedVoice = selectedVoiceId;
      try {
        await _storage.write(key: 'selected_tts_voice', value: selectedVoiceId);
      } catch (_) {}
    }

    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return false;

    try {
      final payload = <String, dynamic>{
        'user_id': uid,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (activeCharacterId != null) payload['active_character_id'] = activeCharacterId;
      if (selectedVoiceId != null) payload['selected_voice_id'] = selectedVoiceId;
      if (selectedVoiceProvider != null) payload['selected_voice_provider'] = selectedVoiceProvider;
      if (selectedVoiceLanguage != null) payload['selected_voice_language'] = selectedVoiceLanguage;
      if (audioSpeed != null) payload['audio_speed'] = audioSpeed;
      if (dailyGoalMinutes != null) payload['daily_goal_minutes'] = dailyGoalMinutes;
      if (overlayEnabled != null) payload['overlay_enabled'] = overlayEnabled;
      if (overlayPositionX != null) payload['overlay_position_x'] = overlayPositionX;
      if (overlayPositionY != null) payload['overlay_position_y'] = overlayPositionY;

      await client.from('user_preferences').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      return false;
    }
  }

  /// Fetch user language pairs
  Future<List<Map<String, dynamic>>> getUserLanguages() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return [];

    try {
      final response = await client
          .from('user_languages')
          .select()
          .eq('user_id', uid)
          .order('is_active', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user languages: $e');
      return [];
    }
  }

  /// Save language pair
  Future<bool> saveUserLanguage({
    required String nativeCode,
    required String targetCode,
    String proficiencyLevel = 'beginner',
  }) async {
    saveCachedLanguages(sourceCode: nativeCode, targetCode: targetCode);

    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return false;

    try {
      await client.from('user_languages').upsert({
        'user_id': uid,
        'native_language_code': nativeCode,
        'target_language_code': targetCode,
        'proficiency_level': proficiencyLevel,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, native_language_code, target_language_code');
      return true;
    } catch (e) {
      debugPrint('Error saving user language: $e');
      return false;
    }
  }

  /// Fetch conversation history
  Future<List<Map<String, dynamic>>> getConversations({int limit = 50, int offset = 0}) async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return [];

    try {
      final response = await client
          .from('conversations')
          .select('*, messages(*)')
          .eq('user_id', uid)
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  /// Save a new conversation session with speech message
  Future<String?> recordConversationMessage({
    required String characterId,
    required String sourceLanguage,
    required String targetLanguage,
    required String sourceText,
    required String translatedText,
    double? pronunciationScore,
  }) async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return null;

    try {
      final now = DateTime.now();
      String convId;

      final canReuse = _activeConversationId != null &&
          _activeConversationCharId == characterId &&
          _activeConversationSrcLang == sourceLanguage &&
          _activeConversationTgtLang == targetLanguage &&
          _lastConversationTime != null &&
          now.difference(_lastConversationTime!).inMinutes < 30;

      if (canReuse) {
        convId = _activeConversationId!;
        await client.from('conversations').update({
          'updated_at': now.toIso8601String(),
        }).eq('id', convId);
      } else {
        final conv = await client
            .from('conversations')
            .insert({
              'user_id': uid,
              'character_id': characterId,
              'title': sourceText.length > 28 ? '${sourceText.substring(0, 28)}...' : sourceText,
              'source_language': sourceLanguage,
              'target_language': targetLanguage,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .select('id')
            .single();

        convId = conv['id'] as String;
        _activeConversationId = convId;
        _activeConversationCharId = characterId;
        _activeConversationSrcLang = sourceLanguage;
        _activeConversationTgtLang = targetLanguage;
      }
      _lastConversationTime = now;

      // 2. Insert message record
      await client.from('messages').insert({
        'conversation_id': convId,
        'user_id': uid,
        'sender_role': 'user',
        'source_text': sourceText,
        'translated_text': translatedText,
        'pronunciation_score': pronunciationScore,
        'created_at': now.toIso8601String(),
      });

      // 3. Insert companion response message
      if (translatedText.isNotEmpty) {
        await client.from('messages').insert({
          'conversation_id': convId,
          'user_id': uid,
          'sender_role': 'assistant',
          'source_text': sourceText,
          'translated_text': translatedText,
          'created_at': now.add(const Duration(milliseconds: 50)).toIso8601String(),
        });
      }

      return convId;
    } catch (e) {
      debugPrint('Error recording conversation: $e');
      return null;
    }
  }

  /// Record structured daily practice attempt into daily_practice_attempts table
  Future<void> recordPracticeAttempt({
    required String targetText,
    required String nativeTranslation,
    required String userSpoken,
    required double score,
    required bool isPassed,
    required int sequenceNumber,
    required String nativeLang,
    required String targetLang,
  }) async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return;

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Get or create daily practice session for today
      final sessionRes = await client
          .from('daily_practice_sessions')
          .select('id')
          .eq('user_id', uid)
          .eq('session_date', dateStr)
          .eq('native_language_code', nativeLang)
          .eq('target_language_code', targetLang)
          .maybeSingle();

      String sessionId;
      if (sessionRes != null && sessionRes['id'] != null) {
        sessionId = sessionRes['id'] as String;
      } else {
        final newSession = await client
            .from('daily_practice_sessions')
            .insert({
              'user_id': uid,
              'session_date': dateStr,
              'native_language_code': nativeLang,
              'target_language_code': targetLang,
              'status': 'in_progress',
              'total_sentences': 14,
              'completed_sentences': 0,
            })
            .select('id')
            .single();
        sessionId = newSession['id'] as String;
      }

      // 2. Get or create practice item
      final itemRes = await client
          .from('daily_practice_items')
          .select('id, attempt_count')
          .eq('session_id', sessionId)
          .eq('sequence_number', sequenceNumber)
          .maybeSingle();

      String itemId;
      int nextAttemptNumber = 1;
      if (itemRes != null && itemRes['id'] != null) {
        itemId = itemRes['id'] as String;
        final currentAttempts = (itemRes['attempt_count'] as num?)?.toInt() ?? 0;
        nextAttemptNumber = currentAttempts + 1;
        await client.from('daily_practice_items').update({
          'attempt_count': nextAttemptNumber,
          'status': isPassed ? 'passed' : 'attempted',
          'best_pronunciation_score': score,
          if (isPassed) 'passed_at': now.toIso8601String(),
        }).eq('id', itemId);
      } else {
        final newItem = await client
            .from('daily_practice_items')
            .insert({
              'session_id': sessionId,
              'user_id': uid,
              'sequence_number': sequenceNumber,
              'target_text': targetText,
              'native_translation': nativeTranslation,
              'status': isPassed ? 'passed' : 'attempted',
              'best_pronunciation_score': score,
              'attempt_count': 1,
              'first_attempted_at': now.toIso8601String(),
              if (isPassed) 'passed_at': now.toIso8601String(),
            })
            .select('id')
            .single();
        itemId = newItem['id'] as String;
      }

      // 3. Record individual attempt
      await client.from('daily_practice_attempts').insert({
        'item_id': itemId,
        'session_id': sessionId,
        'user_id': uid,
        'attempt_number': nextAttemptNumber,
        'recognized_transcript': userSpoken,
        'expected_target': targetText,
        'pronunciation_score': score,
        'is_passed': isPassed,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[UserDataService] Practice attempt record note: $e');
    }
  }

  /// Mark daily practice session completed
  Future<void> updateDailyPracticeSessionCompletion({
    required int totalSentences,
    required int completedCount,
    required double averageScore,
    required String nativeLang,
    required String targetLang,
  }) async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return;

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await client.from('daily_practice_sessions').update({
        'completed_sentences': completedCount,
        'status': completedCount >= totalSentences ? 'completed' : 'in_progress',
        'average_pronunciation_score': averageScore,
        'completed_at': completedCount >= totalSentences ? now.toIso8601String() : null,
      }).eq('user_id', uid).eq('session_date', dateStr).eq('native_language_code', nativeLang).eq('target_language_code', targetLang);
    } catch (e) {
      debugPrint('[UserDataService] Session completion update note: $e');
    }
  }

  /// Fetch learning progress (spaced repetition)
  Future<List<Map<String, dynamic>>> getLearningProgress() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return [];

    try {
      final response = await client
          .from('learning_progress')
          .select()
          .eq('user_id', uid)
          .order('next_review_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching learning progress: $e');
      return [];
    }
  }

  /// Fetch user achievements
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return [];

    try {
      final response = await client
          .from('achievements')
          .select()
          .eq('user_id', uid)
          .order('earned_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      return [];
    }
  }

  /// Fetch user subscription entitlement
  Future<Map<String, dynamic>?> getSubscription() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return null;

    try {
      final response = await client
          .from('subscriptions')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      return null;
    }
  }

  /// Fetch usage records summary (seconds consumed)
  Future<double> getTotalSpeechSeconds() async {
    final uid = currentUserId;
    final client = _client;
    if (client == null || uid == null) return 0.0;

    try {
      final response = await client
          .from('usage_records')
          .select('duration_seconds')
          .eq('user_id', uid);
      double total = 0.0;
      for (final r in response) {
        total += (r['duration_seconds'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      debugPrint('Error fetching speech usage: $e');
      return 0.0;
    }
  }
}

