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
                        SrsTag(
                          label: hasDue
                              ? l10n.srsDue(dueCount)
                              : l10n.srsCards(node.totalCardsRecursive),
                          icon: hasDue
                              ? Icons.schedule
                              : Icons.style_outlined,
                          color:
                              hasDue ? colorScheme.error : colorScheme.outline,
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
}
