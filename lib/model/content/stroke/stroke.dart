import 'dart:ui';

class Stroke {
  final int cellIndex;
  final List<Offset> path;
  final double strokeWidth;

  Stroke({
    required this.cellIndex,
    required List<Offset> path,
    required this.strokeWidth,
  }) : path = List.unmodifiable(path);
}
