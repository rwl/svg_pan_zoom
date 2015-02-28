library svg_pan_zoom.internal.utils;

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

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

/// Create a requestAnimationFrame simulation.
Function createRequestAnimationFrame(dynamic refreshRate) {
  var timeout = null;

  // Convert refreshRate to timeout.
  if (refreshRate != 'auto' && refreshRate < 60 && refreshRate > 1) {
    timeout = (1000 / refreshRate).floor();
  }

  if (timeout == null) {
    return window.requestAnimationFrame;
  } else {
    return requestTimeout(timeout);
  }
}

/// Create a callback that will execute after a given timeout.
Function requestTimeout(num timeout) {
  return (callback) {
    new Future.delayed(new Duration(milliseconds: timeout), callback);
  };
}
