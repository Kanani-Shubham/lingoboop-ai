import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient? get _client {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _client?.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check backend connection.');
    }
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign up with email, password, and optional full name
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Please check backend connection.');
    }
    return await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: fullName != null && fullName.isNotEmpty
          ? {'full_name': fullName.trim()}
          : null,
    );
  }

  /// Request password reset
  Future<void> sendPasswordResetEmail(String email) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured.');
    }
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Sign out current session
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (e) {
        debugPrint('Error signing out: $e');
      }
    }
  }
}
