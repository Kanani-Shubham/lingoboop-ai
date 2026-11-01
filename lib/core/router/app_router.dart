import 'package:flutter/material.dart';
import '../../features/achievements/presentation/achievements_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/character/presentation/pet_select_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/navigation/presentation/main_navigation_shell.dart';
import '../../features/onboarding/presentation/goal_setup_screen.dart';
import '../../features/onboarding/presentation/language_select_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case '/onboarding/languages':
        return MaterialPageRoute(builder: (_) => const LanguageSelectScreen());
      case '/onboarding/goals':
        return MaterialPageRoute(builder: (_) => const GoalSetupScreen());
      case '/onboarding/pets':
        return MaterialPageRoute(builder: (_) => const PetSelectScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const MainNavigationShell());
      case '/pets':
        return MaterialPageRoute(builder: (_) => const PetSelectScreen());
      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/progress':
        return MaterialPageRoute(builder: (_) => const ProgressScreen());
      case '/achievements':
        return MaterialPageRoute(builder: (_) => const AchievementsScreen());
      case '/subscription':
        return MaterialPageRoute(builder: (_) => const SubscriptionScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/history':
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
