library svg_pan_zoom.internal.shadow_viewport;

import 'dart:math' show Rectangle;
import 'dart:math' as math;
import 'dart:svg';
import 'svg_utils.dart' as svgUtils;
import 'utils.dart' as utils;

class State {
  final num zoom, x, y;

  State({this.zoom, this.x, this.y});

  factory State.from(State s) {
    return new State(zoom: s.zoom, x: s.x, y: s.y);
  }
}

/// Return false to cancel zooming.
typedef bool BeforeZoomFn(num scale, num ctm);

/// Return false to not modify panning. [Point.x] and [Point.y] may be null
/// to prevent panning in a particular direction.
typedef dynamic BeforePanFn(math.Point oldPan, math.Point newPan);

typedef void OnZoomFn(num scale);
typedef void OnPanFn(math.Point newPan);

class ViewportOptions {
  SvgSvgElement svg;
  num height, width;
  bool fit, center;
  String refreshRate;
  BeforeZoomFn beforeZoom;
  OnZoomFn onZoom;
  BeforePanFn beforePan;
  OnPanFn onPan;
}

class ShadowViewport {
  final GElement _viewport;
  final ViewportOptions _options;
  State _originalState, _activeState;
  Rectangle _viewBox;

  Function _requestAnimationFrame;
  Function _updateCtmCached;

  ShadowViewport(this._viewport, this._options) {
    // State cache
    _originalState = new State(zoom: 1, x: 0, y: 0);
    _activeState = new State(zoom: 1, x: 0, y: 0);

    _updateCtmCached = updateCtm;

    // Create a custom requestAnimationFrame taking in account refreshRate.
    _requestAnimationFrame = utils.createRequestAnimationFrame(_options.refreshRate);

    // ViewBox
    _viewBox = new Rectangle(0, 0, 0, 0);
    cacheViewBox();

    // Process CTM.
    processCtm();
  }

  /// Cache initial viewBox value.
  ///
  /// If no viewBox is defined, then use viewport size/position instead for
  /// viewBox values.
  void cacheViewBox() {
    var svgViewBox = _options.svg.getAttribute('viewBox');

    if (svgViewBox != null) {
      var viewBoxValues = svgViewBox.split(' ').map(double.parse).toList();

      // Cache viewbox x and y offset.
      var x = viewBoxValues[0];
      var y = viewBoxValues[1];
      var width = viewBoxValues[2];
      var height = viewBoxValues[3];
      _viewBox = new Rectangle(x,  y, width, height);

      var zoom = math.min(_options.width / _viewBox.width, _options.height / _viewBox.height);

      // Update active state.
      var sx = (_options.width - _viewBox.width * zoom) / 2;
      var sy = (_options.height - _viewBox.height * zoom) / 2;
      _activeState = new State(zoom: zoom, x: sx, y: sy);

      // Force updating CTM.
      updateCtmOnNextFrame();

      _options.svg.attributes.remove('viewBox');
    } else {
      var bBox = _viewport.getBBox();

      // Cache viewbox sizes.
      var x = bBox.x;
      var y = bBox.y;
      var width = bBox.width;
      var height = bBox.height;
      _viewBox = new Rectangle(x, y, width, height);
    }
  }

  /// Recalculate viewport sizes and update viewBox cache.
  recacheViewBox() {
    var boundingClientRect = _viewport.getBoundingClientRect();
    var viewBoxWidth = boundingClientRect.width / zoom;
    var viewBoxHeight = boundingClientRect.height / zoom;

    // Cache viewbox.
    _viewBox = new Rectangle(0, 0, viewBoxWidth, viewBoxHeight);
  }

  /// Returns a viewbox object. Safe to alter.
  Rectangle get viewBox {
    return new Rectangle(_viewBox.left, _viewBox.top, _viewBox.width,
        _viewBox.height);
  }

  /// Get initial zoom and pan values. Save them into originalState.
  /// Parses viewBox attribute to alter initial sizes
  processCtm() {
    final newCTM = ctm;

    if (_options.fit) {
      var newScale = math.min(_options.width/(_viewBox.width - _viewBox.left),
          _options.height/(_viewBox.height - _viewBox.top));

      newCTM.a = newScale; // x-scale
      newCTM.d = newScale; // y-scale
      newCTM.e = -_viewBox.left * newScale; // x-transform
      newCTM.f = -_viewBox.top * newScale; // y-transform
    }

    if (_options.center) {
      var offsetX = (_options.width - (_viewBox.width + _viewBox.left) * newCTM.a) * 0.5;
      var offsetY = (_options.height - (_viewBox.height + _viewBox.top) * newCTM.a) * 0.5;

      newCTM.e = offsetX;
      newCTM.f = offsetY;
    }

    // Cache initial values. Based on activeState and fix+center opitons
    _originalState = new State(zoom: newCTM.a, x: newCTM.e, y: newCTM.f);

    // Update viewport CTM and cache zoom and pan.
    ctm = newCTM;
  }

  /// Return originalState object. Safe to alter
  State get originalState => new State.from(_originalState);

  /// Return actualState object. Safe to alter.
  State get state => new State.from(_activeState);

  /// Get zoom scale.
  num get zoom => _activeState.zoom;

  /// Get zoom scale for pubilc usage.
  num get relativeZoom => _activeState.zoom / _originalState.zoom;

  /// Compute zoom scale for pubilc usage.
  num computeRelativeZoom(num scale) {
    return scale / _originalState.zoom;
  }

  /// Get pan.
  math.Point get pan {
    return new math.Point(_activeState.x, _activeState.y);
  }

  /// Return cached viewport CTM value that can be safely modified.
  Matrix get ctm {
    Matrix safeCTM = _options.svg.createSvgMatrix();

    // Copy values manually as in FF they are not iterable.
    safeCTM.a = _activeState.zoom;
    safeCTM.b = 0;
    safeCTM.c = 0;
    safeCTM.d = _activeState.zoom;
    safeCTM.e = _activeState.x;
    safeCTM.f = _activeState.y;

    return safeCTM;
  }

  /// Set a new CTM.
  void set ctm(Matrix newCTM) {
    bool willZoom = isZoomDifferent(newCTM);
    bool willPan = isPanDifferent(newCTM);

    if (willZoom || willPan) {
      // Before zoom.
      if (willZoom) {
        // If returns false then cancel zooming.
        var computed = computeRelativeZoom(newCTM.a);
        if (_options.beforeZoom(relativeZoom, computed) == false) {
          newCTM.a = newCTM.d = _activeState.zoom;
          willZoom = false;
        }
      }

      // Before pan
      if (willPan) {
        var p = new math.Point(newCTM.e, newCTM.f);
        var preventPan = _options.beforePan(pan, p);
        // If prevent pan is an object
        bool preventPanX = false;
        bool preventPanY = false;

        // If prevent pan is Boolean false
        if (preventPan == false) {
          // Set x and y same as before
          newCTM.e = pan.x;
          newCTM.f = pan.y;

          preventPanX = preventPanY = true;
        } else if (preventPan is math.Point) {
          // Check for X axes attribute
          if (preventPan.x == null) {
            // Prevent panning on x axes.
            newCTM.e = pan.x;
            preventPanX = true;
          } else {
            // Set a custom pan value
            newCTM.e = preventPan.x;
          }

          // Check for Y axes attribute
          if (preventPan.y == null) {
            // Prevent panning on x axes
            newCTM.f = pan.y;
            preventPanY = true;
          } else  {
            // Set a custom pan value
            newCTM.f = preventPan.y;
          }
        }

        // Update willPan flag
        if (preventPanX && preventPanY) {
          willPan = false;
        }
      }

      // Check again if should zoom or pan
      if (willZoom || willPan) {
        updateCache(newCTM);

        updateCtmOnNextFrame();

        // After callbacks
        if (willZoom) {
          _options.onZoom(relativeZoom);
        }
        if (willPan) {
          _options.onPan(pan);
        }
      }
    }
  }

  bool isZoomDifferent(Matrix newCTM) {
    return _activeState.zoom != newCTM.a;
  }

  bool isPanDifferent(Matrix newCTM) {
    return _activeState.x != newCTM.e || _activeState.y != newCTM.f;
  }

  /// Update cached CTM and active state.
  void updateCache(Matrix newCTM) {
    _activeState = new State(zoom: newCTM.a, x: newCTM.e, y: newCTM.f);
  }

  var _pendingUpdate = false;

  /// Place a request to update CTM on next Frame.
  updateCtmOnNextFrame() {
    if (!_pendingUpdate) {
      // Lock
      _pendingUpdate = true;

      // Throttle next update.
      _requestAnimationFrame(/*window, */_updateCtmCached);
    }
  }

  SvgElement _defs;

  /// Update viewport CTM with cached CTM.
  updateCtm(_) {
    // Updates SVG element.
    svgUtils.setCTM(_viewport, ctm, _defs);

    // Free the lock.
    _pendingUpdate = false;
  }
}
