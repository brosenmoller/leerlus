import 'package:leerlus/models/answer_type.dart' show AnswerType;
import 'package:leerlus/models/question_data.dart';

/// Returns a randomly ordered copy of [questions] with one light constraint:
/// two back-to-back flashcards never have the first card's **back** side equal
/// to the second card's **front** side (which would reveal the answer early).
///
/// Cost is effectively linear. We shuffle once, then place cards greedily;
/// the only extra work happens when a conflict is actually encountered, which
/// is rare. Front/back keys are short strings normalized on demand, so even
/// thousands of questions stay comfortably under a frame — no lag.
List<QuestionData> scrambleQuestions(List<QuestionData> questions) {
  final pool = List<QuestionData>.of(questions)..shuffle();
  final n = pool.length;
  if (n < 2) return pool;

  String? frontKey(QuestionData q) {
    if (q.answerType != AnswerType.flashcard) return null;
    final t = q.flashcardConfig?.frontText?.trim().toLowerCase();
    return (t == null || t.isEmpty) ? null : t;
  }

  String? backKey(QuestionData q) {
    if (q.answerType != AnswerType.flashcard) return null;
    final t = q.flashcardConfig?.backText?.trim().toLowerCase();
    return (t == null || t.isEmpty) ? null : t;
  }

  // Greedy placement over the shuffled pool. Elements in [0, start) are placed;
  // [start, n) is the active region. "Consuming" an element swaps it to `start`
  // and advances `start`, so removal is O(1) and order stays random.
  final result = <QuestionData>[];
  String? prevBack;
  for (int start = 0; start < n; start++) {
    int pick = start;
    if (prevBack != null) {
      // Find the first remaining card that doesn't continue the chain. If every
      // remaining card conflicts (unavoidable), we fall back to `start`.
      for (int k = start; k < n; k++) {
        if (frontKey(pool[k]) != prevBack) {
          pick = k;
          break;
        }
      }
    }
    final chosen = pool[pick];
    pool[pick] = pool[start];
    pool[start] = chosen;
    result.add(chosen);
    prevBack = backKey(chosen);
  }
  return result;
}
