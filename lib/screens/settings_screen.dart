import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/srs_settings.dart';
import 'package:leerlus/screens/image_management_screen.dart';
import 'package:leerlus/screens/sync_screen.dart';
import 'package:leerlus/services/favorites_service.dart';
import 'package:leerlus/services/notification_service.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/settings_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/utils/language_data.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase db;

  const SettingsScreen({super.key, required this.db});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SrsService _srsService = SrsService();
  final SettingsService _settings = SettingsService();
  final StreakService _streak = StreakService();
  final NotificationService _notifs = NotificationService();

  late SrsSettings _srs;
  late bool _streakEnabled;
  late bool _notifsEnabled;
  late TimeOfDay _notifTime;
  late bool _animationsEnabled;
  late final TextEditingController _defaultLangController;
  final FocusNode _defaultLangFocusNode = FocusNode();
  String? _defaultLangCode;

  @override
  void initState() {
    super.initState();
    _srs = _settings.srsSettings;
    _streakEnabled = _streak.streakEnabled;
    _notifsEnabled = _streak.notifsEnabled;
    _notifTime = TimeOfDay(hour: _streak.notifsHour, minute: _streak.notifsMinute);
    _animationsEnabled = _settings.animationsEnabled;
    _defaultLangCode = _settings.defaultQuizLanguageCode;
    _defaultLangController = TextEditingController(
      text: codeToDisplay(_defaultLangCode),
    );
    _defaultLangFocusNode.addListener(() {
      if (_defaultLangFocusNode.hasFocus) {
        _defaultLangController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _defaultLangController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _defaultLangController.dispose();
    _defaultLangFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveSrs(SrsSettings updated) async {
    setState(() => _srs = updated);
    await _settings.setSrsSettings(updated);
  }

  Future<void> _resetSrs() async {
    await _settings.resetSrsSettings();
    setState(() => _srs = const SrsSettings());
  }


  Future<void> _confirmWipe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe all content?'),
        content: const Text(
            'This deletes every folder, quiz, question, SRS record, and '
            'favorite. Content cannot be recovered — re-import packs from '
            'the Content Packs screen afterwards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await widget.db.wipeAllContent();
    await SrsService().resetAll();
    await FavoritesService().clearAll();
    await QuestionService().refresh();

    messenger.showSnackBar(
      const SnackBar(content: Text('All content wiped.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            // ── Language ──────────────────────────────────────────
            DropdownButtonFormField<String?>(
              value: _settings.languageCode,
              decoration: InputDecoration(
                labelText: l10n.settingsLanguage,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.settingsLanguageSystem),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.settingsLanguageEnglish),
                ),
                DropdownMenuItem(
                  value: 'nl',
                  child: Text(l10n.settingsLanguageDutch),
                ),
              ],
              onChanged: (code) async {
                await _settings.setLanguageCode(code);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 8),

            // ── Default quiz language ─────────────────────────────
            DropdownMenu<String>(
              controller: _defaultLangController,
              focusNode: _defaultLangFocusNode,
              expandedInsets: EdgeInsets.zero,
              menuHeight: MediaQuery.sizeOf(context).height * 0.4,
              enableFilter: true,
              requestFocusOnTap: true,
              label: Text(l10n.settingsDefaultQuizLanguage),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                isDense: false,
              ),
              dropdownMenuEntries: [
                DropdownMenuEntry<String>(
                  value: '',
                  label: l10n.settingsDefaultQuizLanguageNone,
                ),
                ...kLanguages.map((l) => DropdownMenuEntry<String>(
                      value: l.code,
                      label: l.display,
                    )),
              ],
              onSelected: (code) async {
                final effectiveCode = (code == null || code.isEmpty) ? null : code;
                setState(() => _defaultLangCode = effectiveCode);
                await _settings.setDefaultQuizLanguageCode(effectiveCode);
                _defaultLangController.text = codeToDisplay(effectiveCode);
              },
            ),
            const SizedBox(height: 8),

            // ── Animations ───────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsAnimations),
              subtitle: Text(l10n.settingsAnimationsSubtitle),
              value: _animationsEnabled,
              onChanged: (v) async {
                await _settings.setAnimationsEnabled(v);
                setState(() => _animationsEnabled = v);
              },
            ),
            const SizedBox(height: 12),

            // ── Sync ─────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync_rounded),
              title: Text(l10n.navSync),
              subtitle: Text(l10n.navSyncSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SyncScreen(db: widget.db)),
              ),
            ),

            // ── Image Library ─────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.imageLibraryTitle),
              subtitle: Text(l10n.imageLibrarySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageManagementScreen(db: widget.db),
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // ── Dev: wipe all content ────────────────────────────
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Wipe all content (dev)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () => _confirmWipe(context),
              ),
              const Divider(),
            ],

            // ── Streak ───────────────────────────────────────────
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.hardEdge,
              child: ExpansionTile(
                leading: const Icon(Icons.local_fire_department),
                title: Text(l10n.streakSectionTitle),
                subtitle: ValueListenableBuilder<StreakState>(
                  valueListenable: _streak.streakNotifier,
                  builder: (context, state, _) => Text(
                    state.streakEnabled && state.streakCount > 0
                        ? l10n.streakCount(state.streakCount)
                        : l10n.streakEnabledSubtitle,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  SwitchListTile(
                    title: Text(l10n.streakEnabledToggle),
                    value: _streakEnabled,
                    onChanged: (v) async {
                      await _streak.setStreakEnabled(v);
                      setState(() => _streakEnabled = v);
                    },
                  ),
                  if (_streakEnabled) ...[
                    if (_notifs.isSupported) ...[
                      SwitchListTile(
                        title: Text(l10n.streakNotifsToggle),
                        subtitle: Text(l10n.streakNotifsSubtitle),
                        value: _notifsEnabled,
                        onChanged: (v) async {
                          if (v) {
                            final granted = await _notifs.requestPermission();
                            if (!granted) return;
                          }
                          await _streak.setNotifsEnabled(v);
                          if (mounted) setState(() => _notifsEnabled = v);
                        },
                      ),
                      if (_notifsEnabled)
                        ListTile(
                          title: Text(l10n.streakNotifsTime),
                          trailing: Text(
                            _notifTime.format(context),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _notifTime,
                            );
                            if (picked == null || !mounted) return;
                            await _streak.setNotifTime(picked.hour, picked.minute);
                            setState(() => _notifTime = picked);
                          },
                        ),
                      const Divider(indent: 16, endIndent: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: Text(l10n.streakResetButton),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.streakResetDialogTitle),
                              content: Text(l10n.streakResetDialogContent),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(l10n.reset),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) await _streak.resetStreak();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── SRS Algorithm ────────────────────────────────────
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.hardEdge,
              child: ExpansionTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.srsAlgoSectionTitle),
                subtitle: Text(l10n.srsAlgoSectionSubtitle),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  _SrsSliderRow(
                    key: ValueKey('lapse_${_srs.lapseMultiplier}'),
                    label: l10n.srsAlgoLapseMultiplier,
                    initialValue: _srs.lapseMultiplier,
                    min: 0.05,
                    max: 0.75,
                    divisions: 14,
                    formatValue: (v) => v.toStringAsFixed(2),
                    description: l10n.srsAlgoLapseDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(lapseMultiplier: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('again_${_srs.easeAgain}'),
                    label: l10n.srsAlgoAgainPenalty,
                    initialValue: _srs.easeAgain,
                    min: -0.50,
                    max: -0.05,
                    divisions: 9,
                    formatValue: (v) => v.toStringAsFixed(2),
                    description: l10n.srsAlgoAgainDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(easeAgain: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('hard_${_srs.easeHard}'),
                    label: l10n.srsAlgoHardPenalty,
                    initialValue: _srs.easeHard,
                    min: -0.50,
                    max: -0.05,
                    divisions: 9,
                    formatValue: (v) => v.toStringAsFixed(2),
                    description: l10n.srsAlgoHardDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(easeHard: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('good_${_srs.easeGood}'),
                    label: l10n.srsAlgoGoodAdjust,
                    initialValue: _srs.easeGood,
                    min: -0.05,
                    max: 0.10,
                    divisions: 15,
                    formatValue: (v) {
                      final s = v.toStringAsFixed(2);
                      return v > 0 ? '+$s' : s;
                    },
                    description: l10n.srsAlgoGoodDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(easeGood: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('easy_${_srs.easeEasy}'),
                    label: l10n.srsAlgoEasyBonus,
                    initialValue: _srs.easeEasy,
                    min: 0.05,
                    max: 0.50,
                    divisions: 9,
                    formatValue: (v) => '+${v.toStringAsFixed(2)}',
                    description: l10n.srsAlgoEasyDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(easeEasy: double.parse(v.toStringAsFixed(2))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('initial_${_srs.initialEase}'),
                    label: l10n.srsAlgoInitialEase,
                    initialValue: _srs.initialEase,
                    min: 1.3,
                    max: 3.0,
                    divisions: 17,
                    formatValue: (v) => v.toStringAsFixed(1),
                    description: l10n.srsAlgoInitialEaseDesc,
                    onChangeEnd: (v) => _saveSrs(
                      _srs.copyWith(initialEase: double.parse(v.toStringAsFixed(1))),
                    ),
                  ),
                  _SrsSliderRow(
                    key: ValueKey('maxInterval_${_srs.maxIntervalDays}'),
                    label: l10n.srsAlgoMaxInterval,
                    initialValue: _srs.maxIntervalDays.toDouble(),
                    min: 30,
                    max: 365,
                    divisions: 67,
                    formatValue: (v) => l10n.srsAlgoDays(v.round()),
                    description: l10n.srsAlgoMaxIntervalDesc,
                    onChangeEnd: (v) =>
                        _saveSrs(_srs.copyWith(maxIntervalDays: v.round())),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.srsAlgoResetDefaults),
                      onPressed: _resetSrs,
                    ),
                  ),
                ],
              ),
            ),

            // ── Reset SRS ────────────────────────────────────────
            ElevatedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.settingsResetSrs),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.settingsResetSrsDialogTitle),
                    content: Text(l10n.settingsResetSrsDialogContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.reset),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _srsService.resetAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.settingsResetSrsSuccess)),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SrsSliderRow extends StatefulWidget {
  final String label;
  final double initialValue;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double> onChangeEnd;
  final String? description;

  const _SrsSliderRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChangeEnd,
    this.description,
  });

  @override
  State<_SrsSliderRow> createState() => _SrsSliderRowState();
}

class _SrsSliderRowState extends State<_SrsSliderRow> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                widget.formatValue(_value),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                widget.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ),
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: widget.onChangeEnd,
          ),
        ],
      ),
    );
  }
}
