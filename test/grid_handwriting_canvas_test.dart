import 'dart:convert';
import 'dart:ui';

import 'package:aiwriting_collection/api.dart';
import 'package:aiwriting_collection/generated/app_localizations.dart';
import 'package:aiwriting_collection/model/common/type_enum.dart';
import 'package:aiwriting_collection/model/content/steps.dart';
import 'package:aiwriting_collection/model/provider/login_status.dart';
import 'package:aiwriting_collection/screen/home/writing_page.dart';
import 'package:aiwriting_collection/widget/dialog/feedback_dialog.dart';
import 'package:aiwriting_collection/widget/writing/grid_handwriting_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Future<Offset> mountCanvas(
  WidgetTester tester,
  GlobalKey<GridHandwritingCanvasState> key,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: GridHandwritingCanvas(
          key: key,
          charCount: 4,
          maxPerRow: 2,
          guideChar: '가 나 ',
          essentialStrokeCounts: const [1, 0, 1, 0],
        ),
      ),
    ),
  );
  return tester.getTopLeft(find.byKey(key));
}

void main() {
  testWidgets('ignores taps, other pointers and cancelled strokes', (
    tester,
  ) async {
    final key = GlobalKey<GridHandwritingCanvasState>();
    final origin = await mountCanvas(tester, key);
    final canvas = key.currentState!;
    final start = origin + const Offset(8, 8);

    await tester.tapAt(start);
    expect(canvas.strokes, isEmpty);

    final pen = await tester.startGesture(
      start,
      kind: PointerDeviceKind.stylus,
    );
    final finger = await tester.startGesture(start + const Offset(18, 18));
    await finger.moveBy(const Offset(4, 0));
    await finger.up();
    expect(canvas.strokes, isEmpty);
    expect(canvas.currentStrokePath, const [Offset(8, 8)]);

    await pen.moveBy(const Offset(8, 0));
    await pen.cancel();
    expect(canvas.strokes, isEmpty);
    expect(canvas.currentStrokePath, isEmpty);
    expect(canvas.activeCell, 0);
  });

  testWidgets('uses the same two-line cells for images, coordinates and undo', (
    tester,
  ) async {
    final key = GlobalKey<GridHandwritingCanvasState>();
    final origin = await mountCanvas(tester, key);
    final canvas = key.currentState!;

    await tester.dragFrom(origin + const Offset(8, 8), const Offset(16, 0));
    expect(canvas.activeCell, 2);
    await tester.dragFrom(origin + const Offset(8, 48), const Offset(16, 0));
    expect(canvas.activeCell, 4);

    final submission = await tester.runAsync(() async {
      final pending = canvas.captureSubmission();
      canvas.undoLastStroke();
      expect(canvas.activeCell, 2);
      return pending;
    });

    expect(submission!.imagesByCell.keys, [0, 2]);
    expect(submission.endpointsByCell.keys, [0, 2]);
    expect(submission.imagesByCell[2], hasLength(1));
    expect(submission.endpointsByCell[2], hasLength(2));
    expect(canvas.strokes.map((stroke) => stroke.cellIndex), [0]);
  });

  testWidgets('submits once and maps reversed results by cell index', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1500, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final requests = <Map<String, dynamic>>[];
    final api = Api(
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'avg_score': 50,
            'results': [
              {'cell_index': 10, 'original_text': 'ㄴ', 'stage': '1000'},
              {'cell_index': 0, 'original_text': 'ㄱ', 'stage': '0100'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create:
            (_) => LoginStatus(api: api)..setUser(
              userId: 1,
              uid: 'test',
              jwt: 'test',
              userType: UserType.CHILD,
            ),
        child: MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WritingPage(
            nowStep: Steps(
              stepId: 1,
              stepMission: '연습',
              stepCharacter: 'assets/character/bearTeacher.png',
              stepType: WritingType.SENTENCE,
              stepText: 'ㄱ         ㄴ',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final writingCanvas = find.byType(GridHandwritingCanvas);
    final topLeft = tester.getTopLeft(writingCanvas);
    final cellSize =
        tester.widget<GridHandwritingCanvas>(writingCanvas).cellSize;
    await tester.dragFrom(topLeft + const Offset(12, 12), const Offset(24, 0));
    await tester.dragFrom(
      topLeft + Offset(12, cellSize + 12),
      const Offset(24, 0),
    );
    await tester.pump();

    final submit = find.text('제출');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    // PNG rasterization completes on the engine thread, outside the fake clock.
    for (var frame = 0; frame < 100 && requests.isEmpty; frame++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(requests, hasLength(1));
    await tester.pumpAndSettle();
    expect((requests.single['cell_images'] as Map).keys, ['0', '10']);
    expect((requests.single['firstandlast_stroke'] as Map).keys, ['0', '10']);
    final feedback = tester.widget<FeedbackDialog>(find.byType(FeedbackDialog));
    expect(feedback.stages, ['0100', ...List.filled(9, '0000'), '1000']);
  });
}
