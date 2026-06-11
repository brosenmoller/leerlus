import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/services/streak_service.dart';

/// A navigable single-month calendar shown in a dialog. Marks each day with a
/// fire (studied) or ice (streak freeze) badge. Weeks start on Monday.
class StreakCalendarDialog extends StatefulWidget {
  const StreakCalendarDialog({super.key});

  @override
  State<StreakCalendarDialog> createState() => _StreakCalendarDialogState();
}

class _StreakCalendarDialogState extends State<StreakCalendarDialog> {
  late DateTime _visibleMonth;
  late final Set<DateTime> _activeDays;
  late final Set<DateTime> _freezeDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _activeDays = StatisticsService().getActiveDays();
    _freezeDays = StreakService().freezeDaySet();
  }

  bool get _atCurrentMonth {
    final now = DateTime.now();
    return _visibleMonth.year == now.year && _visibleMonth.month == now.month;
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  Future<void> _pickMonthYear() async {
    final now = DateTime.now();
    int minYear = now.year;
    for (final d in _activeDays) {
      if (d.year < minYear) minYear = d.year;
    }
    for (final d in _freezeDays) {
      if (d.year < minYear) minYear = d.year;
    }
    if (_visibleMonth.year < minYear) minYear = _visibleMonth.year;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPicker(
        initial: _visibleMonth,
        minYear: minYear,
        maxMonth: DateTime(now.year, now.month),
      ),
    );
    if (picked != null) {
      setState(() => _visibleMonth = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                label: DateFormat.yMMMM(locale).format(_visibleMonth),
                onPrev: () => _changeMonth(-1),
                onNext: _atCurrentMonth ? null : () => _changeMonth(1),
                onPickDate: _pickMonthYear,
                cs: cs,
              ),
              const SizedBox(height: 12),
              _WeekdayRow(locale: locale, cs: cs),
              const SizedBox(height: 6),
              _MonthGrid(
                month: _visibleMonth,
                activeDays: _activeDays,
                freezeDays: _freezeDays,
                cs: cs,
              ),
              const SizedBox(height: 14),
              _Legend(l10n: l10n, cs: cs),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.back),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;
  final ColorScheme cs;

  const _Header({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 22, color: cs.onSurface.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final String locale;
  final ColorScheme cs;

  const _WeekdayRow({required this.locale, required this.cs});

  @override
  Widget build(BuildContext context) {
    // 2024-01-01 is a Monday — anchor the labels there to force Monday-first.
    final monday = DateTime(2024, 1, 1);
    final labels = List.generate(
      7,
      (i) => DateFormat.E(locale).format(monday.add(Duration(days: i))),
    );
    return Row(
      children: labels
          .map((l) => Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Set<DateTime> activeDays;
  final Set<DateTime> freezeDays;
  final ColorScheme cs;

  const _MonthGrid({
    required this.month,
    required this.activeDays,
    required this.freezeDays,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // Mon=0 … Sun=6
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_DayCell(
        day: day,
        isToday: date == todayDate,
        isStudied: activeDays.contains(date),
        isFreeze: !activeDays.contains(date) && freezeDays.contains(date),
        cs: cs,
      ));
    }
    // Always render 6 rows (42 cells) so the dialog height stays constant
    // between months — the header buttons never shift up or down.
    while (cells.length < 42) {
      cells.add(const SizedBox.shrink());
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isStudied;
  final bool isFreeze;
  final ColorScheme cs;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isStudied,
    required this.isFreeze,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    const fire = Colors.deepOrange;
    final ice = Colors.lightBlue.shade400;

    Color bg = Colors.transparent;
    if (isStudied) {
      bg = fire.withValues(alpha: 0.14);
    } else if (isFreeze) {
      bg = ice.withValues(alpha: 0.16);
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: cs.primary, width: 1.6)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isStudied)
            const Icon(Icons.local_fire_department,
                color: fire, size: 22)
          else if (isFreeze)
            Icon(Icons.ac_unit_rounded, color: ice, size: 20),
          Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: (isStudied || isFreeze)
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final AppLocalizations l10n;
  final ColorScheme cs;

  const _Legend({required this.l10n, required this.cs});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(Icons.local_fire_department, Colors.deepOrange,
            l10n.streakCalendarLegendStudied),
        const SizedBox(width: 20),
        item(Icons.ac_unit_rounded, Colors.lightBlue.shade400,
            l10n.streakCalendarLegendFreeze),
      ],
    );
  }
}

/// Compact picker: choose a year (◀ ▶) then tap a month to jump to it.
/// Pops the chosen month as a [DateTime] (first of month), or null on dismiss.
class _MonthYearPicker extends StatefulWidget {
  final DateTime initial;
  final int minYear;
  final DateTime maxMonth;

  const _MonthYearPicker({
    required this.initial,
    required this.minYear,
    required this.maxMonth,
  });

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  bool _isFuture(int month) =>
      _year > widget.maxMonth.year ||
      (_year == widget.maxMonth.year && month > widget.maxMonth.month);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (_year > widget.minYear)
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _year--),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (_year < widget.maxMonth.year)
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _year++),
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final label =
                      DateFormat.MMM(locale).format(DateTime(_year, month));
                  final selected = _year == widget.initial.year &&
                      month == widget.initial.month;
                  final disabled = _isFuture(month);
                  return _MonthChip(
                    label: label,
                    selected: selected,
                    disabled: disabled,
                    cs: cs,
                    onTap: disabled
                        ? null
                        : () => Navigator.pop(context, DateTime(_year, month)),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final ColorScheme cs;
  final VoidCallback? onTap;

  const _MonthChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: disabled
                  ? cs.onSurface.withValues(alpha: 0.3)
                  : selected
                      ? cs.onPrimary
                      : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
