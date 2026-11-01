import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/features/home/presentation/main_companion_screen.dart';

void main() {
  testWidgets('MainCompanionScreen renders notes feed, floating pet and gear button',
      (WidgetTester tester) async {
    // Increase test surface size to simulate standard phone aspect ratio
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MainCompanionScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Action Header and Notes
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Train to Surat'), findsOneWidget);
    expect(find.text('Call Dad'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);

    // Verify Gear Settings button exists
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // Tap gear button to open settings sheet
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump(const Duration(milliseconds: 300));

    // Settings sheet should be visible
    expect(find.text('Pet and languages'), findsOneWidget);
    expect(find.text('I speak'), findsOneWidget);
    expect(find.text("I'm learning"), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Tap Done to close settings sheet
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pet and languages'), findsNothing);

    // Reset surface size after test
    addTearDown(tester.view.resetPhysicalSize);
  });
}
