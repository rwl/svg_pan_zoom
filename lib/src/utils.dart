library svg_pan_zoom.internal.utils;

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;
import 'dart:svg' hide ImageElement;

/// Search for an SVG element
SvgSvgElement getSvg(dynamic elementOrSelector) {
  Element element;
  SvgSvgElement svg;

  if (elementOrSelector is! Element) {
    // If selector provided
    if (elementOrSelector is String) {
      // Try to find the element
      element = document.querySelector(elementOrSelector);

      if (element == null) {
        throw new Exception('Provided selector did not find any elements. Selector: $elementOrSelector');
        return null;
      }
    } else {
      throw new ArgumentError.value(elementOrSelector, 'elementOrSelector',
          'Provided selector is not an HTML object nor String');
      return null;
    }
  } else {
    element = elementOrSelector;
  }

  if (element.tagName.toLowerCase() == 'svg') {
    svg = element;
  } else {
    throw new Exception('Cannot get SVG.');
    /*if (element.tagName.toLowerCase() == 'object') {
      svg = element.contentDocument.documentElement;
    } else {
      //if (element.tagName.toLowerCase() == 'embed') {
      if (element is EmbedElement) {
        //svg = element.getSVGDocument().documentElement;

        var request = new HttpRequest()
          ..open('GET', element.src, async: false)
          ..send();
        final doc = new DomParser().parseFromString(request.responseText, 'text/xml');
        svg = doc.documentElement;

      } else {
        //if (element.tagName.toLowerCase() === 'img') {
        if (element is ImageElement) {
          throw new Exception('Cannot script an SVG in an "img" element. Please use an "object" element or an in-line SVG.');
        } else {
          throw new Exception('Cannot get SVG.');
        }
        return null;
      }
    }*/
  }

  return svg;
}

/**
 * If it is a touch event than add clientX and clientY to event object
 *
 * @param  {Event} evt
 * @param  {SVGSVGElement} svg
 */
mouseAndTouchNormalize(Event evt, SvgSvgElement svg) {
/*  // If no cilentX and but touch objects are available
  if (evt.clientX === void 0 || evt.clientX === null) {
    // Fallback
    evt.clientX = 0
    evt.clientY = 0

    // If it is a touch event
    if (evt.changedTouches !== void 0 && evt.changedTouches.length) {
      // If touch event has changedTouches
      if (evt.changedTouches[0].clientX !== void 0) {
        evt.clientX = evt.changedTouches[0].clientX
        evt.clientY = evt.changedTouches[0].clientY
      }
      // If changedTouches has pageX attribute
      else if (evt.changedTouches[0].pageX !== void 0) {
        var rect = svg.getBoundingClientRect();

        evt.clientX = evt.changedTouches[0].pageX - rect.left
        evt.clientY = evt.changedTouches[0].pageY - rect.top
      }
    // If it is a custom event
    } else if (evt.originalEvent !== void 0) {
      if (evt.originalEvent.clientX !== void 0) {
        evt.clientX = evt.originalEvent.clientX
        evt.clientY = evt.originalEvent.clientY
      }
    }
  }*/
}

/// Check if an event is a double click/tap.
bool isDblClick(MouseEvent evt, MouseEvent prevEvt) {
  // Double click detected by browser.
  if (evt.detail == 2) {
    return true;
  }
  // Try to compare events.
  else if (prevEvt != null) {
    num timeStampDiff = evt.timeStamp - prevEvt.timeStamp; // should be lower than 250 ms
    var touchesDistance = math.sqrt(math.pow(evt.client.x - prevEvt.client.x, 2) + math.pow(evt.client.y - prevEvt.client.y, 2));

    return timeStampDiff < 250 && touchesDistance < 10;
  }

  // Nothing found.
  return false;
}

/// Create a requestAnimationFrame simulation
Function createRequestAnimationFrame(dynamic refreshRate) {
  var timeout = null;

  // Convert refreshRate to timeout
  if (refreshRate != 'auto' && refreshRate < 60 && refreshRate > 1) {
    timeout = (1000 / refreshRate).floor();
  }

  if (timeout == null) {
    return window.requestAnimationFrame;// || requestTimeout(33);
  } else {
    return requestTimeout(timeout);
  }
}

/// Create a callback that will execute after a given timeout
Function requestTimeout(num timeout) {
  return (callback) {
    //window.setTimeout(callback, timeout);
    new Future.delayed(new Duration(milliseconds: timeout), callback);
  };
}
