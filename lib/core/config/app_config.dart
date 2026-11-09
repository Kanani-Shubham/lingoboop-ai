// Client configuration: public anon key and project URL only.
// Private service-role keys and Gnani keys are strictly server-side.

class AppConfig {
  AppConfig._();

  static const String appName = 'TalkTails';
  static const String backendProductionUrl = 'https://lingoboop-ai.onrender.com';
  static const String backendEmulatorUrl = 'http://10.0.2.2:8000';
  static const String backendDeviceUrl = 'http://127.0.0.1:8000';

  /// Default backend base URL: uses BACKEND_URL dart-define if provided,
  /// otherwise defaults to the production Render URL.
  static const String defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: backendProductionUrl,
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kmkvyhtwxhsweznzubrr.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtta3Z5aHR3eGhzd2V6bnp1YnJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM0OTM0OTMsImV4cCI6MjEwOTA2OTQ5M30.dX2mRVNX5FL9Q2i2xs0AnzlXKqRMuR04RpD5_GOgM8g',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project-id');
}
