import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/settings_service.dart';
import 'package:leerlus/utils/language_data.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/image_picker_field.dart';

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
    final defaultLang = widget.existing == null
        ? SettingsService().defaultQuizLanguageCode
        : widget.existing!.languageCode;
    _languageController =
        TextEditingController(text: codeToDisplay(defaultLang));
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
                  onTap: collapseSelectionOnTap(_titleController),
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
                  dropdownMenuEntries: kLanguages
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
    final languageCode = displayToCode(_languageController.text);
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
        updatedAt: Value(DateTime.now()),
      ));
    }
    await QuestionService().refresh();
    if (mounted) Navigator.pop(context);
  }
}
