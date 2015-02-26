library svg_pan_zoom.internal.shadow_viewport;

//var SvgUtils = require('./svg-utilities')
//  , Utils = require('./utilities')
//  ;

//var ShadowViewport = function(viewport, options){
//  this.init(viewport, options)
//}

import 'dart:math' show Rectangle;
import 'dart:math' as math;
import 'dart:svg';
//import 'dart:html' show window;
import 'svg_utils.dart' as svgUtils;
import 'utils.dart' as utils;

class State {
  final num zoom, x, y;
  State({this.zoom, this.x, this.y});
  factory State.from(State s) {
    return new State(zoom: s.zoom, x: s.x, y: s.y);
  }
}

typedef BeforeZoomFn(num scale, num ctm);
typedef OnZoomFn(num scale);
typedef BeforePanFn(math.Point oldPan, math.Point newPan);
typedef OnPanFn(math.Point newPan);

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
  GElement viewport;
  ViewportOptions options;
  State originalState, activeState;
  Rectangle viewBox;

  Function requestAnimationFrame;
  Function updateCTMCached;

  ShadowViewport(this.viewport, this.options) {
    // DOM Elements
//    this.viewport = viewport;
//    this.options = options;

    // State cache
    originalState = new State(zoom: 1, x: 0, y: 0);
    activeState = new State(zoom: 1, x: 0, y: 0);

    updateCTMCached = updateCTM;//Utils.proxy(this.updateCTM, this);

    // Create a custom requestAnimationFrame taking in account refreshRate
    requestAnimationFrame = utils.createRequestAnimationFrame(options.refreshRate);

    // ViewBox
    viewBox = new Rectangle(0, 0, 0, 0);
    cacheViewBox();

    // Process CTM
    processCTM();
  }

  /// Cache initial viewBox value
  /// If no viewBox is defined, then use viewport size/position instead for
  /// viewBox values.
  void cacheViewBox() {
    var svgViewBox = this.options.svg.getAttribute('viewBox');

    if (svgViewBox != null) {
      var viewBoxValues = svgViewBox.split(' ').map(double.parse).toList();

      // Cache viewbox x and y offset
      var /*this.viewBox.*/x = viewBoxValues[0];
      var /*this.viewBox.*/y = viewBoxValues[1];
      var /*this.viewBox.*/width = viewBoxValues[2];
      var /*this.viewBox.*/height = viewBoxValues[3];
      viewBox = new Rectangle(x,  y, width, height);

      var zoom = math.min(options.width / viewBox.width, options.height / viewBox.height);

      // Update active state
      //this.activeState.zoom = zoom;
      var/*this.activeState.*/ sx = (options.width - viewBox.width * zoom) / 2;
      var/*this.activeState.*/ sy = (options.height - viewBox.height * zoom) / 2;
      activeState = new State(zoom: zoom, x: sx, y: sy);

      // Force updating CTM
      updateCTMOnNextFrame();

      options.svg.attributes.remove('viewBox');
    } else {
      var bBox = this.viewport.getBBox();

      // Cache viewbox sizes
      var/*this.viewBox.*/ x = bBox.x;
      var/*this.viewBox.*/ y = bBox.y;
      var/*this.viewBox.*/ width = bBox.width;
      var/*this.viewBox.*/ height = bBox.height;
      viewBox = new Rectangle(x, y, width, height);
    }
  }

  /// Recalculate viewport sizes and update viewBox cache.
  recacheViewBox() {
    var boundingClientRect = viewport.getBoundingClientRect();
    var viewBoxWidth = boundingClientRect.width / getZoom();
    var viewBoxHeight = boundingClientRect.height / getZoom();

    // Cache viewbox
    var/*this.viewBox.*/ x = 0;
    var/*this.viewBox.*/ y = 0;
    var/*this.viewBox.*/ width = viewBoxWidth;
    var/*this.viewBox.*/ height = viewBoxHeight;
    viewBox = new Rectangle(x, y, width, height);
  }

  /// Returns a viewbox object. Safe to alter.
  Rectangle getViewBox() {
    //return Utils.extend({}, this.viewBox);
    return new Rectangle(viewBox.left, viewBox.top, viewBox.width, viewBox.height);
  }

  /// Get initial zoom and pan values. Save them into originalState.
  /// Parses viewBox attribute to alter initial sizes
  processCTM() {
    final newCTM = getCTM();

    if (options.fit) {
      var newScale = math.min(options.width/(viewBox.width - viewBox.left), options.height/(viewBox.height - viewBox.top));

      newCTM.a = newScale; //x-scale
      newCTM.d = newScale; //y-scale
      newCTM.e = -viewBox.left * newScale; //x-transform
      newCTM.f = -viewBox.top * newScale; //y-transform
    }

    if (options.center) {
      var offsetX = (options.width - (viewBox.width + viewBox.left) * newCTM.a) * 0.5;
      var offsetY = (options.height - (viewBox.height + viewBox.top) * newCTM.a) * 0.5;

      newCTM.e = offsetX;
      newCTM.f = offsetY;
    }

    // Cache initial values. Based on activeState and fix+center opitons
    var/*this.originalState.*/ zoom = newCTM.a;
    var/*this.originalState.*/ x = newCTM.e;
    var/*this.originalState.*/ y = newCTM.f;
    originalState = new State(zoom: zoom, x: x, y: y);

    // Update viewport CTM and cache zoom and pan.
    setCTM(newCTM);
  }

  /// Return originalState object. Safe to alter
  State getOriginalState() {
    //return Utils.extend({}, originalState);
    return new State.from(originalState);
  }

  /// Return actualState object. Safe to alter.
  State getState() {
//    return Utils.extend({}, this.activeState);
    return new State.from(activeState);
  }

  /// Get zoom scale.
  num getZoom() {
    return activeState.zoom;
  }

  /// Get zoom scale for pubilc usage.
  num getRelativeZoom() {
    return activeState.zoom / originalState.zoom;
  }

  /// Compute zoom scale for pubilc usage.
  computeRelativeZoom(num scale) {
    return scale / originalState.zoom;
  }

  /// Get pan.
  math.Point getPan() {
    return new math.Point(activeState.x, activeState.y);
  }

  /// Return cached viewport CTM value that can be safely modified.
  Matrix getCTM() {
    Matrix safeCTM = options.svg.createSvgMatrix();

    // Copy values manually as in FF they are not itterable
    safeCTM.a = this.activeState.zoom;
    safeCTM.b = 0;
    safeCTM.c = 0;
    safeCTM.d = this.activeState.zoom;
    safeCTM.e = this.activeState.x;
    safeCTM.f = this.activeState.y;

    return safeCTM;
  }

  /// Set a new CTM.
  setCTM(Matrix newCTM) {
    bool willZoom = this.isZoomDifferent(newCTM);
    bool willPan = this.isPanDifferent(newCTM);

    if (willZoom || willPan) {
      // Before zoom
      if (willZoom) {
        // If returns false then cancel zooming
        if (options.beforeZoom(getRelativeZoom(), computeRelativeZoom(newCTM.a)) == false) {
          newCTM.a = newCTM.d = activeState.zoom;
          willZoom = false;
        }
      }

      // Before pan
      if (willPan) {
        var preventPan = options.beforePan(getPan(), new math.Point(newCTM.e, newCTM.f));
        // If prevent pan is an object
        bool preventPanX = false;
        bool preventPanY = false;

        // If prevent pan is Boolean false
        if (preventPan == false) {
          // Set x and y same as before
          newCTM.e = getPan().x;
          newCTM.f = getPan().y;

          preventPanX = preventPanY = true;
        } else if (preventPan is Map) {
          // Check for X axes attribute
          if (preventPan['x'] == false) {
            // Prevent panning on x axes
            newCTM.e = getPan().x;
            preventPanX = true;
          } else if (preventPan['x'] is num) {
            // Set a custom pan value
            newCTM.e = preventPan['x'];
          }

          // Check for Y axes attribute
          if (preventPan['y'] == false) {
            // Prevent panning on x axes
            newCTM.f = getPan().y;
            preventPanY = true;
          } else if (preventPan['y'] is num) {
            // Set a custom pan value
            newCTM.f = preventPan['y'];
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

        updateCTMOnNextFrame();

        // After callbacks
        if (willZoom) {
          options.onZoom(getRelativeZoom());
        }
        if (willPan) {
          options.onPan(getPan());
        }
      }
    }
  }

  bool isZoomDifferent(Matrix newCTM) {
    return activeState.zoom != newCTM.a;
  }

  bool isPanDifferent(Matrix newCTM) {
    return activeState.x != newCTM.e || activeState.y != newCTM.f;
  }


  /// Update cached CTM and active state
  void updateCache(Matrix newCTM) {
    var/*this.activeState.*/ zoom = newCTM.a;
    var/*this.activeState.*/ x = newCTM.e;
    var/*this.activeState.*/ y = newCTM.f;
    activeState = new State(zoom: zoom, x: x, y: y);
  }

  var pendingUpdate = false;

  /// Place a request to update CTM on next Frame.
  updateCTMOnNextFrame() {
    if (!pendingUpdate) {
      // Lock
      pendingUpdate = true;

      // Throttle next update
      requestAnimationFrame(/*window, */updateCTMCached);
    }
  }

  SvgElement defs;

  /// Update viewport CTM with cached CTM.
  updateCTM(_) {
    // Updates SVG element
    svgUtils.setCTM(this.viewport, getCTM(), defs);

    // Free the lock
    pendingUpdate = false;
  }
}

//module.exports = function(viewport, options){
//  return new ShadowViewport(viewport, options)
//}