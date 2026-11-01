import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/companion/presentation/companion_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud backend if configured
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization notice: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: LingoBoomApp(),
    ),
  );
}

class LingoBoomApp extends ConsumerWidget {
  const LingoBoomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companionState = ref.watch(companionProvider);
    final isAuthenticated = AuthService.instance.isAuthenticated;

    return MaterialApp(
      title: 'LingoBoom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(
        accentColor: companionState.activePet.accentColor,
      ),
      initialRoute: isAuthenticated ? '/home' : '/',
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
