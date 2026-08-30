import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/screens/manage_content_screens/manage_questions_screen.dart';

/// Opening the screen from the content search must land on the question that
/// was tapped.
///
/// The list is a lazy `ListView.builder`, so a target below the fold has no
/// element yet when the first frame settles — `Scrollable.ensureVisible` alone
/// silently did nothing and the user was dropped at the top of the quiz.
void main() {
  late AppDatabase db;
  late Quiz quiz;
  late List<String> questionIds;


  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final folderId = await db.insertFolder(
        const FoldersCompanion(id: Value('folder-1'), title: Value('F')));
    final quizId = await db.insertQuiz(QuizzesCompanion(
      id: const Value('quiz-1'),
      title: const Value('Quiz'),
      folderId: Value(folderId),
    ));
    questionIds = [];
    for (var i = 0; i < 40; i++) {
      questionIds.add(await db.insertQuestionIntoQuiz(
        quizId: quizId,
        question: QuestionsCompanion(
          id: Value('q-$i'),
          questionText: Value('Question $i'),
          answerType: const Value('typed'),
          answerConfig: const Value('{"acceptedAnswers":["a"]}'),
        ),
      ));
    }
    quiz = (await db.getQuizById(quizId))!;
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(WidgetTester tester, {String? highlightId}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ManageQuestionsScreen(
        db: db,
        quiz: quiz,
        highlightQuestionId: highlightId,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Whether the widget is actually inside the viewport, not merely built
  /// because it sits in the sliver's cache extent.
  bool onScreen(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    return rect.bottom > 0 && rect.top < screen.height;
  }

  testWidgets('scrolls a question far down the list into view',
      (tester) async {
    await pumpScreen(tester, highlightId: questionIds[35]);

    expect(find.text('Question 35'), findsOneWidget);
    expect(onScreen(tester, find.text('Question 35')), isTrue);
  });

  testWidgets('scrolls to the last question', (tester) async {
    await pumpScreen(tester, highlightId: questionIds.last);

    expect(find.text('Question 39'), findsOneWidget);
    expect(onScreen(tester, find.text('Question 39')), isTrue);
  });

  testWidgets('leaves the list at the top for a question already visible',
      (tester) async {
    await pumpScreen(tester, highlightId: questionIds.first);

    expect(onScreen(tester, find.text('Question 0')), isTrue);
    expect(tester.widget<Scrollable>(find.byType(Scrollable).first).controller
        ?.position.pixels, 0.0);
  });

  testWidgets('opens at the top when no question was requested',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Question 0'), findsOneWidget);
    expect(find.text('Question 35'), findsNothing);
  });
}
