// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.test;

import 'dart:math' show Point;
import 'package:test/test.dart';
import 'package:svg_pan_zoom/svg_pan_zoom.dart';

const svgSelector = '#test-inline';
const svgSelectorViewbox = '#test-viewbox';
const svgSelectorTransform = '#test-transform';
const svgSelectorViewboxTransform = '#test-viewbox-transform';

const delta = 0.0001;

main() {
  group('SvgPanZoom', () {
    testSvgPanZoom(svgSelector);
    testSvgPanZoom(svgSelectorViewbox);
    testSvgPanZoom(svgSelectorTransform);
    testSvgPanZoom(svgSelectorViewboxTransform);
  });
}

testSvgPanZoom(String selector) {
  group(selector, () {
    SvgPanZoom instance;

    setUp(() {
      instance = new SvgPanZoom.selector(selector);
    });

    tearDown(() {
      if (instance != null) {
        instance.destroy();
        instance = null;
      }
    });

    /// Pan state (enabled, disabled)

    test('by default pan should be enabled', () {
      expect(instance.panEnabled, isTrue);
    });

    test('disable pan via options', () {
      instance.panEnabled = false;
      expect(instance.panEnabled, isFalse);
    });

    test('disable and enable pan via API', () {
      instance.panEnabled = false;
      expect(instance.panEnabled, isFalse);

      instance.panEnabled = true;
      expect(instance.panEnabled, isTrue);
    });

    /// Zoom state (enabled, disabled)

    test('by default zoom should be enabled', () {
      expect(instance.zoomEnabled, isTrue);
    });

    test('disable zoom via options', () {
      instance.zoomEnabled = false;

      expect(instance.zoomEnabled, isFalse);
    });

    test('disable and enable zoom via API', () {
      instance.zoomEnabled = false;
      expect(instance.zoomEnabled, isFalse);

      instance.zoomEnabled = true;
      expect(instance.zoomEnabled, isTrue);
    });

    /// Controls state (enabled, disabled)

    test('by default controls are disabled', () {
      expect(instance.controlsEnabled, isFalse);
    });

    test('enable controls via opions', () {
      instance.controlsEnabled = true;

      expect(instance.controlsEnabled, isTrue);
    });

    test('disable and enable controls via API', () {
      instance.controlsEnabled = true;
      expect(instance.controlsEnabled, isTrue);

      instance.controlsEnabled = false;
      expect(instance.controlsEnabled, isFalse);
    });

    /// Double click zoom state (enabled, disabled)

    test('by default double click zoom is enabled', () {
      expect(instance.dblClickZoomEnabled, isTrue);
    });

    test('disable double click zoom via options', () {
      instance.dblClickZoomEnabled = false;

      expect(instance.dblClickZoomEnabled, isFalse);
    });

    test('disable and enable double click zoom via API', () {
      instance.dblClickZoomEnabled = false;
      expect(instance.dblClickZoomEnabled, isFalse);

      instance.dblClickZoomEnabled = true;
      expect(instance.dblClickZoomEnabled, isTrue);
    });

    /// Mouse wheel zoom state (enabled, disabled)

    test('by default mouse wheel zoom is enabled', () {
      expect(instance.mouseWheelZoomEnabled, isTrue);
    });

    test('disable mouse wheel zoom via options', () {
      instance.mouseWheelZoomEnabled = false;

      expect(instance.mouseWheelZoomEnabled, isFalse);
    });

    test('disable and enable mouse wheel zoom via API', () {
      instance.mouseWheelZoomEnabled = false;
      expect(instance.mouseWheelZoomEnabled, isFalse);

      instance.mouseWheelZoomEnabled = true;
      expect(instance.mouseWheelZoomEnabled, isTrue);
    });

    /// Pan

    test('pan', () {
      instance.panTo(100, 300);

      expect(instance.pan, equals(new Point(100, 300)));
    });

    test('pan through API should work even if pan is disabled', () {
      instance.panEnabled = false;

      instance.panTo(100, 300);

      expect(instance.pan, equals(new Point(100, 300)));
    });

    test('pan by', () {
      var initialPan = instance.pan;

      instance.panBy(100, 300);

      expect(instance.pan,
          equals(new Point(initialPan.x + 100, initialPan.y + 300)));
    });

    /// Pan callbacks

//    test('before pan', () {
//      var initialPan = instance.pan;
//      bool called = false;
//
//      instance.beforePan = (Pan point, _) {
//        called = true;
//        expect(point.x, equals(initialPan.x));
//        expect(point.y, equals(initialPan.y));
//      };
//
//      instance.panTo(100, 300);
//      expect(called, isTrue);
//
//      // Remove beforePan as it will be called on destroy
//      instance.beforePan = null;
//      called = false;
//
//      // Pan one more time to test if it is really removed
//      instance.panTo(50, 150);
//      expect(called, isFalse);
//    });

    test('on pan', () {
      var called = false;

      instance.onPan = (Pan point) {
        called = true;
        expect(point.x, equals(100));
        expect(point.y, equals(300));
      };

      instance.panTo(100, 300);
      expect(called, isTrue);

      // Remove onPan as it will be called on destroy
      instance.onPan = null;
      called = false;

      // Pan one more time to test if it is really removed
      instance.panTo(50, 150);
      expect(called, isFalse);
    });

    /// Zoom

    test('zoom', () {
      instance.zoom = 3;

      expect(instance.zoom, equals(3));
    });

    test('zoom by', () {
      var initialZoom = instance.zoom;

      instance.zoomBy(2);

      expect(instance.zoom, equals(initialZoom * 2));
    });

    test('zoom at point', () {
      instance = new SvgPanZoom.selector(selector, fit: false);

      instance.zoomAtPoint(2, new Point(200, 100));

      expect(instance.zoom, closeTo(2, delta));
//      expect(instance.pan, equals(new Point(-300, -600)));
    });

    test('zoom at point by', () {
      instance = new SvgPanZoom.selector(selector, fit: false);

      instance.zoomAtPointBy(2, new Point(200, 100));

      expect(instance.zoom, closeTo(2, delta));
//      expect(instance.pan, equals(new Point(-300, -600)));
    });

//    test('zoom in', () {
//      instance = new SvgPanZoom.selector(selector, fit: false);
//
//      instance.zoomIn();
//
//      expect(instance.zoom, closeTo(1.1, delta));
//      expect(instance.pan.x, closeTo(-90, delta));
//      expect(instance.pan.y, closeTo(-290, delta));
//    });

//    test('zoom out', () {
//      instance = new SvgPanZoom.selector(selector, fit: false);
//
//      instance.zoomOut();
//
//      expect(instance.zoom, closeTo(0.90909, delta));
//      expect(instance.pan.x, closeTo(-13.636374, delta));
//      expect(instance.pan.y, closeTo(-213.636374, delta));
//    });

    /// Zoom settings (min, max, sensitivity)

    test('default min zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = new SvgPanZoom.selector(selector, fit: false);

      instance.zoom = 0.1;

      expect(instance.zoom, equals(0.5));
    });

//    test('min zoom', () {
//      // Do not use fit as it will set original zoom different from 1
//      instance = new SvgPanZoom.selector(selector, fit: false, minZoom: 1);
//
//      instance.zoom = 0.01;
//
//      expect(instance.zoom, 1);
//    });

    test('default max zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = new SvgPanZoom.selector(selector, fit: false);

      instance.zoom = 50;

      expect(instance.zoom, 10);
    });

//    test('max zoom', () {
//      // Do not use fit as it will set original zoom different from 1
//      instance = new SvgPanZoom.selector(selector, fit: false, maxZoom: 20);
//
//      instance.zoom = 50;
//
//      expect(instance.zoom, 20);
//    });

    test('test zoomScaleSensitivity using zoomIn and zoomOut', () {
      var sensitivity = 0.2;

      // Do not use fit as it will set original zoom different from 1
      instance = new SvgPanZoom.selector(selector,
          fit: false, zoomScaleSensitivity: sensitivity);

      // Get initial zoom
      var initialZoom = instance.zoom; // should be one

      instance.zoomIn();

      expect(instance.zoom, closeTo(initialZoom * (1 + sensitivity), delta),
          reason: 'Check if zoom in uses scale sensitivity right');

      // Lets zoom to 2
      instance.zoom = 2;

      // Now lets zoom out.
      instance.zoomOut();

      expect(instance.zoom, closeTo(2 / (1 + sensitivity), delta),
          reason: 'Check if zoom out uses scale sensitivity right');
    });

    /// Zoom callbacks

    test('before zoom', () {
      var initialZoom = instance.zoom;
      var called = false;

      instance.beforeZoom = (num scale, _) {
        called = true;
        expect(scale, closeTo(initialZoom, delta));
      };

      instance.zoom = 2.3;
      expect(called, isTrue);

      // Remove beforeZoom as it will be called on destroy.
      instance.beforeZoom = null;
      called = false;

      // Zoom one more time to test if it is really removed.
      instance.zoom = 2.4;
      expect(called, isFalse);
    });

    test('on zoom', () {
      var called = false;

      instance.onZoom = (num scale) {
        called = true;
        expect(scale, closeTo(2.3, delta));
      };

      instance.zoom = 2.3;
      expect(called, isTrue);

      // Remove onZoom as it will be called on destroy.
      instance.onZoom = null;
      called = false;

      // Zoom one more time to test if it is really removed.
      instance.zoom = 2.4;
      expect(called, isFalse);
    });

    /// Reseting

    test('reset zoom', () {
      var initialZoom = instance.zoom;

      instance.zoom = 2.3;

      instance.resetZoom();

      expect(instance.zoom, closeTo(initialZoom, delta));
    });

    test('reset pan', () {
      var initialPan = instance.pan;

      instance.panBy(100, 300);

      instance.resetPan();

      expect(instance.pan, equals(initialPan));
    });

    test('reset (zoom and pan)', () {
      var initialZoom = instance.zoom;
      var initialPan = instance.pan;

      instance.zoom = 2.3;
      instance.panBy(100, 300);

      instance.reset();

      expect(instance.zoom, closeTo(initialZoom, delta));
      expect(instance.pan, equals(initialPan));
    });

    /// Fit and center

    /// SVG size 700x300
    /// viewport size 800x800
    ///
    /// If no viewBox attribute then initial zoom is always 1.
    test('fit when initialized with fit: true', () {
      instance.fit();

      expect(instance.zoom, closeTo(1, delta));
    });

    /// SVG size 700x300
    /// viewport size 800x800
    /// zoom = Math.min(700/800, 300/800) = 0.375
//    test('fit when initialized with fit: false', () {
//      instance = new SvgPanZoom.selector(selector, fit: false, minZoom: 0.1);
//
//      instance.fit();
//
//      expect(instance.zoom, equals(0.375));
//    });

    /// SVG size 700x300
    /// viewport size 800x800 (sides ratio is 1)
    /// zoom 1 => width = height = 300
    ///
    /// panX = (700 - 300)/2 = 200
    /// panY = (300 - 300)/2 = 0
//    test('center when zoom is 1', () {
//      instance.center();
//
//      expect(instance.pan, equals(new Point(200, 0)));
//    });

    /// SVG size 700x300
    /// viewport size 800x800 (sides ratio is 1)
    /// zoom 0.5 => width = height = 150
    ///
    /// panX = (700 - 150)/2 = 275
    /// panY = (300 - 150)/2 = 75
//    test('center when zoom is 0.5', () {
//      instance.zoom = 0.5;
//      instance.center();
//
//      expect(instance.pan, equals(new Point(275, 75)));
//    });

    /// Resize

    // TODO resize
  });
}
