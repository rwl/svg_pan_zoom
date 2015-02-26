// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.test;

import 'dart:math' show Point;
import 'package:unittest/unittest.dart';
import 'package:svg_pan_zoom/svg_pan_zoom.dart';

const svgSelector = '#test-inline';
//const svgSelectorViewbox = '#test-viewbox';
//const svgSelectorTransform = '#test-transform';
//const svgSelectorViewboxTransform = '#test-viewbox-transform';

PublicSvgPanZoom initSvgPanZoom([SvgPanZoomOptions options, selector = svgSelector]) {
  if (options != null) {
    return svgPanZoom(selector, options);
  } else {
    return svgPanZoom(selector);
  }
}

const delta = 0.0001;

main() {
  group('api tests', () {
    PublicSvgPanZoom instance;

    setUp(() {
    });

    tearDown(() {
      if (instance != null) {
        instance.destroy();
      }
    });

    /// Pan state (enabled, disabled)

    test('by default pan should be enabled', () {
      instance = initSvgPanZoom();

      expect(instance.isPanEnabled(), isTrue);
    });

    test('disable pan via options', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..panEnabled = false
      );

      expect(instance.isPanEnabled(), isFalse);
    });

    test('disable and enable pan via API', () {
      instance = initSvgPanZoom();

      instance.disablePan();
      expect(instance.isPanEnabled(), isFalse);

      instance.enablePan();
      expect(instance.isPanEnabled(), isTrue);
    });

    /// Zoom state (enabled, disabled)

    test('by default zoom should be enabled', () {
      instance = initSvgPanZoom();

      expect(instance.isZoomEnabled(), isTrue);
    });

    test('disable zoom via options', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..zoomEnabled = false
      );

      expect(instance.isZoomEnabled(), isFalse);
    });

    test('disable and enable zoom via API', () {
      instance = initSvgPanZoom();

      instance.disableZoom();
      expect(instance.isZoomEnabled(), isFalse);

      instance.enableZoom();
      expect(instance.isZoomEnabled(), isTrue);
    });

    /// Controls state (enabled, disabled)

    test('by default controls are disabled', () {
      instance = initSvgPanZoom();

      expect(instance.isControlIconsEnabled(), isFalse);
    });

    test('enable controls via opions', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..controlIconsEnabled = true
      );

      expect(instance.isControlIconsEnabled(), isTrue);
    });

    test('disable and enable controls via API', () {
      instance = initSvgPanZoom();

      instance.enableControlIcons();
      expect(instance.isControlIconsEnabled(), isTrue);

      instance.disableControlIcons();
      expect(instance.isControlIconsEnabled(), isFalse);
    });

    /// Double click zoom state (enabled, disabled)

    test('by default double click zoom is enabled', () {
      instance = initSvgPanZoom();

      expect(instance.isDblClickZoomEnabled(), isTrue);
    });

    test('disable double click zoom via options', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..dblClickZoomEnabled = false
      );

      expect(instance.isDblClickZoomEnabled(), isFalse);
    });

    test('disable and enable double click zoom via API', () {
      instance = initSvgPanZoom();

      instance.disableDblClickZoom();
      expect(instance.isDblClickZoomEnabled(), isFalse);

      instance.enableDblClickZoom();
      expect(instance.isDblClickZoomEnabled(), isTrue);
    });

    /// Mouse wheel zoom state (enabled, disabled)

    test('by default mouse wheel zoom is enabled', () {
      instance = initSvgPanZoom();

      expect(instance.isMouseWheelZoomEnabled(), isTrue);
    });

    test('disable mouse wheel zoom via options', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..mouseWheelZoomEnabled = false
      );

      expect(instance.isMouseWheelZoomEnabled(), isFalse);
    });

    test('disable and enable mouse wheel zoom via API', () {
      instance = initSvgPanZoom();

      instance.disableMouseWheelZoom();
      expect(instance.isMouseWheelZoomEnabled(), isFalse);

      instance.enableMouseWheelZoom();
      expect(instance.isMouseWheelZoomEnabled(), isTrue);
    });

    /// Pan

    test('pan', () {
      instance = initSvgPanZoom();

      instance.pan(new Point(100, 300));

      expect(instance.getPan(), equals(new Point(100, 300)));
    });

    test('pan through API should work even if pan is disabled', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..panEnabled = false
      );

      instance.pan(new Point(100, 300));

      expect(instance.getPan(), equals(new Point(100, 300)));
    });

    test('pan by', () {
      instance = initSvgPanZoom();

      var initialPan = instance.getPan();

      instance.panBy(new Point(100, 300));

      expect(instance.getPan(), equals(new Point(initialPan.x + 100, initialPan.y + 300)));
    });

    /// Pan callbacks

    test('before pan', () {
      instance = initSvgPanZoom();

      var initialPan = instance.getPan();

      instance.setBeforePan((point) {
        expect(point, equals(initialPan));
      });

      instance.pan(new Point(100, 300));

      // Remove beforePan as it will be called on destroy
      instance.setBeforePan(null);

      // Pan one more time to test if it is really removed
      instance.pan(new Point(50, 150));
    });


    test('on pan', () {
      instance = initSvgPanZoom();

      instance.setOnPan((point) {
        expect(point, equals(new Point(100, 300)));
      });

      instance.pan(new Point(100, 300));

      // Remove onPan as it will be called on destroy
      instance.setOnPan(null);

      // Pan one more time to test if it is really removed
      instance.pan(new Point(50, 150));
    });

    /// Zoom

    test('zoom', () {
      instance = initSvgPanZoom();

      instance.zoom(3);

      expect(instance.getZoom(), equals(3));
    });

    test('zoom by', () {
      instance = initSvgPanZoom();

      var initialZoom = instance.getZoom();

      instance.zoomBy(2);

      expect(instance.getZoom(), equals(initialZoom * 2));
    });

    test('zoom at point', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoomAtPoint(2, new Point(200, 100));

      expect(instance.getZoom(), closeTo(2, delta));
      expect(instance.getPan(), equals(new Point(-300, -600)));
    });

    test('zoom at point by', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoomAtPointBy(2, new Point(200, 100));

      expect(instance.getZoom(), closeTo(2, delta));
      expect(instance.getPan(), equals(new Point(-300, -600)));
    });

    test('zoom in', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoomIn();

      expect(instance.getZoom(), closeTo(1.2, delta));
      expect(instance.getPan().x, closeTo(-130, delta));
      expect(instance.getPan().y, closeTo(-330, delta));
    });

    test('zoom out', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoomOut();

      expect(instance.getZoom(), closeTo(0.833333, delta));
      expect(instance.getPan().x, closeTo(16.666666, delta));
      expect(instance.getPan().y, closeTo(-183.333325, delta));
    });

    /// Zoom settings (min, max, sensitivity)

    test('default min zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoom(0.1);

      expect(instance.getZoom(), equals(0.5));
    });

    test('min zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
        ..minZoom = 1
      );

      instance.zoom(0.01);

      expect(instance.getZoom(), 1);
    });

    test('default max zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
      );

      instance.zoom(50);

      expect(instance.getZoom(), 10);
    });

    test('max zoom', () {
      // Do not use fit as it will set original zoom different from 1
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
        ..maxZoom = 20
      );

      instance.zoom(50);

      expect(instance.getZoom(), 20);
    });

    test('test zoomScaleSensitivity using zoomIn and zoomOut', () {
      var sensitivity = 0.2;

      // Do not use fit as it will set original zoom different from 1
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
        ..zoomScaleSensitivity = sensitivity
      );

      // Get initial zoom
      var initialZoom = instance.getZoom(); // should be one

      instance.zoomIn();

      expect(instance.getZoom(), closeTo(initialZoom * (1 + sensitivity), delta), reason: 'Check if zoom in uses scale sensitivity right');

      // Lets zoom to 2
      instance.zoom(2);

      // Now lets zoom out
      instance.zoomOut();

      expect(instance.getZoom(), closeTo(2 / (1 + sensitivity), delta), reason: 'Check if zoom out uses scale sensitiviry right');
    });

    /// Zoom callbacks

    test('before zoom', () {
      instance = initSvgPanZoom();

      var initialZoom = instance.getZoom();

      instance.setBeforeZoom((scale) {
        expect(scale, closeTo(initialZoom, delta));
      });

      instance.zoom(2.3);

      // Remove beforeZoom as it will be called on destroy
      instance.setBeforeZoom(null);

      // Zoom one more time to test if it is really removed
      instance.zoom(2.4);
    });


    test('on zoom', () {
      instance = initSvgPanZoom();

      instance.setOnZoom((scale) {
        expect(scale, closeTo(2.3, delta));
      });

      instance.zoom(2.3);

      // Remove onZoom as it will be called on destroy
      instance.setOnZoom(null);

      // Zoom one more time to test if it is really removed
      instance.zoom(2.4);
    });

    /// Reseting

    test('reset zoom', () {
      instance = initSvgPanZoom();

      var initialZoom = instance.getZoom();

      instance.zoom(2.3);

      instance.resetZoom();

      expect(instance.getZoom(), closeTo(initialZoom, delta));
    });

    test('reset pan', () {
      instance = initSvgPanZoom();

      var initialPan = instance.getPan();

      instance.panBy(new Point(100, 300));

      instance.resetPan();

      expect(instance.getPan(), equals(initialPan));
    });

    test('reset (zoom and pan)', () {
      instance = initSvgPanZoom();

      var initialZoom = instance.getZoom(),
          initialPan = instance.getPan();

      instance.zoom(2.3);
      instance.panBy(new Point(100, 300));

      instance.reset();

      expect(instance.getZoom(), closeTo(initialZoom, delta));
      expect(instance.getPan(), equals(initialPan));
    });

    /// Fit and center

    /// SVG size 700x300
    /// viewport zise 800x800
    ///
    /// If no viewBox attribute then initial zoom is always 1
    test('fit when initialized with fit: true', () {
      instance = initSvgPanZoom();

      instance.fit();

      expect(instance.getZoom(), closeTo(1, delta));
    });

    /// SVG size 700x300
    /// viewport zise 800x800
    /// zoom = Math.min(700/800, 300/800) = 0.375
    test('fit when initialized with fit: false', () {
      instance = initSvgPanZoom(new SvgPanZoomOptions()
        ..fit = false
        ..minZoom = 0.1
      );

      instance.fit();

      expect(instance.getZoom(), equals(0.375));
    });

    /// SVG size 700x300
    /// viewport zise 800x800 (sides ratio is 1)
    /// zoom 1 => width = height = 300
    ///
    /// panX = (700 - 300)/2 = 200
    /// panY = (300 - 300)/2 = 0
    test('center when zoom is 1', () {
      instance = initSvgPanZoom();

      instance.center();

      expect(instance.getPan(), equals(new Point(200, 0)));
    });

    /// SVG size 700x300
    /// viewport zise 800x800 (sides ratio is 1)
    /// zoom 0.5 => width = height = 150
    ///
    /// panX = (700 - 150)/2 = 275
    /// panY = (300 - 150)/2 = 75
    test('center when zoom is 0.5', () {
      instance = initSvgPanZoom();

      instance.zoom(0.5);
      instance.center();

      expect(instance.getPan(), equals(new Point(275, 75)));
    });

    /// Resize

    // TODO resize

    /// Destroy

    test('after destroy calling svgPanZoom again should return a new instance', () {
      instance = initSvgPanZoom();

      instance.destroy();

      var instance2 = initSvgPanZoom();

      expect(instance2, isNot(equals(instance)));

      // Set it as null so teardown will not try to destroy it again
      instance = null;

      // Destroy second instance
      instance2.destroy();
      instance2 = null;
    });
  });
}
