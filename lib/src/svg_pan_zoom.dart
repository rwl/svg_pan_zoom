// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.internal;

import 'dart:math' as math;
import 'dart:html' hide Point;
import 'dart:async';
import 'dart:svg' hide ImageElement;
import 'shadow_viewport.dart';
import 'svg_utils.dart' as svgUtils;
//import 'control_icons.dart' as controls;
import 'utils.dart' as utils;

part 'control_icons.dart';

class SvgPanZoomOptions {
  /// Viewport selector. Can be querySelector string or SVGElement
  var viewportSelector = '.svg-pan-zoom_viewport';

  /// enable or disable panning (default enabled)
  bool panEnabled = true;

  /// insert icons to give user an option in addition to mouse events to control pan/zoom (default disabled)
  bool controlIconsEnabled = false;

  /// enable or disable zooming (default enabled)
  bool zoomEnabled = true;

  /// enable or disable zooming by double clicking (default enabled)
  bool dblClickZoomEnabled = true;

  /// enable or disable zooming by mouse wheel (default enabled)
  bool mouseWheelZoomEnabled = true;

  /// Zoom sensitivity
  num zoomScaleSensitivity = 0.2;

  /// Minimum Zoom level
  num minZoom = 0.5;

  /// Maximum Zoom level
  int maxZoom = 10;

  /// enable or disable viewport fit in SVG (default true)
  bool fit = true;

  /// enable or disable viewport centering in SVG (default true)
  bool center = true;

  /// Maximum number of frames per second (altering SVG's viewport)
  var refreshRate = 'auto';

  BeforeZoomFn beforeZoom = null;
  OnZoomFn onZoom = null;
  BeforePanFn beforePan = null;
  OnPanFn onPan = null;
  CustomEventsHandler customEventsHandler = null;
}

abstract class CustomEventsHandler {
  List<String> haltEventListeners;
  init(SvgSvgElement svg, SvgPanZoom spz);
  destroy(SvgSvgElement svg, SvgPanZoom spz);
}

enum State {
  NONE, PAN
}

class SvgPanZoom {
  final SvgSvgElement _svg;
  var _defs;
  SvgPanZoomOptions _options;
  State _state;
  num _width, _height;
  ShadowViewport _viewport;

  Map<String, EventListener> _eventListeners;
  GElement _controlIcons;

  factory SvgPanZoom.selector(String selector, [SvgPanZoomOptions options]) {
    final svg = document.querySelector(selector);
    if (svg is! SvgSvgElement) {
      throw new ArgumentError.value(selector, 'selector');
    }
    return new SvgPanZoom(svg, options);
  }

  SvgPanZoom(this._svg, [this._options]) {
    _defs = _svg.querySelector('defs');

    // Add default attributes to SVG
    svgUtils.setupSvgAttributes(_svg);

    // Set options
    if (_options == null) {
      _options = new SvgPanZoomOptions();
    }

    // Set default state
    _state = State.NONE;

    // Get dimensions
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(_svg);
    _width = boundingClientRectNormalized.width;
    _height = boundingClientRectNormalized.height;

    // Init shadow viewport
    _viewport = new ShadowViewport(svgUtils.getOrCreateViewport(_svg, _options.viewportSelector), new ViewportOptions()
      ..svg = _svg
      ..width = _width
      ..height = _height
      ..fit = _options.fit
      ..center = _options.center
      ..refreshRate = _options.refreshRate
      // Put callbacks into functions as they can change through time
      ..beforeZoom = (oldScale, newScale) {
        if (_viewport != null && _options.beforeZoom != null) {
          return _options.beforeZoom(oldScale, newScale);
        }
      }
      ..onZoom = (scale) {
        if (_viewport != null && _options.onZoom != null) {
          return _options.onZoom(scale);
        }
      }
      ..beforePan = (oldPoint, newPoint) {
        if (_viewport != null && _options.beforePan != null) {
          return _options.beforePan(oldPoint, newPoint);
        }
      }
      ..onPan = (point) {
        if (_viewport != null && _options.onPan != null) {
          return _options.onPan(point);
        }
      }
    );

    // Wrap callbacks into public API context
//    var publicInstance = getPublicInstance();
//    publicInstance.setBeforeZoom(_options.beforeZoom);
//    publicInstance.setOnZoom(_options.onZoom);
//    publicInstance.setBeforePan(_options.beforePan);
//    publicInstance.setOnPan(_options.onPan);

    if (_options.controlIconsEnabled) {
      _enableControls(this);
    }

    // Init events handlers
    _setupHandlers();
  }

  /// Register event handlers
  void _setupHandlers() {
    var prevEvt = null; // use for touchstart event to detect double tap

    _eventListeners = {
      // Mouse down group
      'mousedown': (evt) => _handleMouseDown(evt, null),
      'touchstart': (evt) {
        _handleMouseDown(evt, prevEvt);
        prevEvt = evt;
        return;
      },

      // Mouse up group
      'mouseup': (evt) => _handleMouseUp(evt),
      'touchend': (evt) => _handleMouseUp(evt),

      // Mouse move group
      'mousemove': (evt) => _handleMouseMove(evt),
      'touchmove': (evt) => _handleMouseMove(evt),

      // Mouse leave group
      'mouseleave': (evt) => _handleMouseUp(evt),
      'touchleave': (evt) => _handleMouseUp(evt),
      'touchcancel': (evt) => _handleMouseUp(evt)
    };

    // Init custom events handler if available.
    if (_options.customEventsHandler != null) {
      _options.customEventsHandler.init(_svg, this/*getPublicInstance()*/);

      // Custom event handler may halt builtin listeners
      var haltEventListeners = _options.customEventsHandler.haltEventListeners;
      if (haltEventListeners != null && !haltEventListeners.isEmpty) {
        for (var i = haltEventListeners.length - 1; i >= 0; i--) {
          if (_eventListeners.containsKey(haltEventListeners[i])) {
            _eventListeners.remove(haltEventListeners[i]);
          }
        }
      }
    }

    // Bind eventListeners
    for (var event in _eventListeners.keys) {
      _svg.addEventListener(event, _eventListeners[event], false);
    }

    // Zoom using mouse wheel
    if (_options.mouseWheelZoomEnabled) {
      // Set to false as enable will set it back to true.
      _options.mouseWheelZoomEnabled = false;
      enableMouseWheelZoom();
    }
  }

  Function _wheelListener;
  StreamSubscription<WheelEvent> _wheelSubscription;

  /// Enable ability to zoom using mouse wheel.
  void enableMouseWheelZoom() {
    if (!_options.mouseWheelZoomEnabled) {
      // Mouse wheel listener
      _wheelListener = (evt) {
        return _handleMouseWheel(evt);
      };

      // Bind wheelListener
      _wheelSubscription = _svg.onMouseWheel.listen(_wheelListener);

      _options.mouseWheelZoomEnabled = true;
    }
  }

  /// Disable ability to zoom using mouse wheel.
  void disableMouseWheelZoom() {
    if (_options.mouseWheelZoomEnabled) {
      if (_wheelSubscription != null) {
        _wheelSubscription.cancel();
      }
      _options.mouseWheelZoomEnabled = false;
    }
  }

  /// Handle mouse wheel event.
  void _handleMouseWheel(WheelEvent evt) {
    if (!_options.zoomEnabled || _state != State.NONE) {
      return;
    }

      evt.preventDefault();

    num delta = 0;

    if (evt.deltaMode == 0) {
      // Make empirical adjustments for browsers that give deltaY in pixels (deltaMode=0).

      if (evt.wheelDeltaY != 0) {
        // Normalizer for Chrome.
        delta = evt.deltaY / (evt.wheelDeltaY/3).abs();
      } else {
        // Others. Possibly tablets? Use a value just in case.
        delta = evt.deltaY / 120;
      }
    } else {
      // Others should be reasonably normalized by the mousewheel code at
      // the end of the file.
      delta = evt.deltaY;
    }

    final inversedScreenCTM = _svg.getScreenCtm().inverse();
    final relativeMousePoint = svgUtils.getEventPoint(evt,
        _svg).matrixTransform(inversedScreenCTM);
    // Multiplying by neg. 1 so as to make zoom in/out behavior match
    // Google maps behavior.
    final zoom = math.pow(1 + _options.zoomScaleSensitivity, -1 * delta);

    _zoomAtPoint(zoom, relativeMousePoint);
  }

  /// Zoom in at a SVG point.
  ///
  /// If [zoomAbsolute] is true, zoomScale is treated as an absolute value.
  /// Otherwise, zoomScale is treated as a multiplied (e.g. 1.10 would zoom
  /// in 10%);
  void _zoomAtPoint(num zoomScale, Point point, [bool zoomAbsolute=false]) {
    final originalState = _viewport.getOriginalState();

    if (!zoomAbsolute) {
      // Fit zoomScale in set bounds.
      if (_getZoom() * zoomScale < _options.minZoom * originalState.zoom) {
        zoomScale = (_options.minZoom * originalState.zoom) / _getZoom();
      } else if (_getZoom() * zoomScale > _options.maxZoom * originalState.zoom) {
        zoomScale = (_options.maxZoom * originalState.zoom) / _getZoom();
      }
    } else {
      // Fit zoomScale in set bounds.
      zoomScale = math.max(_options.minZoom * originalState.zoom,
          math.min(_options.maxZoom * originalState.zoom, zoomScale));
      // Find relative scale to achieve desired scale.
      zoomScale = zoomScale/_getZoom();
    }

    final oldCTM = _viewport.getCTM();
    final relativePoint = point.matrixTransform(oldCTM.inverse());
    final modifier = _svg.createSvgMatrix().translate(relativePoint.x,
        relativePoint.y).scale(zoomScale).translate(-relativePoint.x, -relativePoint.y);
    final newCTM = oldCTM.multiply(modifier);

    if (newCTM.a != oldCTM.a) {
      _viewport.setCTM(newCTM);
    }
  }

  /// Zoom at center point.
  ///
  /// [absolute] marks zoom scale as relative or absolute
  void _zoom(num scale, bool absolute) {
    final point = svgUtils.getSvgCenterPoint(_svg, _width, _height);
    _zoomAtPoint(scale, point, absolute);
  }

  /// Zoom used by public instance
  ///
  /// [absolute] marks zoom scale as relative or absolute.
  void zoom(num scale, [bool absolute=true]) {
    if (absolute) {
      scale = _computeFromRelativeZoom(scale);
    }

    _zoom(scale, absolute);
  }

  /// Zoom at point used by public instance.
  ///
  /// [absolute] marks zoom scale as relative or absolute.
  zoomAtPoint(num scale, dynamic point, [bool absolute=true]) {
    if (absolute) {
      // Transform zoom into a relative value
      scale = _computeFromRelativeZoom(scale);
    }

    // If not a SVGPoint but has x and y than create a SVGPoint
    if (point is math.Point) {
      point = svgUtils.createSVGPoint(_svg, point.x, point.y);
    } else if (point is Map && point.containsKey('x') && point.containsKey('y')) {
      point = svgUtils.createSVGPoint(_svg, point['x'], point['y']);
    } else {
      throw new Exception('Given point is invalid: $point');
      return;
    }

    _zoomAtPoint(scale, point, absolute);
  }

  /// Get zoom scale.
  num _getZoom() {
    return _viewport.getZoom();
  }

  /// Get zoom scale for public usage
  num getZoom() {
    return _viewport.getRelativeZoom();
  }

  /// Compute actual zoom from public zoom.
  num _computeFromRelativeZoom(num zoom) {
    return zoom * _viewport.getOriginalState().zoom;
  }

  /// Set zoom to initial state.
  resetZoom() {
    var originalState = _viewport.getOriginalState();

    _zoom(originalState.zoom, true);
  }

  /// Set pan to initial state.
  resetPan() {
    final s = _viewport.getOriginalState();
    pan(new math.Point(s.x, s.y));
  }

  /// Set pan and zoom to initial state.
  reset() {
    resetZoom();
    resetPan();
  }

  /// Handle double click event.
  /// See [_handleMouseDown] for alternate detection method.
  _handleDblClick(MouseEvent evt) {
      evt.preventDefault();

    // Check if target was a control button.
    if (_options.controlIconsEnabled) {
      String targetClass = '';
      final t = evt.target;
      if (t is Element) {
        t.attributes['class'];
      }
      if (targetClass.indexOf('svg-pan-zoom-control') > -1) {
        return false;
      }
    }

    num zoomFactor;

    if (evt.shiftKey) {
      // Zoom out when shift key pressed.
      zoomFactor = 1/((1 + this._options.zoomScaleSensitivity) * 2);
    } else {
      zoomFactor = (1 + this._options.zoomScaleSensitivity) * 2;
    }

    var point = svgUtils.getEventPoint(evt, _svg).matrixTransform(_svg.getScreenCtm().inverse());
    _zoomAtPoint(zoomFactor, point);
  }

  Matrix _firstEventCTM;
  Point _stateOrigin;

  /// Handle click event.
  void _handleMouseDown(MouseEvent evt, prevEvt) {
      evt.preventDefault();

    //Utils.mouseAndTouchNormalize(evt, svg);

    // Double click detection; more consistent than ondblclick
    if (_options.dblClickZoomEnabled && utils.isDblClick(evt, prevEvt)){
      _handleDblClick(evt);
    } else {
      // Pan mode
      _state = State.PAN;
      _firstEventCTM = this._viewport.getCTM();
      _stateOrigin = svgUtils.getEventPoint(evt, _svg).matrixTransform(_firstEventCTM.inverse());
    }
  }

  /// Handle mouse move event
  void _handleMouseMove(MouseEvent evt) {
      evt.preventDefault();

    if (_state == State.PAN && _options.panEnabled) {
      // Pan mode
      var point = svgUtils.getEventPoint(evt, _svg).matrixTransform(this._firstEventCTM.inverse());
      var viewportCTM = _firstEventCTM.translate(point.x - _stateOrigin.x, point.y - _stateOrigin.y);

      _viewport.setCTM(viewportCTM);
    }
  }

  /// Handle mouse button release event
  void _handleMouseUp(MouseEvent evt) {
      evt.preventDefault();

    if (_state == State.PAN) {
      // Quit pan mode.
      _state = State.NONE;
    }
  }

  /// Adjust viewport size (only) so it will fit in SVG.
  /// Does not center image.
  void fit() {
    Rectangle viewBox = _viewport.getViewBox();
    var newScale = math.min(_width/(viewBox.width - viewBox.left),
        _height/(viewBox.height - viewBox.top));

    _zoom(newScale, true);
  }

  /// Adjust viewport pan (only) so it will be centered in SVG.
  /// Does not zoom/fit image.
  void center() {
    Rectangle viewBox = _viewport.getViewBox();
    var offsetX = (_width - (viewBox.width + viewBox.left) * _getZoom()) * 0.5;
    var offsetY = (_height - (viewBox.height + viewBox.top) * _getZoom()) * 0.5;

    /*getPublicInstance().*/pan(new math.Point(offsetX, offsetY));
  }

  /// Update content cached BorderBox
  /// Use when viewport contents change
  void updateBBox() {
    _viewport.recacheViewBox();
  }

  /// Pan to a rendered position
  void pan(math.Point point) {
    var viewportCTM = _viewport.getCTM();
    viewportCTM.e = point.x;
    viewportCTM.f = point.y;
    _viewport.setCTM(viewportCTM);
  }

  /// Relatively pan the graph by a specified rendered position vector.
  void panBy(math.Point point) {
    var viewportCTM = _viewport.getCTM();
    viewportCTM.e += point.x;
    viewportCTM.f += point.y;
    _viewport.setCTM(viewportCTM);
  }

  /// Get pan vector.
  math.Point getPan() {
    var state = _viewport.getState();

    return new math.Point(state.x, state.y);
  }

  /// Recalculates cached svg dimensions and controls position.
  void resize() {
    // Get dimensions.
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(_svg);
    _width = boundingClientRectNormalized.width;
    _height = boundingClientRectNormalized.height;

    // Reposition control icons by re-enabling them
    if (_options.controlIconsEnabled) {
      /*getPublicInstance().*/disableControlIcons();
      /*getPublicInstance().*/enableControlIcons();
    }
  }

//  BeforeZoomFn _beforeZoom;
//  OnZoomFn _onZoom;
//  BeforePanFn _beforePan;
//  OnPanFn _onPan;
//  var publicInstance, pi;

  /// Unbind mouse events, free callbacks and destroy public instance
  destroy() {
//    var that = this;

    // Free callbacks
//    _beforeZoom = null;
//    _onZoom = null;
//    _beforePan = null;
//    _onPan = null;

    // Destroy custom event handlers
    if (_options.customEventsHandler != null) {
      _options.customEventsHandler.destroy(_svg, this/*getPublicInstance()*/);
    }

    // Unbind eventListeners
    for (var event in _eventListeners.keys) {
      _svg.removeEventListener(event, _eventListeners[event], false);
    }

    // Unbind wheelListener
    disableMouseWheelZoom();

    // Remove control icons
    /*getPublicInstance().*/disableControlIcons();

    // Reset zoom and pan
    reset();

    // Remove instance from instancesStore
//    instancesStore = instancesStore.where((Map instance) {
//      return instance['svg'] != _svg;
//    }).toList();

    // Delete options and its contents
    /*delete*/ _options = null;

    // Destroy public instance and rewrite getPublicInstance
//    /*delete*/ publicInstance = null;
//    /*delete*/ pi = null;
//    getPublicInstance = () {
//      return null;
//    };
  }

  /// Returns a public instance object
//  getPublicInstance() {
//    // Create cache
//    if (publicInstance == null) {
//      publicInstance = pi = new PublicSvgPanZoom(this);

//      publicInstance = pi = {
//        // Pan
//        enablePan: () {that.options.panEnabled = true; return that.pi;}
//      , disablePan: () {that.options.panEnabled = false; return that.pi;}
//      , isPanEnabled: () {return !!that.options.panEnabled;}
//      , pan: (point) {that.pan(point); return that.pi;}
//      , panBy: (point) {that.panBy(point); return that.pi;}
//      , getPan: () {return that.getPan();}
//        // Pan event
//      , setBeforePan: (fn) {that.options.beforePan = fn == null ? null : Utils.proxy(fn, that.publicInstance); return that.pi;}
//      , setOnPan: (fn) {that.options.onPan = fn == null ? null : Utils.proxy(fn, that.publicInstance); return that.pi;}
//        // Zoom and Control Icons
//      , enableZoom: () {that.options.zoomEnabled = true; return that.pi;}
//      , disableZoom: () {that.options.zoomEnabled = false; return that.pi;}
//      , isZoomEnabled: () {return !!that.options.zoomEnabled;}
//      , enableControlIcons: () {
//          if (!that.options.controlIconsEnabled) {
//            that.options.controlIconsEnabled = true;
//            ControlIcons.enable(that);
//          }
//          return that.pi;
//        }
//      , disableControlIcons: () {
//          if (that.options.controlIconsEnabled) {
//            that.options.controlIconsEnabled = false;
//            ControlIcons.disable(that);
//          }
//          return that.pi;
//        }
//      , isControlIconsEnabled: () {return !!that.options.controlIconsEnabled;}
//        // Double click zoom
//      , enableDblClickZoom: () {that.options.dblClickZoomEnabled = true; return that.pi;}
//      , disableDblClickZoom: () {that.options.dblClickZoomEnabled = false; return that.pi;}
//      , isDblClickZoomEnabled: () {return !!that.options.dblClickZoomEnabled;}
//        // Mouse wheel zoom
//      , enableMouseWheelZoom: () {that.enableMouseWheelZoom(); return that.pi;}
//      , disableMouseWheelZoom: () {that.disableMouseWheelZoom(); return that.pi;}
//      , isMouseWheelZoomEnabled: () {return !!that.options.mouseWheelZoomEnabled;}
//        // Zoom scale and bounds
//      , setZoomScaleSensitivity: (scale) {that.options.zoomScaleSensitivity = scale; return that.pi;}
//      , setMinZoom: (zoom) {that.options.minZoom = zoom; return that.pi;}
//      , setMaxZoom: (zoom) {that.options.maxZoom = zoom; return that.pi;}
//        // Zoom event
//      , setBeforeZoom: (fn) {that.options.beforeZoom = fn == null ? null : Utils.proxy(fn, that.publicInstance); return that.pi;}
//      , setOnZoom: (fn) {that.options.onZoom = fn == null ? null : Utils.proxy(fn, that.publicInstance); return that.pi;}
//        // Zooming
//      , zoom: (scale) {that.publicZoom(scale, true); return that.pi;}
//      , zoomBy: (scale) {that.publicZoom(scale, false); return that.pi;}
//      , zoomAtPoint: (scale, point) {that.publicZoomAtPoint(scale, point, true); return that.pi;}
//      , zoomAtPointBy: (scale, point) {that.publicZoomAtPoint(scale, point, false); return that.pi;}
//      , zoomIn: () {this.zoomBy(1 + that.options.zoomScaleSensitivity); return that.pi;}
//      , zoomOut: () {this.zoomBy(1 / (1 + that.options.zoomScaleSensitivity)); return that.pi;}
//      , getZoom: () {return that.getRelativeZoom();}
//        // Reset
//      , resetZoom: () {that.resetZoom(); return that.pi;}
//      , resetPan: () {that.resetPan(); return that.pi;}
//      , reset: () {that.reset(); return that.pi;}
//        // Fit and Center
//      , fit: () {that.fit(); return that.pi;}
//      , center: () {that.center(); return that.pi;}
//        // Size and Resize
//      , updateBBox: () {that.updateBBox(); return that.pi;}
//      , resize: () {that.resize(); return that.pi;}
//      , getSizes: () {
//          return {
//            width: that.width
//          , height: that.height
//          , realZoom: that.getZoom()
//          , viewBox: that.viewport.getViewBox()
//          };
//        }
//        // Destroy
//      , destroy: () {that.destroy(); return that.pi;}
//      };
//    }

//    return publicInstance;
//  }
//}

//class PublicSvgPanZoom {
//  final SvgPanZoom spz;
//  PublicSvgPanZoom(this.spz);

  /// Pan

  void enablePan() {
    _options.panEnabled = true;
  }

  void disablePan() {
    _options.panEnabled = false;
  }

  bool isPanEnabled() {
    return _options.panEnabled;
  }

  /// Pan event
  void setBeforePan(BeforePanFn fn) {
    _options.beforePan = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
  }

  void setOnPan(OnPanFn fn) {
    _options.onPan = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
  }

  /// Zoom and control icons.

  void enableZoom() {
    _options.zoomEnabled = true;
  }

  void disableZoom() {
    _options.zoomEnabled = false;
  }

  bool isZoomEnabled() {
    return _options.zoomEnabled;
  }

  enableControlIcons() {
    if (!_options.controlIconsEnabled) {
      _options.controlIconsEnabled = true;
      _enableControls(this);
    }
  }

  disableControlIcons() {
    if (_options.controlIconsEnabled) {
      _options.controlIconsEnabled = false;
      _disableControls(this);
    }
  }

  bool isControlIconsEnabled() {
    return _options.controlIconsEnabled;
  }

  /// Double click zoom.

  enableDblClickZoom() {
    _options.dblClickZoomEnabled = true;
  }

  disableDblClickZoom() {
    _options.dblClickZoomEnabled = false;
  }

  isDblClickZoomEnabled() {
    return _options.dblClickZoomEnabled;
  }

  /// Mouse wheel zoom

  bool isMouseWheelZoomEnabled() {
    return _options.mouseWheelZoomEnabled;
  }

  /// Zoom scale and bounds

  void setZoomScaleSensitivity(num scale) {
    _options.zoomScaleSensitivity = scale;
  }

  void setMinZoom(num zoom) {
    _options.minZoom = zoom;
  }

  void setMaxZoom(num zoom) {
    _options.maxZoom = zoom;
  }

  /// Zoom event

  void setBeforeZoom(BeforeZoomFn fn) {
    _options.beforeZoom = fn;
  }

  void setOnZoom(OnZoomFn fn) {
    _options.onZoom = fn;
  }

  /// Zooming

  void zoomBy(num scale) {
    zoom(scale, false);
  }

  void zoomAtPointBy(num scale, math.Point point) {
    zoomAtPoint(scale, point, false);
  }

  void zoomIn() {
    zoomBy(1 + _options.zoomScaleSensitivity);
  }

  void zoomOut() {
    zoomBy(1 / (1 + _options.zoomScaleSensitivity));
  }

  /// Size and Resize

  getSizes() {
    return {
      'width': _width,
      'height': _height,
      'realZoom': _getZoom(),
      'viewBox': _viewport.getViewBox()
    };
  }
}
/*
/// Stores pairs of instances of SvgPanZoom and SVG.
/// Each pair is represented by a map:
///     {'svg': SVGSVGElement, 'instance': SvgPanZoom}
List<Map<SvgSvgElement, SvgPanZoom>> instancesStore = [];

PublicSvgPanZoom svgPanZoom(elementOrSelector, [SvgPanZoomOptions options]) {
  var svg = utils.getSvg(elementOrSelector);

  if (svg == null) {
    return null;
  } else {
    // Look for existent instance
    for(var i = instancesStore.length - 1; i >= 0; i--) {
      if (instancesStore[i]['svg'] == svg) {
        return instancesStore[i]['instance'].getPublicInstance();
      }
    }

    // If instance not found - create one
    instancesStore.add({
      'svg': svg,
      'instance': new SvgPanZoom(svg, options)
    });

    // Return just pushed instance
    return instancesStore[instancesStore.length - 1]['instance'].getPublicInstance();
  }
}
*/
//module.exports = svgPanZoom;
