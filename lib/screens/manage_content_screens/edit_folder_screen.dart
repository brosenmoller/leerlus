import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/image_picker_field.dart';

class EditFolderScreen extends StatefulWidget {
  final AppDatabase db;
  final Folder? existing;
  /// The parent folder to create inside; null means root level.
  final String? parentFolderId;

  const EditFolderScreen({
    super.key,
    required this.db,
    this.existing,
    this.parentFolderId,
  });

  @override
  State<EditFolderScreen> createState() => _EditFolderScreenState();
}

class _EditFolderScreenState extends State<EditFolderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickerKey = GlobalKey<ImagePickerFieldState>();
  late final TextEditingController _titleController;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existing?.title ?? '');
    _imagePath = widget.existing?.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editFolderAppBarTitle : l10n.addFolderAppBarTitle),
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
                labelText: l10n.folderNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: !isEditing,
              validator: (v) => v!.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 20),
            ImagePickerField(
              key: _pickerKey,
              label: l10n.folderImageOptional,
              initialPath: _imagePath,
              onChanged: (path) => setState(() => _imagePath = path),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? l10n.saveChanges : l10n.addFolder),
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
    final imagePath =
        await _pickerKey.currentState?.applyAutoName('folder_$title') ??
            _imagePath;
    final existing = widget.existing;
    if (existing == null) {
      await widget.db.insertFolder(FoldersCompanion(
        title: Value(title),
        imagePath: Value(imagePath),
        parentFolderId: Value(widget.parentFolderId),
      ));
    } else {
      await widget.db.updateFolder(FoldersCompanion(
        id: Value(existing.id),
        parentFolderId: Value(existing.parentFolderId),
        title: Value(title),
        imagePath: Value(imagePath),
        updatedAt: Value(DateTime.now()),
      ));
    }
    await QuestionService().refresh();
    if (mounted) Navigator.pop(context);
  }
}
