// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.internal.svg_utils;

import 'dart:math' show Rectangle;
import 'dart:svg';
import 'dart:html' hide Point;

//var Utils = require('./utilities')
//  , _browser = 'unknown'
//  ;

// http://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
//if (/*@cc_on!@*/false || !!document.documentMode) { // internet explorer
//  _browser = 'ie';
//}

//module.exports = {
const svgNS = 'http://www.w3.org/2000/svg';
const xmlNS = 'http://www.w3.org/XML/1998/namespace';
const xmlnsNS = 'http://www.w3.org/2000/xmlns/';
const xlinkNS = 'http://www.w3.org/1999/xlink';
const evNS = 'http://www.w3.org/2001/xml-events';

  /**
   * Get svg dimensions: width and height
   *
   * @param  {SVGSVGElement} svg
   * @return {Object}     {width: 0, height: 0}
   */
  Rectangle getBoundingClientRectNormalized(SvgSvgElement svg) {
    return svg.getBoundingClientRect();
    /*if (svg.clientWidth && svg.clientHeight) {
      return {width: svg.clientWidth, height: svg.clientHeight};
    } else if (!!svg.getBoundingClientRect()) {
      return svg.getBoundingClientRect();
    } else {
      throw new Error('Cannot get BoundingClientRect for SVG.');
    }*/
  }

  /**
   * Gets g element with class of "viewport" or creates it if it doesn't exist
   *
   * @param  {SVGSVGElement} svg
   * @return {SVGElement}     g (group) element
   */
  GElement getOrCreateViewport(SvgSvgElement svg, selector) {
    var viewport = null;

    if (Utils.isElement(selector)) {
      viewport = selector;
    } else {
      viewport = svg.querySelector(selector);
    }

    // Check if there is just one main group in SVG
    if (!viewport) {
      var childNodes = Array.prototype.slice.call(svg.childNodes || svg.children).filter((el) {
        return el.nodeName != 'defs' && el.nodeName != '#text';
      });

      // Node name should be SVGGElement and should have no transform attribute
      // Groups with transform are not used as viewport because it involves parsing of all transform possibilities
      if (childNodes.length == 1 && childNodes[0].nodeName == 'g' && childNodes[0].getAttribute('transform') == null) {
        viewport = childNodes[0];
      }
    }

    // If no favorable group element exists then create one
    if (!viewport) {
      var viewportId = 'viewport-' + new Date().toISOString().replaceAll('\D', '');
      viewport = document.createElementNS(svgNS, 'g');
      viewport.setAttribute('id', viewportId);

      // Internet Explorer (all versions?) can't use childNodes, but other browsers prefer (require?) using childNodes
      var svgChildren = svg.childNodes || svg.children;
      if (!!svgChildren && svgChildren.length > 0) {
        for (var i = svgChildren.length; i > 0; i--) {
          // Move everything into viewport except defs
          if (svgChildren[svgChildren.length - i].nodeName != 'defs') {
            viewport.appendChild(svgChildren[svgChildren.length - i]);
          }
        }
      }
      svg.appendChild(viewport);
    }

    // Parse class names
    var classNames = [];
    if (viewport.getAttribute('class')) {
      classNames = viewport.getAttribute('class').split(' ');
    }

    // Set class (if not set already)
    if (!~classNames.indexOf('svg-pan-zoom_viewport')) {
      classNames.push('svg-pan-zoom_viewport');
      viewport.setAttribute('class', classNames.join(' '));
    }

    return viewport;
  }

  /**
   * Set SVG attributes
   *
   * @param  {SVGSVGElement} svg
   */
  setupSvgAttributes(svg) {
    // Setting default attributes
    svg.setAttribute('xmlns', svgNS);
    svg.setAttributeNS(xmlnsNS, 'xmlns:xlink', xlinkNS);
    svg.setAttributeNS(xmlnsNS, 'xmlns:ev', evNS);

    // Needed for Internet Explorer, otherwise the viewport overflows
    if (svg.parentNode != null) {
      var style = svg.getAttribute('style') || '';
      if (style.toLowerCase().indexOf('overflow') == -1) {
        svg.setAttribute('style', 'overflow: hidden; ' + style);
      }
    }
  }

/**
 * How long Internet Explorer takes to finish updating its display (ms).
 */
var internetExplorerRedisplayInterval = 300;

/**
 * Forces the browser to redisplay all SVG elements that rely on an
 * element defined in a 'defs' section. It works globally, for every
 * available defs element on the page.
 * The throttling is intentionally global.
 *
 * This is only needed for IE. It is as a hack to make markers (and 'use' elements?)
 * visible after pan/zoom when there are multiple SVGs on the page.
 * See bug report: https://connect.microsoft.com/IE/feedback/details/781964/
 * also see svg-pan-zoom issue: https://github.com/ariutta/svg-pan-zoom/issues/62
 */
var refreshDefsGlobal = Utils.throttle(() {
    var allDefs = document.querySelectorAll('defs');
    var allDefsCount = allDefs.length;
    for (var i = 0; i < allDefsCount; i++) {
      var thisDefs = allDefs[i];
      thisDefs.parentNode.insertBefore(thisDefs, thisDefs);
    }
  }, internetExplorerRedisplayInterval);

  /**
   * Sets the current transform matrix of an element
   *
   * @param {SVGElement} element
   * @param {SVGMatrix} matrix  CTM
   * @param {SVGElement} defs
   */
setCTM(element, matrix, defs) {
  //var that = this
  var s = 'matrix(' + matrix.a + ',' + matrix.b + ',' + matrix.c + ',' + matrix.d + ',' + matrix.e + ',' + matrix.f + ')';

  element.setAttributeNS(null, 'transform', s);

  // IE has a bug that makes markers disappear on zoom (when the matrix "a" and/or "d" elements change)
  // see http://stackoverflow.com/questions/17654578/svg-marker-does-not-work-in-ie9-10
  // and http://srndolha.wordpress.com/2013/11/25/svg-line-markers-may-disappear-in-internet-explorer-11/
  if (_browser == 'ie' && !!defs) {
    // this refresh is intended for redisplaying the SVG during zooming
    defs.parentNode.insertBefore(defs, defs);
    // this refresh is intended for redisplaying the other SVGs on a page when panning a given SVG
    // it is also needed for the given SVG itself, on zoomEnd, if the SVG contains any markers that
    // are located under any other element(s).
    window.setTimeout(() {
      that.refreshDefsGlobal();
    }, that.internetExplorerRedisplayInterval);
  }
}

/**
 * Instantiate an SVGPoint object with given event coordinates
 *
 * @param {Event} evt
 * @param  {SVGSVGElement} svg
 * @return {SVGPoint}     point
 */
Point getEventPoint(MouseEvent evt, SvgSvgElement svg) {
  final point = svg.createSvgPoint();

  Utils.mouseAndTouchNormalize(evt, svg);

  point.x = evt.client.x;
  point.y = evt.client.y;

  return point;
}

/**
 * Get SVG center point
 *
 * @param  {SVGSVGElement} svg
 * @return {SVGPoint}
 */
getSvgCenterPoint(svg, width, height) {
  return createSVGPoint(svg, width / 2, height / 2);
}

/**
 * Create a SVGPoint with given x and y
 *
 * @param  {SVGSVGElement} svg
 * @param  {Number} x
 * @param  {Number} y
 * @return {SVGPoint}
 */
createSVGPoint(svg, x, y) {
  var point = svg.createSVGPoint();
  point.x = x;
  point.y = y;

  return point;
}
