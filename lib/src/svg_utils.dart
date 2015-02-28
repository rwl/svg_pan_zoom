// Copyright (c) 2009-2015 Andrea Leofreddi
// All rights reserved.
library svg_pan_zoom.internal.svg_utils;

import 'dart:math' show Rectangle;
import 'dart:svg';
import 'dart:html' hide Point;

const svgNS = 'http://www.w3.org/2000/svg';
const xmlNS = 'http://www.w3.org/XML/1998/namespace';
const xmlnsNS = 'http://www.w3.org/2000/xmlns/';
const xlinkNS = 'http://www.w3.org/1999/xlink';
const evNS = 'http://www.w3.org/2001/xml-events';

/// Gets g element with class of "viewport" or creates it if it doesn't exist.
GElement getOrCreateViewport(SvgSvgElement svg, dynamic selector) {
  var viewport = null;

  if (selector is Element) {
    viewport = selector;
  } else {
    viewport = svg.querySelector(selector);
  }

  // Check if there is just one main group in SVG.
  if (viewport == null) {
    final childNodes = svg.childNodes.where((Node el) {
      return el.nodeName != 'defs' && el.nodeName != '#text';
    }).toList();

    // Node name should be GElement and should have no transform attribute.
    // Groups with transform are not used as viewport because it involves
    // parsing of all transform possibilities.
    if (childNodes.length == 1 && childNodes.first.nodeName == 'g' &&
        childNodes.first.getAttribute('transform') == null) {
      viewport = childNodes.first;
    }
  }

  // If no favorable group element exists then create one.
  if (viewport == null) {
    var viewportId = 'viewport-' +
        new DateTime.now().toIso8601String().replaceAll('\D', '');
    viewport = document.createElementNS(svgNS, 'g');
    viewport.setAttribute('id', viewportId);

    var svgChildren = svg.childNodes;
    if (svgChildren != null && svgChildren.length > 0) {
      for (var i = svgChildren.length; i > 0; i--) {
        // Move everything into viewport except defs.
        if (svgChildren[svgChildren.length - i].nodeName != 'defs') {
          viewport.append(svgChildren[svgChildren.length - i]);
        }
      }
    }
    svg.append(viewport);
  }

  // Parse class names.
  var classNames = [];
  if (viewport.getAttribute('class') != null) {
    classNames = viewport.getAttribute('class').split(' ');
  }

  // Set class (if not set already).
  if (classNames.indexOf('svg-pan-zoom_viewport') == -1) {
    classNames.add('svg-pan-zoom_viewport');
    viewport.setAttribute('class', classNames.join(' '));
  }

  return viewport;
}

/// Set SVG attributes.
setupSvgAttributes(SvgSvgElement svg) {
  // Setting default attributes
  svg.setAttribute('xmlns', svgNS);
  svg.setAttributeNS(xmlnsNS, 'xmlns:xlink', xlinkNS);
  svg.setAttributeNS(xmlnsNS, 'xmlns:ev', evNS);

  // Needed for Internet Explorer, otherwise the viewport overflows
  if (svg.parentNode != null) {
    var style = svg.getAttribute('style');
    if (style == null) {
      style = '';
    }
    if (style.toLowerCase().indexOf('overflow') == -1) {
      svg.setAttribute('style', 'overflow: hidden; $style');
    }
  }
}

/// Sets the current transform matrix of an element.
setCTM(SvgElement element, Matrix m, SvgElement defs) {
  var s = 'matrix(${m.a},${m.b},${m.c},${m.d},${m.e},${m.f})';

  element.setAttributeNS(null, 'transform', s);
}

/// Instantiate an svg.Point object with given event coordinates.
Point getEventPoint(MouseEvent evt, SvgSvgElement svg) {
  final point = svg.createSvgPoint();

//  Utils.mouseAndTouchNormalize(evt, svg);

  point.x = evt.client.x;
  point.y = evt.client.y;

  return point;
}

/// Get SVG center point.
Point getSvgCenterPoint(SvgSvgElement svg, num width, num height) {
  return createSVGPoint(svg, width / 2, height / 2);
}

/// Create a SVGPoint with given x and y.
Point createSVGPoint(SvgSvgElement svg, num x, num y) {
  var point = svg.createSvgPoint();
  point.x = x;
  point.y = y;

  return point;
}
