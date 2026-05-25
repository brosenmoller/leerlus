import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/streak_service.dart';

/// Displays a contextual streak result after completing a quiz or SRS session.
/// Returns an empty widget for [StreakEvent.disabled] and [StreakEvent.sameDay].
class StreakBanner extends StatelessWidget {
  final StreakEvent event;

  const StreakBanner({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    if (event == StreakEvent.disabled || event == StreakEvent.sameDay) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final state = StreakService().streakNotifier.value;

    final IconData icon;
    final Color color;
    final String title;
    final String body;

    switch (event) {
      case StreakEvent.continued:
        icon = Icons.local_fire_department;
        color = Colors.deepOrange;
        title = l10n.streakContinued;
        body = l10n.streakContinuedBody(state.streakCount);
      case StreakEvent.freezeUsed:
        icon = Icons.ac_unit;
        color = Colors.blue;
        title = l10n.streakFreezeUsed;
        body = l10n.streakFreezeUsedBody(state.freezesRemaining);
      case StreakEvent.reset:
        icon = Icons.local_fire_department_outlined;
        color = Colors.grey;
        title = l10n.streakReset;
        body = l10n.streakResetBody;
      default:
        return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
