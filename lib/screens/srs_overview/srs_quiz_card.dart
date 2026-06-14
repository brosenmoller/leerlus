import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/question_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/srs_overview/srs_tag.dart';

// ── Popup menu actions ────────────────────────────────────────────────────────

enum SrsCardAction { startNormal, removeSrs }

// ── Data class ────────────────────────────────────────────────────────────────

class SrsQuizEntry {
  final QuizData quiz;
  final String quizTitle;
  final String? folderTitle;
  final List<QuestionData> dueQuestions;
  final List<QuestionData> allQuestions;
  final DateTime? oldestDue;
  final DateTime nextUpcoming;

  const SrsQuizEntry({
    required this.quiz,
    required this.quizTitle,
    required this.folderTitle,
    required this.dueQuestions,
    required this.allQuestions,
    required this.oldestDue,
    required this.nextUpcoming,
  });
}

// ── Card widget ───────────────────────────────────────────────────────────────

class SrsQuizCard extends StatelessWidget {
  final SrsQuizEntry entry;
  final void Function(BuildContext, List<QuestionData>, String) onStart;
  final void Function(BuildContext, QuizData) onStartNormal;
  final void Function(BuildContext, SrsQuizEntry) onRemoveSrs;

  /// Whether to show the parent-folder tag. Hidden in folder view where the
  /// quiz already sits visually inside its folder.
  final bool showFolderTag;

  const SrsQuizCard({
    super.key,
    required this.entry,
    required this.onStart,
    required this.onStartNormal,
    required this.onRemoveSrs,
    this.showFolderTag = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasDue = entry.dueQuestions.isNotEmpty;

    final accentColor =
        hasDue ? colorScheme.error : colorScheme.outlineVariant;

    final Color timeColor =
        hasDue ? colorScheme.error : colorScheme.outline;

    // Use screen width as the breakpoint — avoids LayoutBuilder inside
    // IntrinsicHeight, which Flutter does not support.
    final wide = MediaQuery.sizeOf(context).width > 450;

    final String timeLabel;
    if (hasDue) {
      final overdue = DateTime.now().difference(entry.oldestDue!);
      timeLabel = wide
          ? l10n.srsOldestOverdue(_fmt(overdue, l10n))
          : _fmt(overdue, l10n);
    } else {
      final until = entry.nextUpcoming.difference(DateTime.now());
      timeLabel = l10n.srsNextIn(_fmt(until, l10n));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: hasDue ? 2 : 1,
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar
              Container(width: 4, color: accentColor),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title — always on its own line so it never wraps into the buttons
                      Text(
                        entry.quizTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      // Tags + action buttons on the same row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tags
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (showFolderTag && entry.folderTitle != null)
                                  SrsTag(
                                    label: entry.folderTitle!,
                                    icon: Icons.folder_outlined,
                                    color: colorScheme.secondary,
                                  ),
                                SrsTag(
                                  label: hasDue
                                      ? l10n.srsDue(entry.dueQuestions.length)
                                      : l10n.srsCards(entry.allQuestions.length),
                                  icon: hasDue
                                      ? Icons.schedule
                                      : Icons.style_outlined,
                                  color: hasDue
                                      ? colorScheme.error
                                      : colorScheme.outline,
                                ),
                                SrsTag(
                                  label: timeLabel,
                                  color: timeColor,
                                ),
                              ],
                            ),
                          ),

                          // Action buttons
                          const SizedBox(width: 8),
                          if (hasDue)
                            FilledButton(
                              onPressed: () => onStart(
                                  context,
                                  entry.dueQuestions,
                                  entry.quizTitle),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              child: Text(l10n.start),
                            ),
                          PopupMenuButton<SrsCardAction>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (action) {
                              if (action == SrsCardAction.startNormal) {
                                onStartNormal(context, entry.quiz);
                              } else if (action == SrsCardAction.removeSrs) {
                                onRemoveSrs(context, entry);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: SrsCardAction.startNormal,
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.play_arrow_outlined),
                                  title: Text(l10n.srsStartNormalQuiz),
                                  subtitle: Text(l10n.srsNoSrsScheduling),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: SrsCardAction.removeSrs,
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red),
                                  title: Text(l10n.srsRemoveFromSrs,
                                      style: const TextStyle(
                                          color: Colors.red)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d, AppLocalizations l10n) {
    if (d.inDays > 0) return l10n.durationDays(d.inDays);
    if (d.inHours > 0) return l10n.durationHours(d.inHours);
    if (d.inMinutes > 0) return l10n.durationMinutes(d.inMinutes);
    final secs = d.inSeconds;
    if (secs > 0) return l10n.durationSeconds(secs);
    return l10n.durationNow;
  }
}
