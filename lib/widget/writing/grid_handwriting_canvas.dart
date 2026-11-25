import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:aiwriting_collection/design_system/app_tokens.dart';
import 'package:aiwriting_collection/model/content/stroke/stroke.dart';
import 'package:aiwriting_collection/widget/writing/inactivecell_painter.dart';
import 'package:flutter/material.dart';
import 'package:aiwriting_collection/model/content/stroke/stroke_guide_model.dart';
import 'grid_painter.dart';
import 'handwriting_painter.dart';
import 'guide_painter.dart';

// grid_painter와 handwriting_painter를 조합해 터치 이벤트를 처리하는 위젯
class GridHandwritingCanvas extends StatefulWidget {
  final int charCount; // 총 그리드 셀 개수 (최대 크기)
  final List<int>? essentialStrokeCounts;
  final int maxPerRow;
  final double cellSize;
  final Color gridColor;
  final double gridWidth;
  final Color penColor;
  final double penStrokeWidth;

  /// 가이드라인을 그릴지 여부
  final bool showGuides;

  /// 셀마다 그릴 가이드 문자열. 이 문자열의 길이가 실제 쓰기 가능한 셀의 수를 결정합니다.
  final String? guideChar;

  final bool showStrokeGuide;

  final Map<String, StrokeCharGuide> strokeGuides;

  const GridHandwritingCanvas({
    super.key,
    required this.charCount, // 그리드의 최대 셀 개수
    required this.essentialStrokeCounts,
    this.strokeGuides = const <String, StrokeCharGuide>{},
    this.maxPerRow = 10,
    this.cellSize = 40,
    this.gridColor = Colors.black,
    this.gridWidth = 1.0,
    this.penColor = Colors.black,
    this.penStrokeWidth = 7.0,
    this.showGuides = false,
    this.guideChar, // 쓰기 가능한 실제 문자열 (이 길이까지만 활성화)
    this.showStrokeGuide = false,
  });

  @override
  GridHandwritingCanvasState createState() => GridHandwritingCanvasState();
}

class GridHandwritingCanvasState extends State<GridHandwritingCanvas> {
  // 획들의 모음
  final List<Stroke> strokes = [];
  // 현재 그리고 있는 하나의 획
  List<Offset> currentStrokePath = [];
  // 현재 활성화된(쓰기가 가능한) 셀의 인덱스
  int activeCell = 0;
  int? _activePointer;
  double? _activeStrokeWidth;
  static const _minimumStrokeDistance = 1.0;

  // 총 그리드 열 개수 (최대)
  int get cols =>
      widget.charCount < widget.maxPerRow ? widget.charCount : widget.maxPerRow;
  // 총 그리드 행 개수 (최대)
  int get rows => (widget.charCount / widget.maxPerRow).ceil();

  // 실제로 쓰기가 가능한 셀의 총 개수 (guideChar의 길이에 따름)
  int get _writeableCharCount =>
      (widget.guideChar?.length ?? widget.charCount).clamp(0, widget.charCount);

  /// 그리드에서 특정 셀(cellIndex)이 차지하는 사각 영역(Rectangle)을 계산합니다.
  Rect _cellRect(int cellIndex) {
    final row = cellIndex ~/ cols;
    final col = cellIndex % cols;
    return Rect.fromLTWH(
      col * widget.cellSize,
      row * widget.cellSize,
      widget.cellSize,
      widget.cellSize,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null || activeCell >= _writeableCharCount) return;
    if (!_cellRect(activeCell).contains(event.localPosition)) return;

    setState(() {
      _activePointer = event.pointer;
      _activeStrokeWidth = widget.penStrokeWidth;
      currentStrokePath = [event.localPosition];
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (!_cellRect(activeCell).contains(event.localPosition)) return;
    setState(() => currentStrokePath.add(event.localPosition));
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;

    setState(() {
      if (_cellRect(activeCell).contains(event.localPosition) &&
          event.localPosition != currentStrokePath.last) {
        currentStrokePath.add(event.localPosition);
      }
      final start = currentStrokePath.first;
      final hasVisibleStroke = currentStrokePath.any(
        (point) => (point - start).distance >= _minimumStrokeDistance,
      );
      if (hasVisibleStroke) {
        strokes.add(
          Stroke(
            cellIndex: activeCell,
            path: currentStrokePath,
            strokeWidth: _activeStrokeWidth!,
          ),
        );
        _maybeAdvanceCell();
      }
      _resetPointer();
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointer) {
      setState(_resetPointer);
    }
  }

  void _resetPointer() {
    _activePointer = null;
    _activeStrokeWidth = null;
    currentStrokePath = [];
  }

  void _skipZeroStrokeCells() {
    final required = widget.essentialStrokeCounts;
    if (required == null) return;
    while (activeCell < _writeableCharCount &&
        activeCell < required.length &&
        required[activeCell] == 0) {
      activeCell++;
    }
  }

  void _maybeAdvanceCell() {
    final required = widget.essentialStrokeCounts;
    if (required == null || activeCell >= required.length) return;

    final cellStrokes = strokes.where(
      (stroke) => stroke.cellIndex == activeCell,
    );
    if (cellStrokes.length >= required[activeCell]) {
      activeCell++;
      _skipZeroStrokeCells();
    }
  }

  @override
  void initState() {
    super.initState();
    _skipZeroStrokeCells();
  }

  @override
  Widget build(BuildContext context) {
    // 한 줄에 그릴 실제 열 개수 (전체 그리드 크기 기준)
    final colCount =
        widget.charCount < widget.maxPerRow
            ? widget.charCount
            : widget.maxPerRow;
    final rowCount = (widget.charCount / widget.maxPerRow).ceil();
    // 캔버스 크기 (전체 그리드 크기 기준)
    final width = colCount * widget.cellSize;
    final height = rowCount * widget.cellSize;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // 비활성화된 셀을 그리는 CustomPaint
          CustomPaint(
            size: Size(width, height),
            painter: InactiveCellPainter(
              activeCell: activeCell,
              charCount: _writeableCharCount, // 쓰기 가능한 셀 수를 전달하여 그 이후는 비활성 처리
              maxPerRow: widget.maxPerRow,
              cellSize: widget.cellSize,
            ),
          ),

          // 터치 이벤트를 감지하는 Listener
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerMove: _onPointerMove,
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: CustomPaint(
              size: Size(width, height),
              painter: GridPainter(
                charCount: widget.charCount, // 전체 그리드 크기 기준
                maxPerRow: widget.maxPerRow,
                cellSize: widget.cellSize,
                lineWidth: widget.gridWidth,
                lineColor: widget.gridColor,
              ),
              // GuidePainter와 HandwritingPainter를 함께 그립니다.
              child:
                  widget.showGuides
                      ? CustomPaint(
                        size: Size(width, height),
                        painter: GuidePainter(
                          guideText: widget.guideChar ?? '',
                          charCount: widget.charCount, // 전체 그리드 크기 기준
                          maxPerRow: widget.maxPerRow,
                          cellSize: widget.cellSize,
                          textStyle: TextStyle(
                            fontFamily: AppFonts.reading,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[400],
                            fontSize: widget.cellSize * 0.7,
                          ),
                          showStrokeGuide: widget.showStrokeGuide,
                          strokeGuides: widget.strokeGuides,
                        ),
                        foregroundPainter: HandwritingPainter(
                          strokes: strokes,
                          currentStroke: currentStrokePath,
                          strokeColor: widget.penColor,
                          strokeWidth:
                              _activeStrokeWidth ?? widget.penStrokeWidth,
                        ),
                      )
                      : CustomPaint(
                        size: Size(width, height),
                        painter: HandwritingPainter(
                          strokes: strokes,
                          currentStroke: currentStrokePath,
                          strokeColor: widget.penColor,
                          strokeWidth:
                              _activeStrokeWidth ?? widget.penStrokeWidth,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  void undoLastStroke() {
    setState(() {
      _resetPointer();
      if (strokes.isNotEmpty) {
        activeCell = strokes.removeLast().cellIndex;
      }
    });
  }

  void clearAll() {
    setState(() {
      strokes.clear();
      _resetPointer();
      activeCell = 0;
      _skipZeroStrokeCells();
    });
  }

  Future<HandwritingSubmission> captureSubmission() async {
    if (_activePointer != null) {
      setState(_resetPointer);
    }
    final colCount = cols;
    final cellSize = widget.cellSize;
    final penColor = widget.penColor;
    final pixelSize = cellSize.ceil();
    final cellGroups = <int, List<Stroke>>{};
    final endpoints = <int, List<Offset>>{};
    for (final stroke in strokes) {
      cellGroups.putIfAbsent(stroke.cellIndex, () => []).add(stroke);
      endpoints.putIfAbsent(stroke.cellIndex, () => [])
        ..add(stroke.path.first)
        ..add(stroke.path.last);
    }

    final imagesByCell = <int, List<Uint8List>>{};
    for (final entry in cellGroups.entries) {
      final cellIndex = entry.key;
      final origin = Offset(
        (cellIndex % colCount) * cellSize,
        (cellIndex ~/ colCount) * cellSize,
      );
      final images = <Uint8List>[];
      for (final stroke in entry.value) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final paint =
            Paint()
              ..color = penColor
              ..strokeWidth = stroke.strokeWidth
              ..strokeCap = StrokeCap.round;
        canvas.clipRect(Rect.fromLTWH(0, 0, cellSize, cellSize));
        canvas.translate(-origin.dx, -origin.dy);

        for (var i = 0; i < stroke.path.length - 1; i++) {
          canvas.drawLine(stroke.path[i], stroke.path[i + 1], paint);
        }

        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(pixelSize, pixelSize);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (bytes == null) {
              throw StateError('Unable to encode stroke image');
            }
            images.add(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      }
      imagesByCell[cellIndex] = images;
    }
    return HandwritingSubmission(imagesByCell, endpoints);
  }
}

class HandwritingSubmission {
  const HandwritingSubmission(this.imagesByCell, this.endpointsByCell);

  final Map<int, List<Uint8List>> imagesByCell;
  final Map<int, List<Offset>> endpointsByCell;
}
