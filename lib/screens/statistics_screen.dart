import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/statistics_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final svc = StatisticsService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _TodayCard(svc: svc, l10n: l10n, cs: cs),
              const SizedBox(height: 12),
              _AllTimeCard(svc: svc, l10n: l10n, cs: cs),
              const SizedBox(height: 12),
              _ActivityChart(svc: svc, l10n: l10n, cs: cs),
              const SizedBox(height: 12),
              _AnswerTypesCard(svc: svc, l10n: l10n, cs: cs),
              const SizedBox(height: 12),
              _SrsQualityCard(svc: svc, l10n: l10n, cs: cs),
              const SizedBox(height: 12),
              _FunFactsCard(svc: svc, l10n: l10n, cs: cs),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────

Widget _statChip(String label, String value, ColorScheme cs) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
      ],
    ),
  );
}

String _pct(int correct, int total) {
  if (total == 0) return '—';
  return '${(correct / total * 100).round()}%';
}

// ── Today ─────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _TodayCard({required this.svc, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final today = svc.getTodayData();
    final answered = today?['answered'] ?? 0;
    final correct = today?['correct'] ?? 0;
    final sessions = today?['sessions'] ?? 0;

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsToday,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onPrimaryContainer)),
            const SizedBox(height: 16),
            if (today == null)
              Text(l10n.statsNoData,
                  style: TextStyle(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                      fontSize: 13))
            else
              Row(children: [
                _statChip(l10n.statsTotalAnswered, '$answered', cs),
                _statChip(l10n.statsAccuracy, _pct(correct, answered), cs),
                _statChip(l10n.statsTotalSessions, '$sessions', cs),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── All Time ──────────────────────────────────────────────────

class _AllTimeCard extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _AllTimeCard({required this.svc, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final totalAnswered = svc.getTotalAnswered();
    final totalCorrect = svc.getTotalCorrect();
    final totalSessions = svc.getTotalSessions();
    final bestDay = svc.getBestDayCount();

    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsAllTime,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSecondaryContainer)),
            const SizedBox(height: 16),
            if (totalAnswered == 0)
              Text(l10n.statsNoData,
                  style: TextStyle(
                      color: cs.onSecondaryContainer.withValues(alpha: 0.7),
                      fontSize: 13))
            else
              _AllTimeChips(
                totalAnswered: totalAnswered,
                totalCorrect: totalCorrect,
                totalSessions: totalSessions,
                bestDay: bestDay,
                l10n: l10n,
                cs: cs,
              ),
          ],
        ),
      ),
    );
  }
}

class _AllTimeChips extends StatelessWidget {
  final int totalAnswered, totalCorrect, totalSessions, bestDay;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _AllTimeChips({
    required this.totalAnswered,
    required this.totalCorrect,
    required this.totalSessions,
    required this.bestDay,
    required this.l10n,
    required this.cs,
  });

  Widget _chip(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondaryContainer)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSecondaryContainer.withValues(alpha: 0.7))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          _chip(l10n.statsTotalAnswered, '$totalAnswered'),
          _chip(l10n.statsAccuracy, _pct(totalCorrect, totalAnswered)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _chip(l10n.statsTotalSessions, '$totalSessions'),
          _chip(l10n.statsBestDay, '$bestDay'),
        ]),
      ],
    );
  }
}

// ── 7-Day Activity Chart ───────────────────────────────────────

class _ActivityChart extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _ActivityChart(
      {required this.svc, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final data = svc.getLast7DaysData();
    final locale = Localizations.localeOf(context).toString();

    final today = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final dt = today.subtract(Duration(days: 6 - i));
      return DateFormat.E(locale).format(dt);
    });

    return Card(
      elevation: 0,
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsActivity7Days,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onTertiaryContainer)),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(
                  data: data.map((d) => d['answered'] ?? 0).toList(),
                  barColor: cs.tertiary,
                  todayColor: cs.primary,
                  labelColor: cs.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: dayLabels.map((label) {
                return Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onTertiaryContainer.withValues(alpha: 0.7)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> data;
  final Color barColor;
  final Color todayColor;
  final Color labelColor;

  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.todayColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = max(data.fold(0, (a, b) => max(a, b)), 1);
    final slotWidth = size.width / data.length;
    final barWidth = slotWidth * 0.55;
    final availH = size.height - 20; // reserve 20px for label above bar

    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      final barH = (val / maxVal) * availH;
      final x = slotWidth * i + (slotWidth - barWidth) / 2;
      final y = size.height - barH;

      final isToday = i == data.length - 1;
      final paint = Paint()
        ..color = isToday ? todayColor : barColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      if (val > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$val',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: labelColor.withValues(alpha: 0.8)),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x + (barWidth - tp.width) / 2, y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.barColor != barColor;
}

// ── Answer Types ──────────────────────────────────────────────

class _AnswerTypesCard extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _AnswerTypesCard(
      {required this.svc, required this.l10n, required this.cs});

  String _label(String answerType, AppLocalizations l10n) {
    switch (answerType) {
      case 'multipleChoice':
        return l10n.answerTypeMCLabel;
      case 'typed':
        return l10n.answerTypeTypedLabel;
      case 'imageClick':
        return l10n.answerTypeImageClickLabel;
      case 'flashcard':
        return l10n.answerTypeFlashcardLabel;
      case 'sorting':
        return l10n.answerTypeSortingLabel;
      case 'set':
        return l10n.answerTypeSetLabel;
      default:
        return answerType[0].toUpperCase() + answerType.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = svc.getAnswerTypeCounts();
    final textColor = cs.onSurface;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsAnswerTypes,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor)),
            const SizedBox(height: 12),
            if (counts.isEmpty)
              Text(l10n.statsNoData,
                  style: TextStyle(
                      color: textColor.withValues(alpha: 0.6), fontSize: 13))
            else
              ...counts.entries.map((e) {
                final answered = e.value['answered'] ?? 0;
                final correct = e.value['correct'] ?? 0;
                final pct = answered == 0 ? 0.0 : correct / answered;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_label(e.key, l10n),
                              style: TextStyle(fontSize: 13, color: textColor)),
                          Text('${(pct * 100).round()}% ($answered)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withValues(alpha: 0.7))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── SRS Quality ────────────────────────────────────────────────

class _SrsQualityCard extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _SrsQualityCard(
      {required this.svc, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final quality = svc.getSrsQuality();
    final total = quality.values.fold(0, (a, b) => a + b);

    final entries = [
      ('again', l10n.srsAgain, cs.errorContainer, cs.onErrorContainer),
      ('hard', l10n.srsHard, cs.tertiaryContainer, cs.onTertiaryContainer),
      ('good', l10n.srsGood, cs.primaryContainer, cs.onPrimaryContainer),
      ('easy', l10n.srsEasy, cs.secondaryContainer, cs.onSecondaryContainer),
    ];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsSrs,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface)),
            const SizedBox(height: 12),
            if (total == 0)
              Text(l10n.statsNoData,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries.map((e) {
                  final count = quality[e.$1] ?? 0;
                  return Container(
                    decoration: BoxDecoration(
                      color: e.$3,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text('${e.$2}: $count',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: e.$4)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Fun Facts ─────────────────────────────────────────────────

class _FunFactsCard extends StatelessWidget {
  final StatisticsService svc;
  final AppLocalizations l10n;
  final ColorScheme cs;
  const _FunFactsCard(
      {required this.svc, required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    final bestDayKey = svc.getBestDayKey();
    final bestDayCount = svc.getBestDayCount();
    final mostActiveWeekday = svc.getMostActiveWeekday();
    final perfectSessions = svc.getTotalPerfectSessions();
    final uniqueQuestions = SrsService().getAllUserData().length;

    final locale = Localizations.localeOf(context).toString();

    String? bestDayStr;
    if (bestDayKey != null) {
      final dateStr = bestDayKey.substring('stats_day_'.length);
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        bestDayStr = DateFormat.yMMMd(locale).format(dt);
      }
    }

    String? mostActiveDayStr;
    if (mostActiveWeekday != null) {
      // Use a fixed Monday-anchored reference week to get weekday name
      final refDate = DateTime(2024, 1, mostActiveWeekday);
      mostActiveDayStr = DateFormat.EEEE(locale).format(refDate);
    }

    final rows = <(IconData, String, String)>[
      if (bestDayStr != null)
        (Icons.emoji_events_rounded, l10n.statsBestDay,
            '$bestDayStr ($bestDayCount)'),
      if (mostActiveDayStr != null)
        (Icons.calendar_today_rounded, l10n.statsMostActiveDay, mostActiveDayStr),
      (Icons.school_rounded, l10n.statsUniqueQuestions, '$uniqueQuestions'),
      (Icons.star_rounded, l10n.statsPerfectSessions, '$perfectSessions'),
    ];

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsFunFacts,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(l10n.statsNoData,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13))
            else
              ...rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(r.$1, size: 20,
                            color: cs.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.$2,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6))),
                              Text(r.$3,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
