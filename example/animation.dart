import 'dart:html';
import 'dart:async';
import 'dart:math' as math;
import 'package:svg_pan_zoom/svg_pan_zoom.dart';

final math.Random r = new math.Random();

main() {
  var spz = new SvgPanZoom.selector('#svg-id',
      zoomEnabled: true,
      controlIconsEnabled: true,
      fit: true,
      center: true,
      minZoom: 0.1);

  // Zoom out
  spz.zoom = 0.2;

  var animationTime = 300; // ms
  var animationStepTime = 15; // one frame per 30 ms

  customPanBy(int panx, int pany) {
    var animationSteps = animationTime / animationStepTime;
    var animationStep = 0;
    var stepX = panx / animationSteps;
    var stepY = pany / animationSteps;

    var duration = new Duration(milliseconds: animationStepTime);
    new Timer.periodic(duration, (Timer t) {
      if (animationStep++ < animationSteps) {
        spz.panBy(stepX, stepY);
      } else {
        t?.cancel();
      }
    });
  }

  document.getElementById("animate").onClick.listen((_) {
    // Pan by any values from -80 to 80
    customPanBy((r.nextDouble() * 160 - 80).round(),
        (r.nextDouble() * 160 - 80).round());
  });
}
