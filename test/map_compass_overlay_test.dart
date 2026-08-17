// Widget tests for [CompassOverlay].

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/ui/widgets/map/compass_overlay.dart';

void main() {
  testWidgets('CompassOverlay renders a SizedBox.shrink when headingDeg is null',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompassOverlay(headingDeg: null))),
    );
    expect(find.byType(CompassOverlay), findsOneWidget);
    // No heading text when heading is null.
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('CompassOverlay renders the needle + heading text when present',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CompassOverlay(headingDeg: 90.0)),
      ),
    );
    await tester.pump();
    expect(find.byType(CompassOverlay), findsOneWidget);
    expect(find.text('090°'), findsOneWidget);
  });
}
