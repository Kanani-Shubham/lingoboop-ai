import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/router/app_router.dart';
import 'package:lingoboop/features/auth/presentation/forgot_password_screen.dart';
import 'package:lingoboop/features/auth/presentation/login_screen.dart';
import 'package:lingoboop/features/auth/presentation/signup_screen.dart';

void main() {
  group('Authentication Flow and Validation Tests', () {
    testWidgets('Welcome screen "Get Started" navigates to SignupScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Get Started button
      final getStartedBtn = find.text('Get Started');
      expect(getStartedBtn, findsOneWidget);
      await tester.tap(getStartedBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify we are on SignupScreen
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsOneWidget);
    });

    testWidgets('Welcome screen "I already have an account" navigates to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tap I already have an account button
      final loginBtn = find.text('I already have an account');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify we are on LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('SignupScreen validates empty fields and mismatched passwords',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Create Account button without entering any input
      final createAccountBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      expect(createAccountBtn, findsOneWidget);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      // Verify validation error messages on empty submission
      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);

      // Enter short password
      await tester.enterText(find.byType(TextFormField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextFormField).at(1), 'jane@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.enterText(find.byType(TextFormField).at(3), '123');
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // Enter mismatched passwords
      await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
      await tester.enterText(find.byType(TextFormField).at(3), 'different456');

      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('LoginScreen validates email and password requirements',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In with empty fields
      final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(signInBtn, findsOneWidget);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);

      // Enter invalid email format
      await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email-address');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');

      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('ForgotPasswordScreen validates email format',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final resetBtn = find.widgetWithText(ElevatedButton, 'Send Reset Link');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
    });

    testWidgets('AppRouter protects /home route and redirects unauthenticated user to LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/home',
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      // Protected route guard routes to LoginScreen
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });
  });
}
