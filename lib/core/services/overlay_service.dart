import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';

class OverlayService {
  OverlayService._();
  static final OverlayService instance = OverlayService._();

  static const MethodChannel _channel = MethodChannel('com.lingoboop.app/overlay');
  static const EventChannel _eventChannel = EventChannel('com.lingoboop.app/overlay_events');
  Stream<dynamic>? _overlayEvents;

  Stream<dynamic> get overlayEvents =>
      _overlayEvents ??= _eventChannel.receiveBroadcastStream();

  /// Check whether Android "Display Over Other Apps" permission is granted
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Launch Android Settings page to allow user to grant overlay permission
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }

  /// Start persistent native floating pet Foreground Service
  Future<bool> startOverlay({
    required String petKey,
    required String petName,
    required String petColorHex,
    required String sourceLang,
    required String targetLang,
    String? voice,
    String? authToken,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final token = authToken ?? AuthService.instance.currentAccessToken;
      final res = await _channel.invokeMethod<bool>('startOverlay', {
        'petKey': petKey,
        'petName': petName,
        'petColor': petColorHex,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'voice': voice ?? 'Shivani',
        'authToken': ?token,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error starting native overlay: $e');
      return false;
    }
  }

  /// Stop persistent native floating pet Foreground Service
  Future<bool> stopOverlay() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('stopOverlay');
      return res ?? false;
    } catch (e) {
      debugPrint('Error stopping native overlay: $e');
      return false;
    }
  }

  /// Check whether native floating pet service is currently running
  Future<bool> isOverlayRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isOverlayRunning');
      return res ?? false;
    } catch (e) {
      debugPrint('Error checking overlay running status: $e');
      return false;
    }
  }

  /// Update active pet in running native overlay
  Future<void> updatePet({
    required String petKey,
    required String petName,
    required String petColorHex,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updatePet', {
        'petKey': petKey,
        'petName': petName,
        'petColor': petColorHex,
      });
    } catch (e) {
      debugPrint('Error updating pet in overlay: $e');
    }
  }

  /// Update languages in running native overlay
  Future<void> updateLanguages({
    required String sourceLang,
    required String targetLang,
    String? sourceLangName,
    String? targetLangName,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateLanguages', {
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'sourceLangName': sourceLangName,
        'targetLangName': targetLangName,
      });
    } catch (e) {
      debugPrint('Error updating languages in overlay: $e');
    }
  }

  /// Update authentication token in running native overlay
  Future<void> updateAuthToken(String token) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateAuthToken', {
        'authToken': token,
      });
    } catch (e) {
      debugPrint('Error updating auth token in overlay: $e');
    }
  }

  /// Update TTS voice character in running native overlay
  Future<void> updateVoice(String voice) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateVoice', {
        'voice': voice,
      });
    } catch (e) {
      debugPrint('Error updating voice in overlay: $e');
    }
  }

  /// Update backend base URL in running native overlay
  Future<void> updateBackendUrl(String backendUrl) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateBackendUrl', {
        'backendUrl': backendUrl,
      });
    } catch (e) {
      debugPrint('Error updating backend URL in overlay: $e');
    }
  }

  /// Fetch latest authoritative card state from native SharedPreferences (e.g. after returning from background)
  Future<Map<String, dynamic>?> getLatestCardState() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getLatestCardState');
      return res;
    } catch (e) {
      debugPrint('Error getting latest card state from native overlay: $e');
      return null;
    }
  }

  /// Synchronize authoritative PolyCard state with running native overlay
  Future<void> updateCardState({
    required String petId,
    required String petName,
    required String petColorHex,
    required String voiceId,
    required String sourceLanguage,
    required String targetLanguage,
    String? sourceLanguageName,
    String? targetLanguageName,
    required String originalText,
    required String translatedText,
    String? correction,
    String? statusNote,
    List<String>? words,
    double? pronunciationScore,
    String? requestId,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateCardState', {
        'petId': petId,
        'petName': petName,
        'petColor': petColorHex,
        'voiceId': voiceId,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'sourceLanguageName': sourceLanguageName,
        'targetLanguageName': targetLanguageName,
        'originalText': originalText,
        'translatedText': translatedText,
        'correction': correction,
        'statusNote': statusNote,
        'words': words?.join(' '),
        'pronunciationScore': pronunciationScore,
        'requestId': requestId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error updating card state in overlay: $e');
    }
  }
}


