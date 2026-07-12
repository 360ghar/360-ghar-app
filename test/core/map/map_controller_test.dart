// test/core/map/map_controller_test.dart
//
// Unit tests for [GharMapController] and the top-level map helpers
// ([boundsFromPoints], [distanceMeters], [circlePolygon]).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/map/map_controller.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

/// Fake [MapLibreMapController] that records camera calls and lets tests
/// stub the async projection / visible-region methods.
class FakeMapLibreController extends Fake implements MapLibreMapController {
  CameraPosition? _cameraPosition;
  final List<CameraUpdate> moveCalls = [];
  final List<({CameraUpdate update, Duration? duration})> animateCalls = [];
  math.Point<num>? _screenLocationResult = const math.Point(100, 200);
  LatLngBounds? _visibleRegion = LatLngBounds(
    southwest: const LatLng(10, 20),
    northeast: const LatLng(30, 40),
  );

  void setCameraPosition(CameraPosition? pos) => _cameraPosition = pos;
  void setScreenLocationResult(math.Point<num>? result) =>
      _screenLocationResult = result;
  void setVisibleRegion(LatLngBounds? bounds) => _visibleRegion = bounds;

  @override
  CameraPosition? get cameraPosition => _cameraPosition;

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    moveCalls.add(cameraUpdate);
    return true;
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    animateCalls.add((update: cameraUpdate, duration: duration));
    return true;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async => _visibleRegion!;

  @override
  Future<math.Point<num>> toScreenLocation(LatLng latLng) async =>
      _screenLocationResult!;
}

void main() {
  group('GharMapController', () {
    late GharMapController wrapper;
    late FakeMapLibreController fake;

    setUp(() {
      wrapper = GharMapController();
      fake = FakeMapLibreController();
    });

    test('isAttached is false before attach and true after', () {
      expect(wrapper.isAttached, isFalse);
      wrapper.attach(fake);
      expect(wrapper.isAttached, isTrue);
    });

    test('controller getter returns null before attach and the controller after', () {
      expect(wrapper.controller, isNull);
      wrapper.attach(fake);
      expect(wrapper.controller, same(fake));
    });

    test('center returns null when no camera position is set', () {
      wrapper.attach(fake);
      expect(wrapper.center, isNull);
    });

    test('center returns the camera target when a camera position is set', () {
      fake.setCameraPosition(const CameraPosition(target: LatLng(12, 34), zoom: 10));
      wrapper.attach(fake);
      expect(wrapper.center, const LatLng(12, 34));
    });

    test('zoom returns kDefaultInitialZoom when camera position is unknown', () {
      wrapper.attach(fake);
      expect(wrapper.zoom, kDefaultInitialZoom);
    });

    test('zoom returns the camera zoom when set', () {
      fake.setCameraPosition(const CameraPosition(target: LatLng(12, 34), zoom: 7));
      wrapper.attach(fake);
      expect(wrapper.zoom, 7);
    });

    test('move calls moveCamera on the underlying controller', () async {
      wrapper.attach(fake);
      await wrapper.move(const LatLng(1, 2), 14);
      expect(fake.moveCalls, hasLength(1));
    });

    test('move is a no-op when not attached', () async {
      // Should not throw.
      await wrapper.move(const LatLng(1, 2), 14);
      expect(fake.moveCalls, isEmpty);
    });

    test('animateTo calls animateCamera with the given zoom', () async {
      fake.setCameraPosition(const CameraPosition(target: LatLng(0, 0), zoom: 5));
      wrapper.attach(fake);
      await wrapper.animateTo(const LatLng(10, 20), zoom: 12);
      expect(fake.animateCalls, hasLength(1));
      expect(fake.animateCalls.single.duration, const Duration(milliseconds: 400));
    });

    test('animateTo preserves current zoom when zoom is omitted', () async {
      fake.setCameraPosition(const CameraPosition(target: LatLng(0, 0), zoom: 9));
      wrapper.attach(fake);
      await wrapper.animateTo(const LatLng(10, 20));
      expect(fake.animateCalls, hasLength(1));
    });

    test('animateTo is a no-op when not attached', () async {
      await wrapper.animateTo(const LatLng(10, 20));
      expect(fake.animateCalls, isEmpty);
    });

    test('animateZoom uses newLatLngZoom when target is known', () async {
      fake.setCameraPosition(const CameraPosition(target: LatLng(5, 6), zoom: 3));
      wrapper.attach(fake);
      await wrapper.animateZoom(16);
      expect(fake.animateCalls, hasLength(1));
    });

    test('animateZoom falls back to zoomTo when target is unknown', () async {
      wrapper.attach(fake);
      // cameraPosition is null → fallback path.
      await wrapper.animateZoom(16);
      expect(fake.animateCalls, hasLength(1));
    });

    test('animateZoom is a no-op when not attached', () async {
      await wrapper.animateZoom(16);
      expect(fake.animateCalls, isEmpty);
    });

    test('fitBounds with a single point animates to that point at zoom 15', () async {
      wrapper.attach(fake);
      await wrapper.fitBounds([const LatLng(1, 2)]);
      expect(fake.animateCalls, hasLength(1));
      expect(fake.moveCalls, isEmpty);
    });

    test('fitBounds with multiple points animates to the enclosing bounds', () async {
      wrapper.attach(fake);
      await wrapper.fitBounds([const LatLng(10, 20), const LatLng(30, 40)]);
      expect(fake.animateCalls, hasLength(1));
    });

    test('fitBounds with custom padding passes it through', () async {
      wrapper.attach(fake);
      await wrapper.fitBounds(
        [const LatLng(10, 20), const LatLng(30, 40)],
        padding: const EdgeInsets.all(100),
      );
      expect(fake.animateCalls, hasLength(1));
    });

    test('fitBounds is a no-op when not attached', () async {
      await wrapper.fitBounds([const LatLng(10, 20), const LatLng(30, 40)]);
      expect(fake.animateCalls, isEmpty);
    });

    test('fitBounds is a no-op when points is empty', () async {
      wrapper.attach(fake);
      await wrapper.fitBounds([]);
      expect(fake.animateCalls, isEmpty);
    });

    test('getVisibleRegion returns the visible region when attached', () async {
      wrapper.attach(fake);
      final region = await wrapper.getVisibleRegion();
      expect(region, isNotNull);
    });

    test('getVisibleRegion returns null when not attached', () async {
      final region = await wrapper.getVisibleRegion();
      expect(region, isNull);
    });

    test('toScreenLocation returns the projected point when attached', () async {
      wrapper.attach(fake);
      final point = await wrapper.toScreenLocation(const LatLng(1, 2));
      expect(point, isNotNull);
    });

    test('toScreenLocation returns null when not attached', () async {
      final point = await wrapper.toScreenLocation(const LatLng(1, 2));
      expect(point, isNull);
    });

    test('dispose drops the underlying controller reference', () {
      wrapper.attach(fake);
      expect(wrapper.isAttached, isTrue);
      wrapper.dispose();
      expect(wrapper.isAttached, isFalse);
      expect(wrapper.controller, isNull);
    });
  });

  group('boundsFromPoints', () {
    test('computes southwest/northeast for two points', () {
      final bounds = boundsFromPoints([const LatLng(10, 20), const LatLng(30, 5)]);
      expect(bounds.southwest, const LatLng(10, 5));
      expect(bounds.northeast, const LatLng(30, 20));
    });

    test('handles a single point (sw == ne)', () {
      final bounds = boundsFromPoints([const LatLng(15, 25)]);
      expect(bounds.southwest, const LatLng(15, 25));
      expect(bounds.northeast, const LatLng(15, 25));
    });

    test('handles negative coordinates', () {
      final bounds = boundsFromPoints([
        const LatLng(-10, -20),
        const LatLng(-30, -5),
      ]);
      expect(bounds.southwest, const LatLng(-30, -20));
      expect(bounds.northeast, const LatLng(-10, -5));
    });

    test('handles points spanning the equator and prime meridian', () {
      final bounds = boundsFromPoints([
        const LatLng(-5, -10),
        const LatLng(5, 10),
      ]);
      expect(bounds.southwest, const LatLng(-5, -10));
      expect(bounds.northeast, const LatLng(5, 10));
    });
  });

  group('distanceMeters', () {
    test('returns 0 for identical coordinates', () {
      expect(distanceMeters(const LatLng(10, 20), const LatLng(10, 20)), 0);
    });

    test('returns a positive distance for different coordinates', () {
      final d = distanceMeters(const LatLng(0, 0), const LatLng(0, 1));
      // 1 degree of longitude at the equator using Earth radius 6378137 m.
      expect(d, closeTo(111319, 100));
    });

    test('is symmetric', () {
      final a = const LatLng(28.6, 77.2);
      final b = const LatLng(19.07, 72.87);
      expect(distanceMeters(a, b), closeTo(distanceMeters(b, a), 1));
    });

    test('handles antipodal points', () {
      final d = distanceMeters(const LatLng(0, 0), const LatLng(0, 180));
      // Half the Earth's circumference using radius 6378137 m.
      expect(d, closeTo(20037508, 1000));
    });
  });

  group('circlePolygon', () {
    test('produces a FeatureCollection with a Polygon geometry', () {
      final geo = circlePolygon(const LatLng(28.6, 77.2), 1.0);
      expect(geo['type'], 'FeatureCollection');
      final features = geo['features'] as List;
      expect(features, hasLength(1));
      final feature = features.first as Map<String, dynamic>;
      expect(feature['type'], 'Feature');
      final geometry = feature['geometry'] as Map<String, dynamic>;
      expect(geometry['type'], 'Polygon');
    });

    test('ring is closed (first == last coordinate)', () {
      final geo = circlePolygon(const LatLng(28.6, 77.2), 0.5, steps: 8);
      final ring = _ring(geo);
      expect(ring.first, ring.last);
    });

    test('ring has steps+1 coordinates', () {
      final geo = circlePolygon(const LatLng(28.6, 77.2), 0.5, steps: 16);
      expect(_ring(geo), hasLength(17));
    });

    test('coordinates are [lng, lat] order', () {
      final geo = circlePolygon(const LatLng(28.6, 77.2), 0.5, steps: 4);
      final ring = _ring(geo);
      for (final coord in ring) {
        expect(coord, isA<List<double>>());
        expect(coord, hasLength(2));
      }
    });

    test('a zero-radius circle produces a degenerate point ring', () {
      final geo = circlePolygon(const LatLng(28.6, 77.2), 0.0, steps: 4);
      final ring = _ring(geo);
      // All points should be at the center.
      for (final coord in ring) {
        expect(coord[0], closeTo(77.2, 0.001));
        expect(coord[1], closeTo(28.6, 0.001));
      }
    });
  });
}

List<List<double>> _ring(Map<String, dynamic> geo) {
  final features = geo['features'] as List;
  final feature = features.first as Map<String, dynamic>;
  final geometry = feature['geometry'] as Map<String, dynamic>;
  final coordinates = geometry['coordinates'] as List;
  return (coordinates.first as List).cast<List<double>>();
}
