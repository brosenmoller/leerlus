import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/settings_service.dart';

/// The review FAB shared by the SRS overview and folder screens.
///
/// Mirrors the card rule: normally a single "Review all" button, but when the
/// due pile is bigger than a quick session it promotes a capped quick review to
/// the primary extended FAB and demotes review-all to a small FAB above it.
class SrsReviewFab extends StatelessWidget {
  final int dueCount;

  /// [quick] asks for a capped, bite-size session instead of the whole pile.
  final void Function({bool quick}) onReview;

  /// Distinguishes the two FABs' hero animations from any other route's.
  final String heroPrefix;

  const SrsReviewFab({
    super.key,
    required this.dueCount,
    required this.onReview,
    required this.heroPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final settings = SettingsService();
    final batchSize = settings.srsBatchSize;
    final split = settings.quickReviewEnabled && dueCount > batchSize;

    if (!split) {
      return FloatingActionButton.extended(
        heroTag: '$heroPrefix-all',
        onPressed: () => onReview(quick: false),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(l10n.srsReviewAll),
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: '$heroPrefix-all',
          tooltip: l10n.srsReviewAllTooltip(dueCount),
          onPressed: () => onReview(quick: false),
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundColor: colorScheme.onSurfaceVariant,
          child: const Icon(Icons.play_arrow_rounded),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: '$heroPrefix-quick',
          onPressed: () => onReview(quick: true),
          icon: const Icon(Icons.bolt),
          label: Text(l10n.srsQuickReviewLabel(batchSize)),
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
      ],
    );
  }
}
