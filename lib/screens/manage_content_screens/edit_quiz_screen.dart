import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/widgets/image_picker_field.dart';

// ── Language data ─────────────────────────────────────────────────────────────

class _Lang {
  final String code;
  final String name;
  const _Lang(this.code, this.name);
  String get display => '$name ($code)';
}

const _kLanguages = <_Lang>[
  _Lang('af', 'Afrikaans'),
  _Lang('ar', 'Arabic'),
  _Lang('bg', 'Bulgarian'),
  _Lang('bn', 'Bengali'),
  _Lang('cs', 'Czech'),
  _Lang('da', 'Danish'),
  _Lang('de', 'German'),
  _Lang('el', 'Greek'),
  _Lang('en', 'English'),
  _Lang('es', 'Spanish'),
  _Lang('et', 'Estonian'),
  _Lang('fa', 'Persian'),
  _Lang('fi', 'Finnish'),
  _Lang('fr', 'French'),
  _Lang('he', 'Hebrew'),
  _Lang('hi', 'Hindi'),
  _Lang('hr', 'Croatian'),
  _Lang('hu', 'Hungarian'),
  _Lang('id', 'Indonesian'),
  _Lang('it', 'Italian'),
  _Lang('ja', 'Japanese'),
  _Lang('ko', 'Korean'),
  _Lang('lt', 'Lithuanian'),
  _Lang('lv', 'Latvian'),
  _Lang('ms', 'Malay'),
  _Lang('nl', 'Dutch'),
  _Lang('no', 'Norwegian'),
  _Lang('pl', 'Polish'),
  _Lang('pt', 'Portuguese'),
  _Lang('ro', 'Romanian'),
  _Lang('ru', 'Russian'),
  _Lang('sk', 'Slovak'),
  _Lang('sl', 'Slovenian'),
  _Lang('sr', 'Serbian'),
  _Lang('sv', 'Swedish'),
  _Lang('sw', 'Swahili'),
  _Lang('th', 'Thai'),
  _Lang('tr', 'Turkish'),
  _Lang('uk', 'Ukrainian'),
  _Lang('ur', 'Urdu'),
  _Lang('vi', 'Vietnamese'),
  _Lang('zh', 'Chinese'),
];

/// Returns the display string ("English (en)") for a stored code, or the
/// raw code if it isn't in the known list (graceful fallback).
String _codeToDisplay(String? code) {
  if (code == null || code.isEmpty) return '';
  return _kLanguages
      .where((l) => l.code == code)
      .firstOrNull
      ?.display ?? code;
}

/// Resolves the text field value back to a language code.
/// Accepts "English (en)", "English", or "en" — falls back to raw text.
String? _displayToCode(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return _kLanguages
      .where((l) =>
          l.display.toLowerCase() == t.toLowerCase() ||
          l.name.toLowerCase() == t.toLowerCase() ||
          l.code.toLowerCase() == t.toLowerCase())
      .firstOrNull
      ?.code ?? t;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EditQuizScreen extends StatefulWidget {
  final AppDatabase db;
  /// The folder this quiz belongs to; null means root level.
  final String? folderId;
  final Quiz? existing;

  const EditQuizScreen({
    super.key,
    required this.db,
    this.folderId,
    this.existing,
  });

  @override
  State<EditQuizScreen> createState() => _EditQuizScreenState();
}

class _EditQuizScreenState extends State<EditQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickerKey = GlobalKey<ImagePickerFieldState>();
  late final TextEditingController _titleController;
  late final TextEditingController _languageController;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _languageController = TextEditingController(
        text: _codeToDisplay(widget.existing?.languageCode ?? 'en'));
    _imagePath = widget.existing?.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            isEditing ? l10n.editQuizAppBarTitle : l10n.addQuizAppBarTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l10n.titleLabel,
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: !isEditing,
                  validator: (v) =>
                      v!.trim().isEmpty ? l10n.required : null,
                ),
                const SizedBox(height: 20),
                ImagePickerField(
                  key: _pickerKey,
                  label: l10n.quizImageOptional,
                  initialPath: _imagePath,
                  onChanged: (path) => setState(() => _imagePath = path),
                ),
                const SizedBox(height: 20),

                // ── Language picker ───────────────────────────────────────
                DropdownMenu<String>(
                  controller: _languageController,
                  expandedInsets: EdgeInsets.zero,
                  menuHeight: MediaQuery.sizeOf(context).height * 0.4,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  label: Text(l10n.languageCodeLabel),
                  hintText: l10n.languageCodeHint,
                  inputDecorationTheme: const InputDecorationTheme(
                    border: OutlineInputBorder(),
                    isDense: false,
                  ),
                  dropdownMenuEntries: _kLanguages
                      .map((l) => DropdownMenuEntry<String>(
                            value: l.code,
                            label: l.display,
                          ))
                      .toList(),
                  onSelected: (_) {},
                ),

                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? l10n.saveChanges : l10n.addQuiz),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _titleController.text.trim();
    final languageCode = _displayToCode(_languageController.text);
    final imagePath =
        await _pickerKey.currentState?.applyAutoName('quiz_$title') ??
            _imagePath;
    final existing = widget.existing;
    if (existing == null) {
      await widget.db.insertQuiz(QuizzesCompanion(
        folderId: Value(widget.folderId),
        title: Value(title),
        imagePath: Value(imagePath),
        languageCode: Value(languageCode),
      ));
    } else {
      await widget.db.updateQuiz(QuizzesCompanion(
        id: Value(existing.id),
        folderId: Value(existing.folderId),
        title: Value(title),
        imagePath: Value(imagePath),
        languageCode: Value(languageCode),
      ));
    }
    await QuestionService().refresh();
    if (mounted) Navigator.pop(context);
  }
}
