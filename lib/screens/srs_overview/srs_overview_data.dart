import 'package:leerlus/models/folder_data.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/screens/srs_overview/srs_quiz_card.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';

// ── Folder tree node ──────────────────────────────────────────────────────────

/// A folder that contains — directly or somewhere below it — at least one quiz
/// with SRS-enabled questions. Built by [buildSrsFolderNode].
class SrsFolderNode {
  final FolderData folder;
  final List<SrsFolderNode> subfolders;
  final List<SrsQuizEntry> quizEntries;

  const SrsFolderNode({
    required this.folder,
    required this.subfolders,
    required this.quizEntries,
  });

  /// Every due question in this folder and all of its descendants.
  List<QuestionData> get allDueRecursive => [
        ...quizEntries.expand((e) => e.dueQuestions),
        ...subfolders.expand((s) => s.allDueRecursive),
      ];

  /// Every SRS question in this folder and all of its descendants.
  int get totalCardsRecursive =>
      quizEntries.fold<int>(0, (sum, e) => sum + e.allQuestions.length) +
      subfolders.fold<int>(0, (sum, s) => sum + s.totalCardsRecursive);
}

// ── Builders ──────────────────────────────────────────────────────────────────

/// Computes one [SrsQuizEntry] per quiz that has at least one SRS-enabled
/// question. Sorted: due entries first (most overdue on top), then upcoming
/// (soonest first).
List<SrsQuizEntry> computeSrsEntries(
  QuestionService questionService,
  SrsService srsService,
) {
  final entries = <SrsQuizEntry>[];

  for (final quiz in questionService.getAllQuizzes()) {
    final questions = quiz.questionIds
        .map((id) => questionService.getQuestion(id))
        .whereType<QuestionData>()
        .where((q) => srsService.getUserData(q).spacedRepetitionEnabled)
        .toList();

    if (questions.isEmpty) continue;

    final dueQuestions =
        questions.where((q) => srsService.getUserData(q).isDue).toList();

    final dueDates =
        dueQuestions.map((q) => srsService.getUserData(q).nextReview);

    final DateTime? oldestDue = dueQuestions.isEmpty
        ? null
        : dueDates.reduce((a, b) => a.isBefore(b) ? a : b);

    final upcomingDates =
        questions.map((q) => srsService.getUserData(q).nextReview);
    final DateTime nextUpcoming =
        upcomingDates.reduce((a, b) => a.isBefore(b) ? a : b);

    final folderTitle = quiz.parentFolderId != null
        ? questionService.getFolder(quiz.parentFolderId!)?.title
        : null;

    entries.add(SrsQuizEntry(
      quiz: quiz,
      quizTitle: quiz.title,
      folderTitle: folderTitle,
      dueQuestions: dueQuestions,
      allQuestions: questions,
      oldestDue: oldestDue,
      nextUpcoming: nextUpcoming,
    ));
  }

  entries.sort((a, b) {
    final aDue = a.oldestDue != null;
    final bDue = b.oldestDue != null;
    if (aDue && bDue) return a.oldestDue!.compareTo(b.oldestDue!);
    if (aDue) return -1;
    if (bDue) return 1;
    return a.nextUpcoming.compareTo(b.nextUpcoming);
  });

  return entries;
}

/// Builds a folder node, or null if neither the folder nor any descendant
/// contains an SRS quiz.
SrsFolderNode? buildSrsFolderNode(
  QuestionService questionService,
  FolderData folder,
  Map<String, SrsQuizEntry> entryByQuizId,
) {
  final subfolders = <SrsFolderNode>[];
  for (final sub in questionService.getSubfolders(folder.id)) {
    final node = buildSrsFolderNode(questionService, sub, entryByQuizId);
    if (node != null) subfolders.add(node);
  }

  final quizEntries = <SrsQuizEntry>[];
  for (final quiz in questionService.getQuizzesInFolder(folder.id)) {
    final entry = entryByQuizId[quiz.id];
    if (entry != null) quizEntries.add(entry);
  }

  if (subfolders.isEmpty && quizEntries.isEmpty) return null;

  return SrsFolderNode(
    folder: folder,
    subfolders: subfolders,
    quizEntries: quizEntries,
  );
}
