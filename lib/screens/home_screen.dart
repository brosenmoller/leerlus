import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/screens/folder_browser_screen.dart';
import 'package:leerlus/screens/manage_content_screens/manage_content_screen.dart';
import 'package:leerlus/screens/settings_screen.dart';
import 'package:leerlus/screens/favorites_screen.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/screens/srs_overview/srs_overview_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

  void _showStreakInfo(BuildContext context, StreakState state, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final nextMonday = currentMonday.add(const Duration(days: 7));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final restockStr = 'Mon ${months[nextMonday.month - 1]} ${nextMonday.day}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.streakInfoTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: state.completedToday ? Colors.orange : Colors.grey, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.streakCount(state.streakCount),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Colors.amber.shade600, size: 22),
                const SizedBox(width: 10),
                Text(
                  l10n.streakBest(state.highestStreak),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.ac_unit_rounded, color: Colors.lightBlue.shade300, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.streakFreezesRemaining(state.freezesRemaining),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.streakFreezesRestockOn(restockStr),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: colorScheme.primary,
            leadingWidth: 80,
            leading: ValueListenableBuilder<StreakState>(
              valueListenable: StreakService().streakNotifier,
              builder: (context, state, _) {
                if (!state.streakEnabled) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showStreakInfo(context, state, l10n),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.usedFreezeYesterday
                                  ? Icons.ac_unit_rounded
                                  : Icons.local_fire_department,
                              color: state.usedFreezeYesterday
                                  ? Colors.lightBlue.shade300
                                  : state.completedToday
                                      ? Colors.orange
                                      : Colors.white38,
                              size: 20,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${state.streakCount}',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings, color: colorScheme.onPrimary),
                tooltip: l10n.settingsTooltip,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(db: db)),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                l10n.appTitle,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, bottom: 32),
                    child: Icon(
                      Icons.biotech_rounded,
                      size: 100,
                      color: colorScheme.onPrimary.withOpacity(0.12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      _NavTile(
                        title: l10n.navBrowse,
                        subtitle: l10n.navBrowseSubtitle,
                        icon: Icons.folder_open_rounded,
                        color: colorScheme.primaryContainer,
                        iconColor: colorScheme.onPrimaryContainer,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FolderBrowserScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        title: l10n.navSpacedRepetition,
                        subtitle: l10n.navSpacedRepetitionSubtitle,
                        icon: Icons.auto_awesome_rounded,
                        color: colorScheme.errorContainer,
                        iconColor: colorScheme.onErrorContainer,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SrsOverviewScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        title: l10n.navFavorites,
                        subtitle: l10n.navFavoritesSubtitle,
                        icon: Icons.star_rounded,
                        color: colorScheme.secondaryContainer,
                        iconColor: colorScheme.onSecondaryContainer,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FavoritesScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        title: l10n.navManageContent,
                        subtitle: l10n.navManageContentSubtitle,
                        icon: Icons.edit_note_rounded,
                        color: colorScheme.tertiaryContainer,
                        iconColor: colorScheme.onTertiaryContainer,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ManageContentScreen(db: db)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: iconColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: iconColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
