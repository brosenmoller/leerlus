import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_data.dart';
import 'package:leerlus/screens/srs_overview/srs_tag.dart';

/// A tappable folder row. Tapping opens the folder's contents in a subscreen.
class SrsFolderCard extends StatelessWidget {
  final SrsFolderNode node;
  final VoidCallback onTap;

  /// Reviews every due question in this folder and all of its descendants
  /// (scrambled). Wired to the card's Review button when anything is due.
  final VoidCallback onReview;

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
                      child: FilledButton(
                        onPressed: onReview,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text(l10n.start),
                      ),
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

  String _fmt(Duration d, AppLocalizations l10n) {
    if (d.inDays > 0) return l10n.durationDays(d.inDays);
    if (d.inHours > 0) return l10n.durationHours(d.inHours);
    if (d.inMinutes > 0) return l10n.durationMinutes(d.inMinutes);
    final secs = d.inSeconds;
    if (secs > 0) return l10n.durationSeconds(secs);
    return l10n.durationNow;
  }
}
