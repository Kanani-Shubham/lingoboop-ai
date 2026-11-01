import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/companion/presentation/companion_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

    return MaterialApp(
      title: 'LingoBoom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(
        accentColor: companionState.activePet.accentColor,
      ),
      initialRoute: '/',
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
