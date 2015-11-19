# svg_pan_zoom

A library for panning and zooming of SVG images in HTML documents.

An interface to [svg-pan-zoom](https://github.com/ariutta/svg-pan-zoom) by
Anders Riutta.

## Usage

    import 'package:svg_pan_zoom/svg_pan_zoom.dart';

    main() {
      var panZoom = new SvgPanZoom.selector('#svg', fit: true, center: true)
        ..zoomEnabled = true
        ..controlsEnabled = true;
    }
