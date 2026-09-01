import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_data.dart';
import 'package:leerlus/screens/srs_overview/srs_tag.dart';
import 'package:leerlus/services/settings_service.dart';

/// A tappable folder row. Tapping opens the folder's contents in a subscreen.
class SrsFolderCard extends StatelessWidget {
  final SrsFolderNode node;
  final VoidCallback onTap;

  /// Reviews the due questions in this folder and all of its descendants
  /// (scrambled). Wired to the card's Review button when anything is due.
  /// [quick] asks for a capped, bite-size session instead of the whole pile.
  final void Function({bool quick}) onReview;

  const SrsFolderCard({
    super.key,
    required this.node,
    required this.onTap,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final dueCount = node.allDueRecursive.length;
    final hasDue = dueCount > 0;

    final accentColor =
        hasDue ? colorScheme.error : colorScheme.outlineVariant;

    final Color timeColor = hasDue ? colorScheme.error : colorScheme.outline;

    // Use screen width as the breakpoint — avoids LayoutBuilder inside
    // IntrinsicHeight, which Flutter does not support.
    final wide = MediaQuery.sizeOf(context).width > 450;

    String? timeLabel;
    if (hasDue) {
      final oldestDue = node.oldestDueRecursive;
      if (oldestDue != null) {
        final overdue = DateTime.now().difference(oldestDue);
        timeLabel = wide
            ? l10n.srsOldestOverdue(_fmt(overdue, l10n))
            : _fmt(overdue, l10n);
      }
    } else {
      final next = node.nextUpcomingRecursive;
      if (next != null) {
        final until = next.difference(DateTime.now());
        timeLabel = l10n.srsNextIn(_fmt(until, l10n));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: hasDue ? 2 : 1,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Icon(Icons.folder_rounded,
                      color: colorScheme.secondary),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          node.folder.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            SrsTag(
                              label: hasDue
                                  ? l10n.srsDue(dueCount)
                                  : l10n.srsCards(node.totalCardsRecursive),
                              icon: hasDue
                                  ? Icons.schedule
                                  : Icons.style_outlined,
                              color: hasDue
                                  ? colorScheme.error
                                  : colorScheme.outline,
                            ),
                            if (timeLabel != null)
                              SrsTag(
                                label: timeLabel,
                                color: timeColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasDue)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _buildStartButtons(colorScheme, l10n, dueCount),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mirrors [SrsQuizCard]: a single Start normally, splitting into a capped
  /// quick session plus a secondary review-all only when the folder's due pile
  /// exceeds a quick session.
  Widget _buildStartButtons(
      ColorScheme colorScheme, AppLocalizations l10n, int dueCount) {
    final settings = SettingsService();
    final batchSize = settings.srsBatchSize;
    final split = settings.quickReviewEnabled && dueCount > batchSize;

    if (!split) {
      return FilledButton(
        onPressed: () => onReview(quick: false),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: Text(l10n.start),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l10n.srsQuickReviewTooltip(batchSize),
          child: FilledButton(
            onPressed: () => onReview(quick: true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              // Left padding is trimmed to offset the bolt glyph's own side
              // bearing, so the gap reads equal on both sides of the pill.
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 20),
                Text('$batchSize'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: l10n.srsReviewAllTooltip(dueCount),
          onPressed: () => onReview(quick: false),
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ],
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
