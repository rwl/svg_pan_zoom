library svg_pan_zoom.internal.shadow_viewport;

//var SvgUtils = require('./svg-utilities')
//  , Utils = require('./utilities')
//  ;

//var ShadowViewport = function(viewport, options){
//  this.init(viewport, options)
//}

import 'dart:math' show Rectangle;
import 'dart:svg';

class State {
  final num zoom, x, y;
  State({this.zoom, this.x, this.y});
  factory State.from(State s) {
    return new State(s.zoom, s.x, s.y);
  }
}

class ShadowViewport {
  GElement viewport;
  Map options;
  State originalState, activeState;
  Rectangle viewBox;

  ShadowViewport(this.viewport, this.options) {
    // DOM Elements
//    this.viewport = viewport;
//    this.options = options;

    // State cache
    originalState = new State(zoom: 1, x: 0, y: 0);
    activeState = new State(zoom: 1, x: 0, y: 0);

    this.updateCTMCached = Utils.proxy(this.updateCTM, this);

    // Create a custom requestAnimationFrame taking in account refreshRate
    this.requestAnimationFrame = Utils.createRequestAnimationFrame(this.options.refreshRate);

    // ViewBox
    viewBox = new Rectangle(0, 0, 0, 0);
    cacheViewBox();

    // Process CTM
    processCTM();
  }

  /**
   * Cache initial viewBox value
   * If no viewBox is defined, then use viewport size/position instead for viewBox values
   */
  cacheViewBox() {
    var svgViewBox = this.options.svg.getAttribute('viewBox');

    if (svgViewBox) {
      var viewBoxValues = svgViewBox.split(' ').map(parseFloat);

      // Cache viewbox x and y offset
      this.viewBox.x = viewBoxValues[0];
      this.viewBox.y = viewBoxValues[1];
      this.viewBox.width = viewBoxValues[2];
      this.viewBox.height = viewBoxValues[3];

      var zoom = Math.min(this.options.width / this.viewBox.width, this.options.height / this.viewBox.height);

      // Update active state
      this.activeState.zoom = zoom;
      this.activeState.x = (this.options.width - this.viewBox.width * zoom) / 2;
      this.activeState.y = (this.options.height - this.viewBox.height * zoom) / 2;

      // Force updating CTM
      this.updateCTMOnNextFrame();

      this.options.svg.removeAttribute('viewBox');
    } else {
      var bBox = this.viewport.getBBox();

      // Cache viewbox sizes
      this.viewBox.x = bBox.x;
      this.viewBox.y = bBox.y;
      this.viewBox.width = bBox.width;
      this.viewBox.height = bBox.height;
    }
  }

  /**
   * Recalculate viewport sizes and update viewBox cache
   */
  recacheViewBox() {
    var boundingClientRect = this.viewport.getBoundingClientRect()
      , viewBoxWidth = boundingClientRect.width / this.getZoom()
      , viewBoxHeight = boundingClientRect.height / this.getZoom();

    // Cache viewbox
    this.viewBox.x = 0;
    this.viewBox.y = 0;
    this.viewBox.width = viewBoxWidth;
    this.viewBox.height = viewBoxHeight;
  }

  /**
   * Returns a viewbox object. Safe to alter
   *
   * @return {Object} viewbox object
   */
  getViewBox() {
    return Utils.extend({}, this.viewBox);
  }

  /**
   * Get initial zoom and pan values. Save them into originalState
   * Parses viewBox attribute to alter initial sizes
   */
  processCTM() {
    var newCTM = this.getCTM();

    if (this.options.fit) {
      var newScale = Math.min(this.options.width/(this.viewBox.width - this.viewBox.x), this.options.height/(this.viewBox.height - this.viewBox.y));

      newCTM.a = newScale; //x-scale
      newCTM.d = newScale; //y-scale
      newCTM.e = -this.viewBox.x * newScale; //x-transform
      newCTM.f = -this.viewBox.y * newScale; //y-transform
    }

    if (this.options.center) {
      var offsetX = (this.options.width - (this.viewBox.width + this.viewBox.x) * newCTM.a) * 0.5
        , offsetY = (this.options.height - (this.viewBox.height + this.viewBox.y) * newCTM.a) * 0.5;

      newCTM.e = offsetX;
      newCTM.f = offsetY;
    }

    // Cache initial values. Based on activeState and fix+center opitons
    this.originalState.zoom = newCTM.a;
    this.originalState.x = newCTM.e;
    this.originalState.y = newCTM.f;

    // Update viewport CTM and cache zoom and pan
    this.setCTM(newCTM);
  }

  /// Return originalState object. Safe to alter
  State getOriginalState() {
    //return Utils.extend({}, originalState);
    return new State.from(originalState);
  }

  /**
   * Return actualState object. Safe to alter
   *
   * @return {Object}
   */
  State getState() {
//    return Utils.extend({}, this.activeState);
    return new State.from(activeState);
  }

  /**
   * Get zoom scale
   *
   * @return {Float} zoom scale
   */
  getZoom() {
    return this.activeState.zoom;
  }

  /**
   * Get zoom scale for pubilc usage
   *
   * @return {Float} zoom scale
   */
  getRelativeZoom() {
    return this.activeState.zoom / this.originalState.zoom;
  }

  /**
   * Compute zoom scale for pubilc usage
   *
   * @return {Float} zoom scale
   */
  computeRelativeZoom(scale) {
    return scale / this.originalState.zoom;
  }

  /**
   * Get pan
   *
   * @return {Object}
   */
  getPan() {
    return {x: this.activeState.x, y: this.activeState.y};
  }

  /**
   * Return cached viewport CTM value that can be safely modified
   *
   * @return {SVGMatrix}
   */
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

  /**
   * Set a new CTM
   *
   * @param {SVGMatrix} newCTM
   */
  setCTM(newCTM) {
    var willZoom = this.isZoomDifferent(newCTM)
      , willPan = this.isPanDifferent(newCTM);

    if (willZoom || willPan) {
      // Before zoom
      if (willZoom) {
        // If returns false then cancel zooming
        if (this.options.beforeZoom(this.getRelativeZoom(), this.computeRelativeZoom(newCTM.a)) == false) {
          newCTM.a = newCTM.d = this.activeState.zoom;
          willZoom = false;
        }
      }

      // Before pan
      if (willPan) {
        var preventPan = this.options.beforePan(this.getPan(), {x: newCTM.e, y: newCTM.f})
            // If prevent pan is an object
          , preventPanX = false
          , preventPanY = false;

        // If prevent pan is Boolean false
        if (preventPan == false) {
          // Set x and y same as before
          newCTM.e = this.getPan().x;
          newCTM.f = this.getPan().y;

          preventPanX = preventPanY = true;
        } else if (Utils.isObject(preventPan)) {
          // Check for X axes attribute
          if (preventPan.x == false) {
            // Prevent panning on x axes
            newCTM.e = this.getPan().x;
            preventPanX = true;
          } else if (Utils.isNumber(preventPan.x)) {
            // Set a custom pan value
            newCTM.e = preventPan.x;
          }

          // Check for Y axes attribute
          if (preventPan.y == false) {
            // Prevent panning on x axes
            newCTM.f = this.getPan().y;
            preventPanY = true;
          } else if (Utils.isNumber(preventPan.y)) {
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
        this.updateCache(newCTM);

        this.updateCTMOnNextFrame();

        // After callbacks
        if (willZoom) {this.options.onZoom(this.getRelativeZoom());}
        if (willPan) {this.options.onPan(this.getPan());}
      }
    }
  }

  isZoomDifferent(newCTM) {
    return this.activeState.zoom != newCTM.a;
  }

  isPanDifferent(newCTM) {
    return this.activeState.x != newCTM.e || this.activeState.y != newCTM.f;
  }


  /**
   * Update cached CTM and active state
   *
   * @param {SVGMatrix} newCTM
   */
  updateCache(newCTM) {
    this.activeState.zoom = newCTM.a;
    this.activeState.x = newCTM.e;
    this.activeState.y = newCTM.f;
  }

  var pendingUpdate = false;

  /**
   * Place a request to update CTM on next Frame
   */
  updateCTMOnNextFrame() {
    if (!this.pendingUpdate) {
      // Lock
      this.pendingUpdate = true;

      // Throttle next update
      this.requestAnimationFrame.call(window, this.updateCTMCached);
    }
  }

  /**
   * Update viewport CTM with cached CTM
   */
  updateCTM() {
    // Updates SVG element
    SvgUtils.setCTM(this.viewport, this.getCTM(), this.defs);

    // Free the lock
    this.pendingUpdate = false;
  }
}

//module.exports = function(viewport, options){
//  return new ShadowViewport(viewport, options)
//}