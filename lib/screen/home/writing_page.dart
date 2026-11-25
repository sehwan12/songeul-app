import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aiwriting_collection/design_system/app_layout.dart';
import 'package:aiwriting_collection/design_system/app_tokens.dart';
import 'package:aiwriting_collection/model/provider/data_provider.dart';
import 'package:aiwriting_collection/model/content/steps.dart';
import 'package:aiwriting_collection/model/common/type_enum.dart';
import 'package:aiwriting_collection/generated/app_localizations.dart';
import 'package:aiwriting_collection/widget/dialog/mini_dialog.dart';
import 'package:aiwriting_collection/widget/common/back_button.dart';
import 'package:aiwriting_collection/widget/common/speech_bubble.dart';
import 'package:aiwriting_collection/widget/writing/grid_handwriting_canvas.dart';
import 'package:flutter/material.dart';
import 'package:aiwriting_collection/api.dart';
import 'package:provider/provider.dart';
import '../../model/provider/login_status.dart';
import 'package:aiwriting_collection/widget/dialog/feedback_dialog.dart';
import 'package:aiwriting_collection/widget/dialog/letter_feedback.dart';

class WritingPage extends StatefulWidget {
  final Steps nowStep;
  final bool showGuides;
  const WritingPage({
    super.key,
    required this.nowStep,
    this.showGuides = false,
  });

  @override
  State<WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<WritingPage> {
  bool _isPoppingPage = false;
  bool _isSubmitting = false;
  double _penStrokeWidth = 7.0; // Initial pen thickness
  static const double _minPenStrokeWidth = 1.0;
  static const double _maxPenStrokeWidth = 20.0;
  Map<String, List<int>> _stringKeyMap(Map<int, List<int>> src) {
    return src.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, List<String>> _stringKeyMap3(Map<int, List<String>> src) {
    return src.map((key, value) => MapEntry(key.toString(), value));
  }

  // 결과 저장 & 열람 가능 상태(mutable!)
  List<Map<String, dynamic>> _letterResults = [];
  bool _feedbackReady = false;
  List<int?> _textIndexToResult = [];

  final api = Api();
  //GlobalKey를 이용해 GridHandwritingCanvas의 내부 상태에 직접 접근할 수 있도록
  final GlobalKey<GridHandwritingCanvasState> _canvasKey =
      GlobalKey<GridHandwritingCanvasState>();

  Timer? _timer;
  late int _remainingTime;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.nowStep.stepTime; // use practice.time
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      //mounted는 state객체가 현재화면에 장착되어있는지를 나타내는 속성
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        timer.cancel();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            final double dialogScale = scaled(context, 2);
            return MiniDialog(
              scale: dialogScale,
              title: AppLocalizations.of(context)!.failure,
              content: AppLocalizations.of(context)!.timeExpired,
            );
          },
        ).then((_) {
          if (!mounted || _isPoppingPage) return;
          _isPoppingPage = true;
          Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _showLetterFeedback(int index) async {
    if (index < 0 || index >= _letterResults.length) return;
    final item = _letterResults[index];

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final String original = item['original_text']?.toString() ?? '';
        final double? score = (item['score'] as num?)?.toDouble();
        final String stage = item['stage']?.toString() ?? '0000';

        final List<dynamic> fbListRaw = (item['feedback'] as List?) ?? const [];
        final List<String> fbList =
            fbListRaw
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();

        return LetterFeedbackSheet(
          targetChar: original,
          score: score,
          stage: stage,
          feedback: fbList,
          imagePath: widget.nowStep.stepCharacter,
        );
      },
    );
  }

  //기본 기준값

  double scaled(BuildContext context, double value) {
    final Size size = MediaQuery.of(context).size;
    //가로모드/세로모드 구분
    final double scale = AppLayout.scale(size);
    return value * scale;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 각 셀의 획 이미지를 base64로 인코딩합니다
  Map<int, List<String>> _encodeImages(Map<int, List<Uint8List>> images) {
    final Map<int, List<String>> cellImages = {};
    images.forEach((cellIndex, byteList) {
      cellImages[cellIndex] =
          byteList.map((bytes) => base64Encode(bytes)).toList();
    });
    return cellImages;
  }

  /// 획 오류 다이얼로그를 표시합니다
  Future<void> _showStrokeErrorDialog(String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        final double dialogScale = scaled(context, 2);
        return MiniDialog(
          scale: dialogScale,
          title: AppLocalizations.of(context)!.failure,
          content: content,
        );
      },
    );
  }

  Future<bool> _validateStrokes(Map<int, List<String>> cellImages) async {
    final required = widget.nowStep.essentialStrokeCounts!;
    final localizations = AppLocalizations.of(context)!;
    for (var cell = 0; cell < required.length; cell++) {
      final actual = cellImages[cell]?.length ?? 0;
      if (actual != required[cell]) {
        await _showStrokeErrorDialog(
          actual > required[cell]
              ? localizations.tooManyStrokes
              : localizations.notEnoughStrokes,
        );
        return false;
      }
    }
    return true;
  }

  List<int?> _buildTextIndexToResultMap(List<Map<String, dynamic>> results) {
    final required = widget.nowStep.essentialStrokeCounts!;
    final mapping = List<int?>.filled(required.length, null);
    final writableCells = [
      for (var cell = 0; cell < required.length; cell++)
        if (required[cell] > 0) cell,
    ];

    // Older servers return results in writing order without cell indexes.
    if (results.every((result) => !result.containsKey('cell_index'))) {
      if (results.length == writableCells.length) {
        for (var i = 0; i < results.length; i++) {
          mapping[writableCells[i]] = i;
        }
      }
      return mapping;
    }

    for (var i = 0; i < results.length; i++) {
      final cell = results[i]['cell_index'];
      if (cell is int &&
          cell >= 0 &&
          cell < required.length &&
          required[cell] > 0) {
        mapping[cell] = i;
      }
    }
    return mapping;
  }

  Future<void> _submitWritingData(
    Map<int, List<String>> encodedImages,
    Map<int, List<Offset>> endpoints,
  ) async {
    // Create result model
    final resultCreate = {
      'user_id': context.read<LoginStatus>().userId,
      'step_id': widget.nowStep.stepId,
      'practice_text': widget.nowStep.stepText,
      'cell_images': _stringKeyMap3(encodedImages),
      'firstandlast_stroke': endpoints.map(
        (key, list) => MapEntry(
          key.toString(),
          list.map((off) => {'x': off.dx, 'y': off.dy}).toList(),
        ),
      ),
      'detailed_strokecounts': _stringKeyMap(
        widget.nowStep.detailedStrokeCounts ?? {},
      ),
      'user_type': context.read<LoginStatus>().userType?.name,
    };
    final res = await api.submitResult(resultCreate);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final decoded = utf8.decode(res.bodyBytes);
      final Map<String, dynamic> data = jsonDecode(decoded);
      final List<Map<String, dynamic>> resultsList =
          ((data['results'] as List?) ?? const [])
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();

      // 제출 성공 후 결과 저장 + 열람 가능 플래그 켜기
      setState(() {
        _letterResults = resultsList;
        _textIndexToResult = _buildTextIndexToResultMap(resultsList);
        _feedbackReady = true;
      });

      // 1) 평균 점수(실수 그대로)
      final double? avgScore = (data['avg_score'] as num?)?.toDouble();

      // If avgScore is over 60, refresh mission records
      if (avgScore != null && avgScore >= 60) {
        if (mounted) {
          Provider.of<DataProvider>(
            context,
            listen: false,
          ).refreshMissionRecords(context.read<LoginStatus>().userId!);
        }
      }

      final stages = <String>[];
      var cell = 0;
      for (final character in widget.nowStep.stepText.characters) {
        final resultIndex = _textIndexToResult[cell];
        stages.add(
          resultIndex == null
              ? '0000'
              : (resultsList[resultIndex]['stage'] as String?) ?? '0000',
        );
        cell += character.length;
      }

      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => FeedbackDialog(
              avgScore: avgScore,
              fullText: widget.nowStep.stepText,
              stages: stages,
              imagePath: widget.nowStep.stepCharacter,
            ),
      );
    } else {
      String errorMessage = '평가 서버에 접속할 수 없습니다. (코드: ${res.statusCode})';
      try {
        final decoded = utf8.decode(res.bodyBytes);
        final Map<String, dynamic> errorData = jsonDecode(decoded);
        if (errorData.containsKey('detail')) {
          errorMessage = errorData['detail'];
        } else if (errorData.containsKey('message')) {
          errorMessage = errorData['message'];
        }
      } catch (_) {
        // Ignore if body is not valid JSON or doesn't contain a message.
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _isPoppingPage || _feedbackReady) return;
    final appLocalizations = AppLocalizations.of(context)!;
    final canvas = _canvasKey.currentState;
    if (canvas == null) return;

    setState(() => _isSubmitting = true);
    _stopTimer();

    try {
      final submission = await canvas.captureSubmission();
      if (!mounted) return;
      final encodedImages = _encodeImages(submission.imagesByCell);
      if (!await _validateStrokes(encodedImages) || !mounted) return;
      if (encodedImages.isEmpty) return;

      await _submitWritingData(encodedImages, submission.endpointsByCell);
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(appLocalizations.error),
              content: Text('평가 전송 중 오류가 발생했습니다: $error'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(appLocalizations.ok),
                ),
              ],
            ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (!_feedbackReady) _startTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context)!;
    final usertype = context.read<LoginStatus>().userType;
    final double cellSize = switch (widget.nowStep.stepType) {
      WritingType.SENTENCE => 103.5,
      WritingType.WORD => 200,
      WritingType.PHONEME => 200,
      WritingType.FREE => 200,
    };
    //10자 이하 문장에서 중앙에 위치하기 위한 boolean 변수
    bool isBelow10Sentence =
        (widget.nowStep.stepText.length <= 10 &&
            widget.nowStep.stepType == WritingType.SENTENCE);

    // Calculate grid width to match practice box
    final int colCount =
        widget.nowStep.stepText.length < 10
            ? widget.nowStep.stepText.length
            : 10;
    final double gridWidth = scaled(context, cellSize) * colCount;
    final int totalChars = widget.nowStep.stepText.length;
    final int rowCount = (totalChars / 10).ceil();
    final double gridHeight = scaled(context, cellSize) * rowCount;

    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            //container가 벗어난 부분의 경계선을 부드럽게 잘라냄
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.canvas),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(53, 5, 53, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                //부모 Column의 너비에 맞춰 자식들이 폭을 꽉 채워서 렌더링됩니다.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 뒤로 가기 버튼 및 타이머
                  SizedBox(
                    height: scaled(context, 60),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BackButtonWidget(scale: 1),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: scaled(context, 200),
                            height: scaled(context, 60),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary,
                              borderRadius: BorderRadius.circular(
                                scaled(context, 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: scaled(context, 6),
                                  offset: Offset(0, scaled(context, 3)),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _formatTime(_remainingTime),
                              style: TextStyle(
                                fontSize: scaled(context, 35),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: scaled(context, 20)),

                  SpeechBubble(
                    text:
                        usertype == UserType.FOREIGN
                            ? "Write the text within the time limit."
                            : widget.nowStep.stepMission,
                    imageAsset: widget.nowStep.stepCharacter,
                    scale: scaled(context, 0.65),
                    horizontalInset: scaled(context, 80),
                    imageRight: -30,
                  ),

                  SizedBox(height: scaled(context, 50)),

                  // 연습과제 박스
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: scaled(context, 100),
                      ),
                      width: gridWidth,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary,
                          width: scaled(context, 5),
                        ),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: scaled(context, 6),
                            offset: Offset(0, scaled(context, 3)),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.nowStep.stepText,
                        style: TextStyle(
                          fontSize: scaled(context, 45),
                          fontFamily: AppFonts.reading,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height:
                        isBelow10Sentence
                            ? scaled(context, 81.75)
                            : scaled(context, 30),
                  ),

                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: gridWidth,
                      height: gridHeight,
                      child: Stack(
                        children: [
                          // 1) 캔버스는 피드백 준비되면 포인터 차단!
                          AbsorbPointer(
                            absorbing: _isSubmitting || _feedbackReady,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanDown: (_) {}, // 스크롤 방지 유지
                              onVerticalDragUpdate: (_) {},
                              child: GridHandwritingCanvas(
                                key: _canvasKey,
                                essentialStrokeCounts:
                                    widget.nowStep.essentialStrokeCounts,
                                charCount: widget.nowStep.stepText.length,
                                gridColor: AppColors.tertiary,
                                gridWidth: scaled(context, 3),
                                cellSize: scaled(context, cellSize),
                                showGuides: widget.showGuides,
                                guideChar: widget.nowStep.stepText,
                                penStrokeWidth: _penStrokeWidth,
                              ),
                            ),
                          ),

                          // 2) 피드백 준비된 경우에만 탭을 가로채는 "투명 레이어"
                          if (_feedbackReady)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                // 드래그 제스처까지 먹어버리기 (아래로 안 내려가게)
                                onPanDown: (_) {},
                                onPanStart: (_) {},
                                onPanUpdate: (_) {},
                                onPanEnd: (_) {},
                                // 탭 좌표로 셀 인덱스 계산
                                onTapDown: (details) {
                                  final double cs = scaled(context, cellSize);
                                  final dx = details.localPosition.dx;
                                  final dy = details.localPosition.dy;

                                  final int col = (dx ~/ cs).clamp(
                                    0,
                                    colCount - 1,
                                  );
                                  final int row = (dy ~/ cs).clamp(
                                    0,
                                    rowCount - 1,
                                  );

                                  final index = row * colCount + col;
                                  if (index >= totalChars) return; // 빈 칸은 무시
                                  if (_textIndexToResult.isEmpty ||
                                      index >= _textIndexToResult.length) {
                                    return;
                                  }
                                  final mapped = _textIndexToResult[index];
                                  if (mapped == null ||
                                      mapped >= _letterResults.length) {
                                    return;
                                  }
                                  _showLetterFeedback(mapped);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        isBelow10Sentence
                            ? scaled(context, 81.75)
                            : scaled(context, 30),
                  ),

                  // Pen thickness slider
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: scaled(context, 50),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${appLocalizations.penThickness} ${_penStrokeWidth.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: scaled(context, 20)),
                        ),
                        Expanded(
                          child: Slider(
                            value: _penStrokeWidth,
                            min: _minPenStrokeWidth,
                            max: _maxPenStrokeWidth,
                            divisions:
                                (_maxPenStrokeWidth - _minPenStrokeWidth)
                                    .toInt() *
                                2, // 0.5 increments
                            label: _penStrokeWidth.toStringAsFixed(1),
                            onChanged: (double value) {
                              setState(() {
                                _penStrokeWidth = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: scaled(context, 10)), // Add some spacing

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isSubmitting ||
                                _isPoppingPage ||
                                _feedbackReady) {
                              return;
                            }
                            _canvasKey.currentState?.undoLastStroke();
                          },
                          child: Container(
                            width: scaled(context, 230),
                            height: scaled(context, 80),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                scaled(context, 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: scaled(context, 6),
                                  offset: Offset(0, scaled(context, 3)),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              appLocalizations.eraseOneStroke,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: scaled(context, 30),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: scaled(context, 35)),
                        GestureDetector(
                          onTap: () {
                            if (_isSubmitting || _isPoppingPage) return;
                            _stopTimer(); // 타이머 멈춤
                            _canvasKey.currentState?.clearAll(); // 글씨 지우기
                            setState(() {
                              _feedbackReady = false; // ⬅ 오버레이/탭 가로채기 비활성화
                              _letterResults = []; // ⬅ (선택) 이전 결과도 비우기
                              _remainingTime =
                                  widget.nowStep.stepTime; // 시간 초기화
                            });
                            _startTimer(); // 타이머 재시작
                          },
                          child: Container(
                            width: scaled(context, 230),
                            height: scaled(context, 80),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                scaled(context, 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: scaled(context, 6),
                                  offset: Offset(0, scaled(context, 3)),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              appLocalizations.eraseAll,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: scaled(context, 30),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: scaled(context, 35)),
                        GestureDetector(
                          onTap:
                              _isSubmitting || _feedbackReady
                                  ? null
                                  : _handleSubmit,
                          child: Container(
                            width: scaled(context, 230),
                            height: scaled(context, 80),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                scaled(context, 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: scaled(context, 6),
                                  offset: Offset(0, scaled(context, 3)),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child:
                                _isSubmitting && !_feedbackReady
                                    ? const CircularProgressIndicator()
                                    : Text(
                                      appLocalizations.submit,
                                      style: TextStyle(
                                        fontSize: scaled(context, 30),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                        SizedBox(width: scaled(context, 35)),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                final double dialogScale = scaled(context, 2);
                                return MiniDialog(
                                  scale: dialogScale,
                                  title: appLocalizations.help,
                                  content:
                                      usertype == UserType.FOREIGN
                                          ? "Keep the shapes clear and balanced."
                                          : widget.nowStep.stepTip,
                                );
                              },
                            );
                          },
                          child: Container(
                            width: scaled(context, 230),
                            height: scaled(context, 80),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                scaled(context, 12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: scaled(context, 6),
                                  offset: Offset(0, scaled(context, 3)),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              appLocalizations.viewHint,
                              style: TextStyle(
                                fontSize: scaled(context, 30),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: scaled(context, 20)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
