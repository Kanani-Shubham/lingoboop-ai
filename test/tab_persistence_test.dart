import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/widgets/floating_pet_avatar.dart';
import 'package:lingoboop/features/navigation/presentation/main_navigation_shell.dart';

void main() {
  testWidgets('MainNavigationShell keeps 3D Pet Avatar mounted across all four tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainNavigationShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tab 0: Home / Speak
    expect(find.byType(FloatingPetAvatar), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    // Switch to Tab 1: Progress
    await tester.tap(find.byIcon(Icons.trending_up));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Pet is still mounted on Progress tab!
    expect(find.byType(FloatingPetAvatar), findsOneWidget);

    // Switch to Tab 2: Badges / Achievements
    await tester.tap(find.byIcon(Icons.emoji_events_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Pet is still mounted on Badges tab!
    expect(find.byType(FloatingPetAvatar), findsOneWidget);

    // Switch to Tab 3: Profile
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Pet is still mounted on Profile tab!
    expect(find.byType(FloatingPetAvatar), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
