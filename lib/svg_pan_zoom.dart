// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.

/// Enables panning and zooming of SVG in HTML documents.
library svg_pan_zoom;

import 'dart:js';
import 'dart:html';
import 'dart:math' as math;

/*import 'package:js/js.dart';

@JS('svgPanZoom')
external dynamic svgPanZoom(selector);

@JS()
external svgPanZoom(Options options);

@JS()
@anonymous
class Options {
  external bool get responsive;

  external factory Options({bool responsive});
}*/

typedef bool BeforeZoom(num oldZoom, num newZoom);
typedef void OnZoom(num newZoom);

typedef Pan BeforePan(Pan oldPan, Pan newPan);
typedef void OnPan(Pan newPan);

class Pan {
  final x, y;
  Pan(this.x, this.y);
}

class SvgPanZoom {
  JsObject _spz;

  BeforeZoom beforeZoom;
  OnZoom onZoom;
  BeforePan beforePan;
  OnPan onPan;

  factory SvgPanZoom.selector(String selector,
      {String viewportSelector: '.svg-pan-zoom_viewport',
      bool panEnabled: true,
      bool controlIconsEnabled: false,
      bool zoomEnabled: true,
      bool dblClickZoomEnabled: true,
      bool mouseWheelZoomEnabled: true,
      bool preventMouseEventsDefault: true,
      num zoomScaleSensitivity: 0.2,
      num minZoom: 0.5,
      num maxZoom: 10,
      bool fit: true,
      bool contain: false,
      bool center: true,
      String refreshRate: 'auto',
      BeforeZoom beforeZoom,
      OnZoom onZoom,
      BeforePan beforePan,
      OnPan onPan}) {
    var svg = document.querySelector(selector);
    return new SvgPanZoom(svg,
        viewportSelector: viewportSelector,
        panEnabled: panEnabled,
        controlIconsEnabled: controlIconsEnabled,
        zoomEnabled: zoomEnabled,
        dblClickZoomEnabled: dblClickZoomEnabled,
        mouseWheelZoomEnabled: mouseWheelZoomEnabled,
        preventMouseEventsDefault: preventMouseEventsDefault,
        zoomScaleSensitivity: zoomScaleSensitivity,
        minZoom: minZoom,
        maxZoom: maxZoom,
        fit: fit,
        contain: contain,
        center: center,
        refreshRate: refreshRate,
        beforeZoom: beforeZoom,
        onZoom: onZoom,
        beforePan: beforePan,
        onPan: onPan);
  }

  SvgPanZoom(Element svg,
      {String viewportSelector: '.svg-pan-zoom_viewport',
      bool panEnabled: true,
      bool controlIconsEnabled: false,
      bool zoomEnabled: true,
      bool dblClickZoomEnabled: true,
      bool mouseWheelZoomEnabled: true,
      bool preventMouseEventsDefault: true,
      num zoomScaleSensitivity: 0.2,
      num minZoom: 0.5,
      num maxZoom: 10,
      bool fit: true,
      bool contain: false,
      bool center: true,
      String refreshRate: 'auto',
      this.beforeZoom,
      this.onZoom,
      this.beforePan,
      this.onPan}) {
    bool _beforeZoom(num oldZoom, num newZoom) {
      if (beforeZoom != null) {
        return beforeZoom(oldZoom, newZoom);
      }
      return true;
    }
    void _onZoom(num newZoom) {
      if (onZoom != null) {
        onZoom(newZoom);
      }
    }
    _beforePan(oldPan, newPan) {
      if (beforePan != null) {
        print('old ${oldPan}');

        var pan = beforePan(new Pan(oldPan['x'], oldPan['y']),
            new Pan(newPan['x'], newPan['y']));
//        return new JsObject.jsify({'x': pan.x, 'y': pan.y});
      }
      return true;
    }
    void _onPan(newPan) {
      if (onPan != null) {
        onPan(new Pan(newPan['x'], newPan['y']));
      }
    }
    var options = {
      'viewportSelector': viewportSelector,
      'panEnabled': panEnabled,
      'controlIconsEnabled': controlIconsEnabled,
      'zoomEnabled': zoomEnabled,
      'dblClickZoomEnabled': dblClickZoomEnabled,
      'mouseWheelZoomEnabled': mouseWheelZoomEnabled,
      'preventMouseEventsDefault': preventMouseEventsDefault,
      'zoomScaleSensitivity': zoomScaleSensitivity,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'fit': fit,
      'contain': contain,
      'center': center,
      'refreshRate': refreshRate,
      'beforeZoom': _beforeZoom,
      'onZoom': _onZoom,
      'beforePan': _beforePan,
      'onPan': _onPan
    };
    var _options = new JsObject.jsify(options);
    try {
      _spz = context.callMethod('svgPanZoom', [svg, _options]);
    } on NoSuchMethodError catch (_) {
      throw new StateError('svg-pan-zoom not loaded');
    }
  }

  /// Unbind mouse events and free callbacks.
  destroy() => _spz?.callMethod('destroy');

  /// Enable or disable panning (default enabled).
  void set panEnabled(bool enabled) {
    _spz.callMethod(enabled ? 'enablePan' : 'disablePan');
  }

  bool get panEnabled => _spz.callMethod('isPanEnabled');

  /// Enable or disable zooming (default enabled).
  bool get zoomEnabled => _spz.callMethod('isZoomEnabled');

  void set zoomEnabled(bool enabled) {
    _spz.callMethod(enabled ? 'enableZoom' : 'disableZoom');
  }

  /// Enable or disable zooming by double clicking (default enabled).
  bool get dblClickZoomEnabled => _spz.callMethod('isDblClickZoomEnabled');

  void set dblClickZoomEnabled(bool enabled) {
    _spz.callMethod(enabled ? 'enableDblClickZoom' : 'disableDblClickZoom');
  }

  /// Zoom sensitivity.
//  num get zoomSensitivity => _spz['zoomSensitivity'];

//  void set zoomSensitivity(num sensitivity) {
//    _spz['zoomSensitivity'] = sensitivity;
//  }

  /// Minimum Zoom level
//  num get minZoom => _spz['minZoom'];

//  void set minZoom(num zoom) {
//    _spz['minZoom'] = zoom;
//  }

  /// Maximum Zoom level
//  int get maxZoom => _spz['maxZoom'];

//  void set maxZoom(num zoom) {
//    _spz['maxZoom'] = zoom;
//  }

  /// Insert icons to give user an option in addition to mouse events to
  /// control pan/zoom (default disabled).
  void set controlsEnabled(bool enabled) {
    _spz.callMethod(enabled ? 'enableControlIcons' : 'disableControlIcons');
  }

  bool get controlsEnabled => _spz.callMethod('isControlIconsEnabled');

  /// Enable or disable zooming by mouse wheel (default enabled).
  void set mouseWheelZoomEnabled(bool enabled) {
    _spz.callMethod(enabled ? 'enableMouseWheelZoom' : 'disableMouseWheelZoom');
  }

  bool get mouseWheelZoomEnabled => _spz.callMethod('isMouseWheelZoomEnabled');

  /// Get pan vector.
  math.Point get pan {
    var p = _spz.callMethod('getPan');
    return new math.Point(p['x'], p['y']);
  }

  void panTo(num x, num y) {
    _spz.callMethod('pan', [_pointMap(new math.Point(x, y))]);
  }

  /// Relatively pan the graph by a specified rendered position vector.
  void panBy(num x, num y) {
    _spz.callMethod('panBy', [_pointMap(new math.Point(x, y))]);
  }

  /// Get zoom scale.
  num get zoom => _spz.callMethod('getZoom');

  /// Zoom at center point.
  void set zoom(num scale) {
    _spz.callMethod('zoom', [scale]);
  }

  void zoomBy(num scale) {
    _spz.callMethod('zoomBy', [scale]);
  }

  /// Zoom by [scale] at [point].
  zoomAtPoint(num scale, math.Point point) {
    _spz.callMethod('zoomAtPoint', [scale, _pointMap(point)]);
  }

  void zoomAtPointBy(num scale, math.Point point) {
    _spz.callMethod('zoomAtPointBy', [scale, _pointMap(point)]);
  }

  void zoomIn() {
    _spz.callMethod('zoomIn');
  }

  void zoomOut() {
    _spz.callMethod('zoomOut');
  }

  /// Set zoom to initial state.
  resetZoom() => _spz.callMethod('resetZoom');

  /// Set pan to initial state.
  resetPan() => _spz.callMethod('resetPan');

  /// Set pan and zoom to initial state.
  reset() => _spz.callMethod('reset');

  /// Adjust viewport size (only) so it will fit in SVG.
  /// Does not center image.
  void fit() {
    _spz.callMethod('fit');
  }

  /// Adjust viewport pan (only) so it will be centered in SVG.
  /// Does not zoom/fit image.
  void center() {
    _spz.callMethod('center');
  }

  static JsObject _pointMap(math.Point point) {
    var p = {'x': point.x, 'y': point.y};
    return new JsObject.jsify(p);
  }

  num width() {
    var sizes = _spz.callMethod('getSizes');
    return sizes['width'];
  }

  num height() {
    var sizes = _spz.callMethod('getSizes');
    return sizes['height'];
  }

  num realZoom() {
    var sizes = _spz.callMethod('getSizes');
    return sizes['realZoom'];
  }

  Rectangle viewBox() {
    var sizes = _spz.callMethod('getSizes');
    var vb = sizes['viewBox'];
    return new Rectangle(vb['x'], vb['y'], vb['width'], vb['height']);
  }

  void resize() {
    _spz.callMethod('resize');
  }
}
