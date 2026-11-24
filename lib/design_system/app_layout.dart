import 'dart:math' as math;
import 'dart:ui';

abstract final class AppLayout {
  static const portraitReferenceWidth = 390.0;
  static const landscapeReferenceHeight = 844.0;

  /// Shrinks the reference layout to fit smaller windows and caps growth at 1×.
  static double scale(
    Size size, {
    double portraitWidth = portraitReferenceWidth,
    double landscapeHeight = landscapeReferenceHeight,
  }) {
    return size.width > size.height
        ? scaleForExtent(size.height, landscapeHeight)
        : scaleForExtent(size.width, portraitWidth);
  }

  static double scaleForExtent(double extent, double referenceExtent) {
    return math.min(extent / referenceExtent, 1.0);
  }
}
