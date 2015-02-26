// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.internal;

import 'dart:math' as math;
import 'dart:html' hide Point;
import 'dart:async';
import 'dart:svg' hide ImageElement;
import 'shadow_viewport.dart';
import 'svg_utils.dart' as svgUtils;
import 'control_icons.dart' as controls;
import 'utils.dart' as utils;

//var Wheel = require('./uniwheel')
//, ControlIcons = require('./control-icons')
//, Utils = require('./utilities')
//, SvgUtils = require('./svg-utilities')
//, ShadowViewport = require('./shadow-viewport')

//var SvgPanZoom = function(svg, options) {
//  this.init(svg, options)
//}

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

  var beforeZoom = null;
  var onZoom = null;
  var beforePan = null;
  var onPan = null;
  var customEventsHandler = null;
}

enum State {
  NONE, PAN
}

class SvgPanZoom {
  final SvgSvgElement svg;
  var defs;
  SvgPanZoomOptions options;
  State state;
  num width, height;
  ShadowViewport viewport;

  Map eventListeners;
  GElement controlIcons;

  SvgPanZoom(this.svg, [this.options]) {
//    var that = this

//    this.svg = svg;
    defs = svg.querySelector('defs');

    // Add default attributes to SVG
    svgUtils.setupSvgAttributes(svg);

    // Set options
//    this.options = Utils.extend(Utils.extend({}, optionsDefaults), options);
    if (options == null) {
      options = new SvgPanZoomOptions();
    }

    // Set default state
    state = State.NONE;

    // Get dimensions
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(svg);
    width = boundingClientRectNormalized.width;
    height = boundingClientRectNormalized.height;

    // Init shadow viewport
    viewport = new ShadowViewport(svgUtils.getOrCreateViewport(svg, options.viewportSelector), new ViewportOptions()
      ..svg = svg
      ..width = width
      ..height = height
      ..fit = options.fit
      ..center = options.center
      ..refreshRate = options.refreshRate
      // Put callbacks into functions as they can change through time
      ..beforeZoom = (oldScale, newScale) {
        if (viewport != null && options.beforeZoom != null) {
          return options.beforeZoom(oldScale, newScale);
        }
      }
      ..onZoom = (scale) {
        if (viewport != null && options.onZoom != null) {
          return options.onZoom(scale);
        }
      }
      ..beforePan = (oldPoint, newPoint) {
        if (viewport != null && options.beforePan != null) {
          return options.beforePan(oldPoint, newPoint);
        }
      }
      ..onPan = (point) {
        if (viewport != null && options.onPan != null) {
          return options.onPan(point);
        }
      }
    );

    // Wrap callbacks into public API context
    var publicInstance = getPublicInstance();
    publicInstance.setBeforeZoom(options.beforeZoom);
    publicInstance.setOnZoom(options.onZoom);
    publicInstance.setBeforePan(options.beforePan);
    publicInstance.setOnPan(options.onPan);

    if (this.options.controlIconsEnabled) {
      controls.enable(this);
    }

    // Init events handlers
    setupHandlers();
  }

  /// Register event handlers
  void setupHandlers() {
//    var that = this
    var prevEvt = null; // use for touchstart event to detect double tap

    eventListeners = {
      // Mouse down group
      'mousedown': (evt) {
        return handleMouseDown(evt, null);
      },
      'touchstart': (evt) {
        /*var result =*/ handleMouseDown(evt, prevEvt);
        prevEvt = evt;
        return;// result;
      },

      // Mouse up group
      'mouseup': (evt) {
        return handleMouseUp(evt);
      },
      'touchend': (evt) {
        return handleMouseUp(evt);
      },

      // Mouse move group
      'mousemove': (evt) {
        return handleMouseMove(evt);
      },
      'touchmove': (evt) {
        return handleMouseMove(evt);
      },

      // Mouse leave group
      'mouseleave': (evt) {
        return handleMouseUp(evt);
      },
      'touchleave': (evt) {
        return handleMouseUp(evt);
      },
      'touchcancel': (evt) {
        return handleMouseUp(evt);
      }
    };

    // Init custom events handler if available
    if (options.customEventsHandler != null) {
      options.customEventsHandler.init(
        svgElement: svg,
        instance: getPublicInstance()
      );

      // Custom event handler may halt builtin listeners
      var haltEventListeners = options.customEventsHandler.haltEventListeners;
      if (haltEventListeners && haltEventListeners.length) {
        for (var i = haltEventListeners.length - 1; i >= 0; i--) {
          if (eventListeners.containsKey(haltEventListeners[i])) {
            eventListeners.remove(haltEventListeners[i]);
          }
        }
      }
    }

    // Bind eventListeners
    for (var event in eventListeners.keys) {
      svg.addEventListener(event, eventListeners[event], false);
    }

    // Zoom using mouse wheel
    if (options.mouseWheelZoomEnabled) {
      options.mouseWheelZoomEnabled = false; // set to false as enable will set it back to true
      enableMouseWheelZoom();
    }
  }

  Function wheelListener;
  StreamSubscription<WheelEvent> wheelSubscription;

  /// Enable ability to zoom using mouse wheel
  void enableMouseWheelZoom() {
    if (!options.mouseWheelZoomEnabled) {
      // Mouse wheel listener
      wheelListener = (evt) {
        return handleMouseWheel(evt);
      };

      // Bind wheelListener
//      Wheel.on(svg, wheelListener, false);
      wheelSubscription = svg.onMouseWheel.listen(wheelListener);

      options.mouseWheelZoomEnabled = true;
    }
  }

  /// Disable ability to zoom using mouse wheel.
  void disableMouseWheelZoom() {
    if (options.mouseWheelZoomEnabled) {
      if (wheelSubscription != null) {
        wheelSubscription.cancel();
      }
//      Wheel.off(this.svg, this.wheelListener, false);
      options.mouseWheelZoomEnabled = false;
    }
  }

  /// Handle mouse wheel event
  void handleMouseWheel(WheelEvent evt) {
    if (!options.zoomEnabled || state != State.NONE) {
      return;
    }

//    if (evt.preventDefault) {
      evt.preventDefault();
//    } else {
//      evt.returnValue = false;
//    }

    num delta = 0;

    if (/*evt.contains('deltaMode') &&*/ evt.deltaMode == 0) {
      // Make empirical adjustments for browsers that give deltaY in pixels (deltaMode=0)

      if (evt.wheelDeltaY != 0/*wheelDelta*/) {
        // Normalizer for Chrome
        delta = evt.deltaY / (evt.wheelDeltaY/3).abs();
      } else {
        // Others. Possibly tablets? Use a value just in case
        delta = evt.deltaY / 120;
      }
    } /*else if (evt.contains('mozPressure')) {
      // Normalizer for newer Firefox
      // NOTE: May need to change detection at some point if mozPressure disappears.
      delta = evt.deltaY / 3;
    } */else {
      // Others should be reasonably normalized by the mousewheel code at the end of the file.
      delta = evt.deltaY;
    }

    final inversedScreenCTM = svg.getScreenCtm().inverse();
    final relativeMousePoint = svgUtils.getEventPoint(evt, svg).matrixTransform(inversedScreenCTM);
    // multiplying by neg. 1 so as to make zoom in/out behavior match Google maps behavior
    final zoom = math.pow(1 + this.options.zoomScaleSensitivity, (-1) * delta);

    zoomAtPoint(zoom, relativeMousePoint);
  }

  /// Zoom in at a SVG point.
  ///
  /// If [zoomAbsolute] is true, zoomScale is treated as an absolute value.
  /// Otherwise, zoomScale is treated as a multiplied (e.g. 1.10 would zoom
  /// in 10%);
  void zoomAtPoint(num zoomScale, Point point, [bool zoomAbsolute=false]) {
    final originalState = viewport.getOriginalState();

    if (!zoomAbsolute) {
      // Fit zoomScale in set bounds.
      if (getZoom() * zoomScale < options.minZoom * originalState.zoom) {
        zoomScale = (options.minZoom * originalState.zoom) / getZoom();
      } else if (getZoom() * zoomScale > options.maxZoom * originalState.zoom) {
        zoomScale = (options.maxZoom * originalState.zoom) / getZoom();
      }
    } else {
      // Fit zoomScale in set bounds.
      zoomScale = math.max(options.minZoom * originalState.zoom, math.min(options.maxZoom * originalState.zoom, zoomScale));
      // Find relative scale to achieve desired scale.
      zoomScale = zoomScale/getZoom();
    }

    final oldCTM = viewport.getCTM();
    final relativePoint = point.matrixTransform(oldCTM.inverse());
    final modifier = svg.createSvgMatrix().translate(relativePoint.x, relativePoint.y).scale(zoomScale).translate(-relativePoint.x, -relativePoint.y);
    final newCTM = oldCTM.multiply(modifier);

    if (newCTM.a != oldCTM.a) {
      viewport.setCTM(newCTM);
    }
  }

  /// Zoom at center point.
  ///
  /// [absolute] marks zoom scale as relative or absolute
  void zoom(num scale, bool absolute) {
    zoomAtPoint(scale, svgUtils.getSvgCenterPoint(svg, width, height), absolute);
  }

  /// Zoom used by public instance
  ///
  /// [absolute] marks zoom scale as relative or absolute.
  void publicZoom(num scale, bool absolute) {
    if (absolute) {
      scale = computeFromRelativeZoom(scale);
    }

    zoom(scale, absolute);
  }

  /// Zoom at point used by public instance.
  ///
  /// [absolute] marks zoom scale as relative or absolute.
  publicZoomAtPoint(num scale, dynamic point, bool absolute) {
    if (absolute) {
      // Transform zoom into a relative value
      scale = computeFromRelativeZoom(scale);
    }

    // If not a SVGPoint but has x and y than create a SVGPoint
    if (point is! Point && point.contains('x') && point.contains('y')) {
      point = svgUtils.createSVGPoint(svg, point['x'], point['y']);
    } else {
      throw new Exception('Given point is invalid');
      return;
    }

    zoomAtPoint(scale, point, absolute);
  }

  /// Get zoom scale.
  num getZoom() {
    return viewport.getZoom();
  }

  /// Get zoom scale for public usage
  num getRelativeZoom() {
    return viewport.getRelativeZoom();
  }

  /// Compute actual zoom from public zoom.
  num computeFromRelativeZoom(num zoom) {
    return zoom * viewport.getOriginalState().zoom;
  }

  /// Set zoom to initial state.
  resetZoom() {
    var originalState = viewport.getOriginalState();

    zoom(originalState.zoom, true);
  }

  /// Set pan to initial state.
  resetPan() {
    final s = viewport.getOriginalState();
    pan(new math.Point(s.x, s.y));
  }

  /// Set pan and zoom to initial state.
  reset() {
    resetZoom();
    resetPan();
  }

  /// Handle double click event.
  /// See [handleMouseDown] for alternate detection method.
  handleDblClick(MouseEvent evt) {
//    if (evt.preventDefault) {
      evt.preventDefault();
//    } else {
//      evt.returnValue = false;
//    }

    // Check if target was a control button
    if (options.controlIconsEnabled) {
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
      zoomFactor = 1/((1 + this.options.zoomScaleSensitivity) * 2);
    } else {
      zoomFactor = (1 + this.options.zoomScaleSensitivity) * 2;
    }

    var point = svgUtils.getEventPoint(evt, svg).matrixTransform(svg.getScreenCtm().inverse());
    zoomAtPoint(zoomFactor, point);
  }

  Matrix firstEventCTM;
  Point stateOrigin;

  /// Handle click event.
  void handleMouseDown(MouseEvent evt, prevEvt) {
//    if (evt.preventDefault) {
      evt.preventDefault();
//    } else {
//      evt.returnValue = false;
//    }

    //Utils.mouseAndTouchNormalize(evt, svg);

    // Double click detection; more consistent than ondblclick
    if (options.dblClickZoomEnabled && utils.isDblClick(evt, prevEvt)){
      handleDblClick(evt);
    } else {
      // Pan mode
      state = State.PAN;
      firstEventCTM = this.viewport.getCTM();
      stateOrigin = svgUtils.getEventPoint(evt, svg).matrixTransform(firstEventCTM.inverse());
    }
  }

  /// Handle mouse move event
  void handleMouseMove(MouseEvent evt) {
//    if (evt.preventDefault) {
      evt.preventDefault();
//    } else {
//      evt.returnValue = false;
//    }

    if (state == State.PAN && options.panEnabled) {
      // Pan mode
      var point = svgUtils.getEventPoint(evt, svg).matrixTransform(this.firstEventCTM.inverse());
      var viewportCTM = firstEventCTM.translate(point.x - stateOrigin.x, point.y - stateOrigin.y);

      viewport.setCTM(viewportCTM);
    }
  }

  /// Handle mouse button release event
  void handleMouseUp(MouseEvent evt) {
//    if (evt.preventDefault) {
      evt.preventDefault();
//    } else {
//      evt.returnValue = false;
//    }

    if (state == State.PAN) {
      // Quit pan mode
      state = State.NONE;
    }
  }

  /// Adjust viewport size (only) so it will fit in SVG.
  /// Does not center image.
  void fit() {
    var viewBox = this.viewport.getViewBox();
    var newScale = math.min(width/(viewBox.width - viewBox.x), height/(viewBox.height - viewBox.y));

    zoom(newScale, true);
  }

  /// Adjust viewport pan (only) so it will be centered in SVG.
  /// Does not zoom/fit image.
  void center() {
    var viewBox = viewport.getViewBox();
    var offsetX = (width - (viewBox.width + viewBox.x) * getZoom()) * 0.5;
    var offsetY = (height - (viewBox.height + viewBox.y) * getZoom()) * 0.5;

    getPublicInstance().pan(new math.Point(offsetX, offsetY));
  }

  /// Update content cached BorderBox
  /// Use when viewport contents change
  void updateBBox() {
    viewport.recacheViewBox();
  }

  /// Pan to a rendered position
  void pan(math.Point point) {
    var viewportCTM = this.viewport.getCTM();
    viewportCTM.e = point.x;
    viewportCTM.f = point.y;
    viewport.setCTM(viewportCTM);
  }

  /// Relatively pan the graph by a specified rendered position vector.
  void panBy(math.Point point) {
    var viewportCTM = this.viewport.getCTM();
    viewportCTM.e += point.x;
    viewportCTM.f += point.y;
    viewport.setCTM(viewportCTM);
  }

  /// Get pan vector.
  math.Point getPan() {
    var state = viewport.getState();

    return new math.Point(state.x, state.y);
  }

  /// Recalculates cached svg dimensions and controls position.
  void resize() {
    // Get dimensions.
    var boundingClientRectNormalized = svgUtils.getBoundingClientRectNormalized(svg);
    width = boundingClientRectNormalized.width;
    height = boundingClientRectNormalized.height;

    // Reposition control icons by re-enabling them
    if (options.controlIconsEnabled) {
      getPublicInstance().disableControlIcons();
      getPublicInstance().enableControlIcons();
    }
  }

  Function beforeZoom, onZoom, beforePan, onPan;
  var publicInstance, pi;

  /// Unbind mouse events, free callbacks and destroy public instance
  destroy() {
//    var that = this;

    // Free callbacks
    beforeZoom = null;
    onZoom = null;
    beforePan = null;
    onPan = null;

    // Destroy custom event handlers
    if (options.customEventsHandler != null) {
      options.customEventsHandler.destroy({
        'svgElement': svg,
        'instance': getPublicInstance()
      });
    }

    // Unbind eventListeners
    for (var event in eventListeners.keys) {
      svg.removeEventListener(event, eventListeners[event], false);
    }

    // Unbind wheelListener
    disableMouseWheelZoom();

    // Remove control icons
    getPublicInstance().disableControlIcons();

    // Reset zoom and pan
    reset();

    // Remove instance from instancesStore
    instancesStore = instancesStore.where((Map instance) {
      return instance['svg'] != svg;
    }).toList();

    // Delete options and its contents
    /*delete*/ options = null;

    // Destroy public instance and rewrite getPublicInstance
    /*delete*/ publicInstance = null;
    /*delete*/ pi = null;
//    getPublicInstance = () {
//      return null;
//    };
  }

  /// Returns a public instance object
//  Function getPublicInstance = () {
  getPublicInstance() {
    // Create cache
    if (publicInstance == null) {
      publicInstance = pi = new PublicSvgPanZoom(this);
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
    }

    return publicInstance;
  }
}

class PublicSvgPanZoom {
  final SvgPanZoom spz;
  PublicSvgPanZoom(this.spz);

  /// Pan

  enablePan() {
    spz.options.panEnabled = true;
    return spz.pi;
  }

  disablePan() {
    spz.options.panEnabled = false;
    return spz.pi;
  }

  isPanEnabled() {
    return !!spz.options.panEnabled;
  }

  pan(point) {
    spz.pan(point);
    return spz.pi;
  }

  panBy(point) {
    spz.panBy(point);
    return spz.pi;
  }

  getPan() {
    return spz.getPan();
  }

  /// Pan event
  setBeforePan(fn) {
    spz.options.beforePan = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
    return spz.pi;
  }

  setOnPan(fn) {
    spz.options.onPan = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
    return spz.pi;
  }

  /// Zoom and control icons.

  enableZoom() {
    spz.options.zoomEnabled = true;
    return spz.pi;
  }

  disableZoom() {
    spz.options.zoomEnabled = false;
    return spz.pi;
  }

  isZoomEnabled() {
    return !!spz.options.zoomEnabled;
  }

  enableControlIcons() {
    if (!spz.options.controlIconsEnabled) {
      spz.options.controlIconsEnabled = true;
      controls.enable(spz);
    }
    return spz.pi;
  }

  disableControlIcons() {
    if (spz.options.controlIconsEnabled) {
      spz.options.controlIconsEnabled = false;
      controls.disable(spz);
    }
    return spz.pi;
  }

  isControlIconsEnabled() {
    return !!spz.options.controlIconsEnabled;
  }

  /// Double click zoom.

  enableDblClickZoom() {
    spz.options.dblClickZoomEnabled = true;
    return spz.pi;
  }

  disableDblClickZoom() {
    spz.options.dblClickZoomEnabled = false;
    return spz.pi;
  }

  isDblClickZoomEnabled() {
    return !!spz.options.dblClickZoomEnabled;
  }

  /// Mouse wheel zoom

  enableMouseWheelZoom() {
    spz.enableMouseWheelZoom();
    return spz.pi;
  }

  disableMouseWheelZoom() {
    spz.disableMouseWheelZoom();
    return spz.pi;
  }

  isMouseWheelZoomEnabled() {
    return !!spz.options.mouseWheelZoomEnabled;
  }

  /// Zoom scale and bounds

  setZoomScaleSensitivity(scale) {
    spz.options.zoomScaleSensitivity = scale;
    return spz.pi;
  }

  setMinZoom(zoom) {
    spz.options.minZoom = zoom;
    return spz.pi;
  }

  setMaxZoom(zoom) {
    spz.options.maxZoom = zoom;
    return spz.pi;
  }

  /// Zoom event

  setBeforeZoom(fn) {
    spz.options.beforeZoom = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
    return spz.pi;
  }

  setOnZoom(fn) {
    spz.options.onZoom = fn;// == null ? null : Utils.proxy(fn, spz.publicInstance);
    return spz.pi;
  }

  /// Zooming

  zoom(scale) {
    spz.publicZoom(scale, true);
    return spz.pi;
  }

  zoomBy(scale) {
    spz.publicZoom(scale, false);
    return spz.pi;
  }

  zoomAtPoint(scale, point) {
    spz.publicZoomAtPoint(scale, point, true);
    return spz.pi;
  }

  zoomAtPointBy(scale, point) {
    spz.publicZoomAtPoint(scale, point, false);
    return spz.pi;
  }

  zoomIn() {
    zoomBy(1 + spz.options.zoomScaleSensitivity);
    return spz.pi;
  }

  zoomOut() {
    zoomBy(1 / (1 + spz.options.zoomScaleSensitivity));
    return spz.pi;
  }

  getZoom() {
    return spz.getRelativeZoom();
  }

  /// Reset

  resetZoom() {
    spz.resetZoom();
    return spz.pi;
  }

  resetPan() {
    spz.resetPan();
    return spz.pi;
  }

  reset() {
    spz.reset();
    return spz.pi;
  }

  /// Fit and Center

  fit() {
    spz.fit();
    return spz.pi;
  }

  center() {
    spz.center();
    return spz.pi;
  }

  /// Size and Resize

  updateBBox() {
    spz.updateBBox();
    return spz.pi;
  }

  resize() {
    spz.resize();
    return spz.pi;
  }

  getSizes() {
    return {
      'width': spz.width,
      'height': spz.height,
      'realZoom': spz.getZoom(),
      'viewBox': spz.viewport.getViewBox()
    };
  }

  /// Destroy

  destroy() {
    spz.destroy();
    return spz.pi;
  }
}

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

//module.exports = svgPanZoom;
