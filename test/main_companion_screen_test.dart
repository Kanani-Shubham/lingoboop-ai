import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingoboop/features/home/presentation/main_companion_screen.dart';

void main() {
  testWidgets('MainCompanionScreen renders speech companion stage, prompts and settings sheet',
      (WidgetTester tester) async {
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

    // Verify Language Pair Pill
    expect(find.textContaining('Gujarati'), findsWidgets);

    // Verify Practice Prompts
    expect(find.text('Ask for Directions'), findsOneWidget);
    expect(find.text('Order Refreshments'), findsOneWidget);
    expect(find.text('Introduce Yourself'), findsOneWidget);
    expect(find.text('Free Speech Practice'), findsOneWidget);

    // Verify History icon and Tune button exist
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    // Tap tune button to open settings sheet
    await tester.tap(find.byIcon(Icons.tune));
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

    addTearDown(tester.view.resetPhysicalSize);
  });
}
