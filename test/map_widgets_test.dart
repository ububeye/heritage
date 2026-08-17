// Widget tests for the extracted map primitives (SiteMarker, SelectedSiteMarker,
// RoutePolylineLayer). These are smoke tests that the widgets compose, render,
// and respond to the `isOffRoute` flag without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:stone_town_heritage_vt_guide/ui/widgets/map/route_polyline_layer.dart';
import 'package:stone_town_heritage_vt_guide/ui/widgets/map/selected_site_marker.dart';
import 'package:stone_town_heritage_vt_guide/ui/widgets/map/site_marker.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('SiteMarker renders label + icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SiteMarker(
          label: 'Forodhani',
          color: Color(0xFFD97706),
          icon: PhosphorIconsRegular.bank,
        ),
      ),
    );
    expect(find.text('Forodhani'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.bank), findsOneWidget);
  });

  testWidgets('SelectedSiteMarker renders selected=true without crashing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SelectedSiteMarker(
          label: 'House of Wonders',
          color: Color(0xFFE11D48),
          icon: PhosphorIconsRegular.maskHappy,
          selected: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('House of Wonders'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.maskHappy), findsOneWidget);
  });

  testWidgets('RoutePolylineLayer renders nothing on a degenerate polyline',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlutterMap(
          options: MapOptions(initialCenter: const LatLng(0, 0), initialZoom: 12),
          children: [
            RoutePolylineLayer(
              points: const [LatLng(0, 0)],
              isOffRoute: false,
              routeColor: const Color(0xFF1565C0),
              underlayColor: const Color(0xFFFFFFFF),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('RoutePolylineLayer renders a polyline for >= 2 points',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlutterMap(
          options: MapOptions(initialCenter: const LatLng(0, 0), initialZoom: 12),
          children: [
            RoutePolylineLayer(
              points: const [
                LatLng(-6.162, 39.190),
                LatLng(-6.165, 39.195),
              ],
              isOffRoute: false,
              routeColor: const Color(0xFF1565C0),
              underlayColor: const Color(0xFFFFFFFF),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('RoutePolylineLayer swaps colour when off-route',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlutterMap(
          options: MapOptions(initialCenter: const LatLng(0, 0), initialZoom: 12),
          children: [
            RoutePolylineLayer(
              points: const [
                LatLng(-6.162, 39.190),
                LatLng(-6.165, 39.195),
              ],
              isOffRoute: true,
              routeColor: const Color(0xFF1565C0),
              warningColor: const Color(0xFFEAB308),
              underlayColor: const Color(0xFFFFFFFF),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(PolylineLayer), findsOneWidget);
  });
}
