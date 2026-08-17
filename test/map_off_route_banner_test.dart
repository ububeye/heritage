// Widget tests for [OffRouteBanner].

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stone_town_heritage_vt_guide/core/theme/app_semantic_colors.dart';
import 'package:stone_town_heritage_vt_guide/ui/widgets/map/off_route_banner.dart';

Widget _host(Widget child) {
  // Provide a minimal ThemeData that includes the AppSemanticColors
  // extension the OffRouteBanner reads from context.semanticColors.
  const semantic = AppSemanticColors(
    success: Color(0xFF2E7D32),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFFEAB308),
    onWarning: Color(0xFF000000),
    info: Color(0xFF1565C0),
    onInfo: Color(0xFFFFFFFF),
    rating: Color(0xFFFFB300),
    mapRoute: Color(0xFF1565C0),
    mapUser: Color(0xFF1E88E5),
    mapMarker: Color(0xFFD97706),
    onImage: Color(0xFFFFFFFF),
    onImageMuted: Color(0xFFCFD8DC),
    imageScrim: Color(0x99000000),
    shadow: Color(0x33000000),
  );
  final base = ThemeData(useMaterial3: true);
  return MaterialApp(
    theme: base.copyWith(
      extensions: <ThemeExtension<dynamic>>[semantic],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('OffRouteBanner shows the label when isVisible is true',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const OffRouteBanner(isVisible: true, label: 'Recalculating route…'),
      ),
    );
    // Pump once to allow AnimatedSwitcher to swap in the visible child;
    // don't pumpAndSettle — the CircularProgressIndicator is forever
    // animating.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Recalculating route…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('OffRouteBanner hides when isVisible is false', (tester) async {
    await tester.pumpWidget(
      _host(const OffRouteBanner(isVisible: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Recalculating route…'), findsNothing);
  });

  test('OffRouteBannerController toggles state for a long enough hold',
      () async {
    final ctrl = OffRouteBannerController();
    final log = <bool>[];
    ctrl.bind(() => log.add(ctrl.isVisible));

    ctrl.show(hold: const Duration(milliseconds: 20));
    expect(ctrl.isVisible, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(ctrl.isVisible, isFalse);
    expect(log, [true, false]);
    ctrl.dispose();
  });
}
