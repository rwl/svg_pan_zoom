// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.internal;

import 'dart:math' as math;
import 'dart:html' hide Point;
import 'dart:async';
import 'dart:svg' hide ImageElement;
import 'shadow_viewport.dart';
import 'svg_utils.dart' as svgUtils;
import 'utils.dart' as utils;

part 'control_icons.dart';

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

  /// Enable or disable panning (default enabled).
  bool panEnabled = true;

  /// Enable or disable zooming (default enabled).
  bool zoomEnabled = true;

  /// Enable or disable zooming by double clicking (default enabled).
  bool dblClickZoomEnabled = true;

  /// Zoom sensitivity.
  num zoomSensitivity = 0.2;

  /// Minimum Zoom level
  num minZoom = 0.5;

  /// Maximum Zoom level
  int maxZoom = 10;

  bool _controlIconsEnabled = false;

  BeforeZoomFn beforeZoom;
  OnZoomFn onZoom;
  BeforePanFn beforePan;
  OnPanFn onPan;

  CustomEventsHandler customEventsHandler = null;

  var _defs;
  State _state;
  num _width, _height;
  ShadowViewport _viewport;

  Map<String, EventListener> _eventListeners;
  GElement _controlIcons;

  factory SvgPanZoom.selector(String selector,
      {viewportSelector: '.svg-pan-zoom_viewport', bool fit: true,
        bool center: true, refreshRate: 'auto'}) {
    final svg = document.querySelector(selector);
    if (svg is! SvgSvgElement) {
      throw new ArgumentError.value(selector, 'selector');
    }
    return new SvgPanZoom(svg, viewportSelector: viewportSelector, fit: fit,
        center: center, refreshRate: refreshRate);
  }

  /// [viewportSelector] can be querySelector string or SVGElement. Enable
  /// or disable viewport [fit] in SVG. Enable or disable viewport
  /// [center]ing in SVG. Maximum number of frames per second (altering
  /// SVG's viewport)
  SvgPanZoom(this._svg, {viewportSelector: '.svg-pan-zoom_viewport',
      bool fit: true, bool center: true, refreshRate: 'auto'}) {
    _defs = _svg.querySelector('defs');

    // Add default attributes to SVG
    svgUtils.setupSvgAttributes(_svg);

    // Set default state
    _state = State.NONE;

    // Get dimensions
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(_svg);
    _width = boundingClientRectNormalized.width;
    _height = boundingClientRectNormalized.height;

    // Init shadow viewport
    final viewportElem = svgUtils.getOrCreateViewport(_svg, viewportSelector);
    _viewport = new ShadowViewport(viewportElem, new ViewportOptions()
      ..svg = _svg
      ..width = _width
      ..height = _height
      ..fit = fit
      ..center = center
      ..refreshRate = refreshRate
      // Put callbacks into functions as they can change through time
      ..beforeZoom = (oldScale, newScale) {
        if (_viewport != null && beforeZoom != null) {
          return beforeZoom(oldScale, newScale);
        }
      }
      ..onZoom = (scale) {
        if (_viewport != null && onZoom != null) {
          return onZoom(scale);
        }
      }
      ..beforePan = (oldPoint, newPoint) {
        if (_viewport != null && beforePan != null) {
          return beforePan(oldPoint, newPoint);
        }
      }
      ..onPan = (point) {
        if (_viewport != null && onPan != null) {
          return onPan(point);
        }
      }
    );

    if (_controlIconsEnabled) {
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
    if (customEventsHandler != null) {
      customEventsHandler.init(_svg, this);

      // Custom event handler may halt builtin listeners.
      var haltEventListeners = customEventsHandler.haltEventListeners;
      if (haltEventListeners != null && !haltEventListeners.isEmpty) {
        for (var i = haltEventListeners.length - 1; i >= 0; i--) {
          if (_eventListeners.containsKey(haltEventListeners[i])) {
            _eventListeners.remove(haltEventListeners[i]);
          }
        }
      }
    }

    // Bind eventListeners.
    for (var event in _eventListeners.keys) {
      _svg.addEventListener(event, _eventListeners[event], false);
    }

    // Zoom using mouse wheel.
    if (_mouseWheelZoomEnabled) {
      // Set to false as enable will set it back to true.
      _mouseWheelZoomEnabled = false;
      _enableMouseWheelZoom();
    }
  }

  /// Enable or disable zooming by mouse wheel (default enabled).
  void set mouseWheelZoomEnabled(bool enabled) {
    enabled ? _enableMouseWheelZoom() : _disableMouseWheelZoom();
  }

  bool get mouseWheelZoomEnabled => _mouseWheelZoomEnabled;

  bool _mouseWheelZoomEnabled = true;

  Function _wheelListener;
  StreamSubscription<WheelEvent> _wheelSubscription;

  void _enableMouseWheelZoom() {
    if (!_mouseWheelZoomEnabled) {
      // Mouse wheel listener
      _wheelListener = (evt) {
        return _handleMouseWheel(evt);
      };

      // Bind wheelListener
      _wheelSubscription = _svg.onMouseWheel.listen(_wheelListener);

      _mouseWheelZoomEnabled = true;
    }
  }

  void _disableMouseWheelZoom() {
    if (_mouseWheelZoomEnabled) {
      if (_wheelSubscription != null) {
        _wheelSubscription.cancel();
      }
      _mouseWheelZoomEnabled = false;
    }
  }

  void _handleMouseWheel(WheelEvent evt) {
    if (!zoomEnabled || _state != State.NONE) {
      return;
    }

    evt.preventDefault();

    num delta = 0;

    if (evt.deltaMode == 0) {
      // Make empirical adjustments for browsers that give deltaY in
      // pixels (deltaMode=0).

      if (evt.wheelDeltaY != 0) {
        // Normalizer for Chrome.
        delta = evt.deltaY / (evt.wheelDeltaY/3).abs();
      } else {
        // Others. Possibly tablets? Use a value just in case.
        delta = evt.deltaY / 120;
      }
    } else {
      // Others should be reasonably normalized by the mousewheel code
      // at the end of the file.
      delta = evt.deltaY;
    }

    final inversedScreenCTM = _svg.getScreenCtm().inverse();
    final relativeMousePoint = svgUtils.getEventPoint(evt,
        _svg).matrixTransform(inversedScreenCTM);
    // Multiplying by neg. 1 so as to make zoom in/out behavior match
    // Google maps behavior.
    final zoom = math.pow(1 + zoomSensitivity, -1 * delta);

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
      if (_getZoom() * zoomScale < minZoom * originalState.zoom) {
        zoomScale = (minZoom * originalState.zoom) / _getZoom();
      } else if (_getZoom() * zoomScale > maxZoom * originalState.zoom) {
        zoomScale = (maxZoom * originalState.zoom) / _getZoom();
      }
    } else {
      // Fit zoomScale in set bounds.
      zoomScale = math.max(minZoom * originalState.zoom,
          math.min(maxZoom * originalState.zoom, zoomScale));
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

  void _zoom(num scale, bool absolute) {
    final point = svgUtils.getSvgCenterPoint(_svg, _width, _height);
    _zoomAtPoint(scale, point, absolute);
  }

  /// Zoom at center point.
  ///
  /// [absolute] marks zoom scale as relative or absolute
  void set zoom(num scale) => _centerZoom(scale);

  void _centerZoom(num scale, [bool absolute=true]) {
    if (absolute) {
      scale = _computeFromRelativeZoom(scale);
    }

    _zoom(scale, absolute);
  }

  /// Zoom by [scale] at [point].
  ///
  /// [absolute] marks zoom scale as relative or absolute.
  zoomAtPoint(num scale, math.Point point, [bool absolute=true]) {
    if (absolute) {
      // Transform zoom into a relative value
      scale = _computeFromRelativeZoom(scale);
    }

    var p = svgUtils.createSVGPoint(_svg, point.x, point.y);

    _zoomAtPoint(scale, p, absolute);
  }

  /// Get zoom scale.
  num _getZoom() {
    return _viewport.getZoom();
  }

  /// Get zoom scale.
  num get zoom => _viewport.getRelativeZoom();

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
    panTo(s.x, s.y);
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
    if (_controlIconsEnabled) {
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
      zoomFactor = 1/((1 + zoomSensitivity) * 2);
    } else {
      zoomFactor = (1 + zoomSensitivity) * 2;
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
    if (dblClickZoomEnabled && utils.isDblClick(evt, prevEvt)){
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

    if (_state == State.PAN && panEnabled) {
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

    panTo(offsetX, offsetY);
  }

  /// Update content cached BorderBox
  /// Use when viewport contents change
  void updateBBox() {
    _viewport.recacheViewBox();
  }

  void panTo(num x, num y) => panToPoint(new math.Point(x, y));

  /// Pan to a rendered position.
  void panToPoint(math.Point point) {
    var viewportCTM = _viewport.getCTM();
    viewportCTM.e = point.x;
    viewportCTM.f = point.y;
    _viewport.setCTM(viewportCTM);
  }

  /// Relatively pan the graph by a specified rendered position vector.
  void panBy(num x, num y) {
    var viewportCTM = _viewport.getCTM();
    viewportCTM.e += x;
    viewportCTM.f += y;
    _viewport.setCTM(viewportCTM);
  }

  /// Get pan vector.
  math.Point get pan {
    var state = _viewport.getState();

    return new math.Point(state.x, state.y);
  }

  /// Recalculates cached svg dimensions and controls position.
  void resize() {
    // Get dimensions.
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(_svg);
    _width = boundingClientRectNormalized.width;
    _height = boundingClientRectNormalized.height;

    // Reposition control icons by re-enabling them.
    if (_controlIconsEnabled) {
      controlsEnabled = false;
      controlsEnabled = true;
    }
  }


  /// Unbind mouse events and free callbacks.
  destroy() {
    // Free callbacks
    beforeZoom = null;
    onZoom = null;
    beforePan = null;
    onPan = null;

    // Destroy custom event handlers
    if (customEventsHandler != null) {
      customEventsHandler.destroy(_svg, this);
    }

    // Unbind eventListeners
    for (var event in _eventListeners.keys) {
      _svg.removeEventListener(event, _eventListeners[event], false);
    }

    // Unbind wheelListener
    _disableMouseWheelZoom();

    // Remove control icons
    controlsEnabled = false;

    // Reset zoom and pan
    reset();
  }

  /// Insert icons to give user an option in addition to mouse events to
  /// control pan/zoom (default disabled).
  void set controlsEnabled(bool enabled) {
    enabled ? _enableControlIcons() : _disableControlIcons();
  }

  bool get controlsEnabled => _controlIconsEnabled;

  _enableControlIcons() {
    if (!_controlIconsEnabled) {
      _controlIconsEnabled = true;
      _enableControls(this);
    }
  }

  _disableControlIcons() {
    if (_controlIconsEnabled) {
      _controlIconsEnabled = false;
      _disableControls(this);
    }
  }

  /// Zooming

  void zoomBy(num scale) {
    _centerZoom(scale, false);
  }

  void zoomAtPointBy(num scale, math.Point point) {
    zoomAtPoint(scale, point, false);
  }

  void zoomIn() {
    zoomBy(1 + zoomSensitivity);
  }

  void zoomOut() {
    zoomBy(1 / (1 + zoomSensitivity));
  }

  /// Size and Resize

  num get width => _width;
  num get height => _height;
  num get realZoom => _getZoom();
  Rectangle get viewBox => _viewport.getViewBox();
}
