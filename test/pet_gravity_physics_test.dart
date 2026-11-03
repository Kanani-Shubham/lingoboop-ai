import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/core/widgets/floating_pet_avatar.dart';
import 'package:lingoboop/features/companion/presentation/lingo_card_widget.dart';
import 'package:lingoboop/features/navigation/presentation/main_navigation_shell.dart';

void main() {
  testWidgets('In-app Pet: Tap opens PolyCard, Drag closes card and applies gravity to floor',
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
    await tester.pump(const Duration(milliseconds: 500));

    // Initially, pet is mounted and card is closed
    expect(find.byType(FloatingPetAvatar), findsOneWidget);
    expect(find.byType(LingoCardWidget), findsNothing);

    final petFinder = find.byType(FloatingPetAvatar);
    final initialTopLeft = tester.getTopLeft(petFinder);

    // 1. TAP the pet (< 6px movement)
    await tester.tap(petFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // PolyCard should be open
    expect(find.byType(LingoCardWidget), findsOneWidget);

    // 2. DRAG the pet upwards towards the top (> 6px movement)
    // Hold gesture to observe mid-air position
    final center = tester.getCenter(petFinder);
    final gesture = await tester.startGesture(center);
    // Move up in increments to trigger pan recognizer (> 6px)
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 16));

    // Dragging closes the card immediately!
    expect(find.byType(LingoCardWidget), findsNothing);

    final midAirPos = tester.getTopLeft(petFinder);
    final releasedX = midAirPos.dx;

    // Verify it is indeed elevated in mid-air
    expect(midAirPos.dy, lessThan(initialTopLeft.dy - 30));

    // 3. RELEASE gesture: gravity pulls the pet back down to the floor
    await gesture.up();
    await tester.pump();

    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    final landedPos = tester.getTopLeft(petFinder);

    // Gravity pulled the pet down towards the bottom
    expect(landedPos.dy, greaterThan(midAirPos.dy));

    // Horizontal position was preserved during vertical fall
    expect((landedPos.dx - releasedX).abs(), lessThan(5.0));

    addTearDown(tester.view.resetPhysicalSize);
  });
}
