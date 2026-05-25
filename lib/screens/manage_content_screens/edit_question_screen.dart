import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:leerlus/models/answer_configs.dart' show FlashcardConfig, ImageClickConfig, MultipleChoiceConfig, SetConfig, SortingConfig, TypedAnswerConfig;
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/image_browser_dialog.dart';
import 'package:leerlus/widgets/image_picker_field.dart';
import 'package:leerlus/widgets/unsaved_changes_guard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'edit_question/answer_type_selector.dart';
import 'edit_question/multiple_choice_section.dart';
import 'edit_question/typed_answer_section.dart';
import 'edit_question/image_click_section.dart';
import 'edit_question/flashcard_section.dart';
import 'edit_question/sorting_section.dart';
import 'edit_question/set_section.dart';
import 'edit_question/occlusion_section.dart';

class EditQuestionScreen extends StatefulWidget {
  final String quizId;
  final AppDatabase db;
  final Question? question; // If provided → edit mode; if null → add mode

  const EditQuestionScreen({
    super.key,
    required this.quizId,
    required this.db,
    this.question,
  });

  bool get isEditing => question != null;

  @override
  State<EditQuestionScreen> createState() => _EditQuestionScreenState();
}

class _EditQuestionScreenState extends State<EditQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickerKey = GlobalKey<ImagePickerFieldState>();
  final _flashcardFrontPickerKey = GlobalKey<ImagePickerFieldState>();
  final _flashcardBackPickerKey = GlobalKey<ImagePickerFieldState>();
  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;
  late String _answerType;
  late String? _imagePath;
  bool _isDirty = false;

  // Multiple choice
  late final List<TextEditingController> _optionControllers;
  late Set<int> _correctIndices;
  bool _multipleCorrectEnabled = false;
  bool _showCorrectCount = false;

  // Typed
  late final List<TextEditingController> _acceptedAnswerControllers;

  // Image variants (for multipleChoice, typed, sorting, set)
  late List<String> _imagePathVariants;

  // Image click — list of polygons in normalized (0–1) coordinates
  List<List<Offset>> _selectedImageAreas = [];

  // Flashcard
  late final TextEditingController _flashcardFrontTextController;
  late final TextEditingController _flashcardBackTextController;
  String? _flashcardFrontImagePath;
  String? _flashcardBackImagePath;
  bool _flashcardRandomizeSides = false;

  // Sorting
  late final List<TextEditingController> _sortingControllers;
  bool _sortingShowPreFilled = true;

  // Set
  late final List<TextEditingController> _setControllers;

  // Occlusion (optional, available for all types except imageClick)
  OcclusionData? _occlusionData;

  bool get _hasChanges => _isDirty;

  /// The image path to use as the background for occlusion editing.
  /// For flashcard: front image. For imageClick: null (not supported).
  /// For all others: first image variant, or fallback to imagePath.
  String? get _occlusionImagePath {
    if (_answerType == 'imageClick') return null;
    if (_answerType == 'flashcard') return _flashcardFrontImagePath;
    return _imagePathVariants.isNotEmpty ? _imagePathVariants.first : _imagePath;
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void initState() {
    super.initState();
    final q = widget.question;

    _answerType = q?.answerType ?? 'multipleChoice';
    _imagePath = q?.imagePath;
    _questionController = TextEditingController(text: q?.questionText ?? '');
    _explanationController =
        TextEditingController(text: q?.explanation ?? '');

    if (q != null) {
      Map<String, dynamic> config;
      try {
        config = jsonDecode(q.answerConfig) as Map<String, dynamic>;
      } catch (_) {
        config = {};
      }

      if (_answerType == 'multipleChoice') {
        final mc = MultipleChoiceConfig.fromJson(config);
        _optionControllers = mc.options
            .map((o) => TextEditingController(text: o))
            .toList();
        while (_optionControllers.length < 2) {
          _optionControllers.add(TextEditingController());
        }
        _correctIndices = mc.correctIndices.toSet();
        _multipleCorrectEnabled = mc.multipleCorrect;
        _showCorrectCount = mc.showCorrectCount;
      } else {
        _optionControllers =
            List.generate(4, (_) => TextEditingController());
        _correctIndices = {0};
      }

      if (_answerType == 'typed') {
        final tc = TypedAnswerConfig.fromJson(config);
        _acceptedAnswerControllers = tc.acceptedAnswers
            .map((a) => TextEditingController(text: a))
            .toList();
      } else {
        _acceptedAnswerControllers = [TextEditingController()];
      }

      if (_answerType == 'imageClick') {
        final ic = ImageClickConfig.fromJson(config);
        _selectedImageAreas = ic.correctAreas;
      }

      if (_answerType == 'flashcard') {
        final fc = FlashcardConfig.fromJson(config);
        _flashcardFrontTextController =
            TextEditingController(text: fc.frontText ?? '');
        _flashcardBackTextController =
            TextEditingController(text: fc.backText ?? '');
        _flashcardFrontImagePath = fc.frontImagePath;
        _flashcardBackImagePath = fc.backImagePath;
        _flashcardRandomizeSides = fc.randomizeSides;
      } else {
        _flashcardFrontTextController = TextEditingController();
        _flashcardBackTextController = TextEditingController();
      }

      if (_answerType == 'sorting') {
        final sc = SortingConfig.fromJson(config);
        _sortingControllers =
            sc.items.map((s) => TextEditingController(text: s)).toList();
        while (_sortingControllers.length < 2) {
          _sortingControllers.add(TextEditingController());
        }
        _sortingShowPreFilled = sc.showPreFilled;
      } else {
        _sortingControllers =
            List.generate(4, (_) => TextEditingController());
      }

      if (_answerType == 'set') {
        final sc = SetConfig.fromJson(config);
        _setControllers =
            sc.answers.map((a) => TextEditingController(text: a)).toList();
        while (_setControllers.length < 2) {
          _setControllers.add(TextEditingController());
        }
      } else {
        _setControllers =
            List.generate(2, (_) => TextEditingController());
      }
    } else {
      // Add mode defaults
      _optionControllers =
          List.generate(4, (_) => TextEditingController());
      _correctIndices = {0};
      _acceptedAnswerControllers = [TextEditingController()];
      _flashcardFrontTextController = TextEditingController();
      _flashcardBackTextController = TextEditingController();
      _sortingControllers =
          List.generate(4, (_) => TextEditingController());
      _setControllers =
          List.generate(2, (_) => TextEditingController());
    }

    // Occlusion config
    if (q?.occlusionConfig != null) {
      try {
        _occlusionData = OcclusionData.fromJson(
            jsonDecode(q!.occlusionConfig!) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Image variants: load from new column if set, fall back to legacy imagePath.
    // imageClick uses a single _imagePath managed by _pickerKey instead.
    if (_answerType == 'imageClick' || _answerType == 'flashcard') {
      _imagePathVariants = [];
    } else if (q?.imagePathVariants != null) {
      try {
        _imagePathVariants =
            List<String>.from(jsonDecode(q!.imagePathVariants!));
      } catch (_) {
        _imagePathVariants = [];
      }
    } else if (q?.imagePath != null) {
      // Legacy single-image question: migrate into the variants list.
      _imagePathVariants = [q!.imagePath!];
    } else {
      _imagePathVariants = [];
    }

    _questionController.addListener(_markDirty);
    _explanationController.addListener(_markDirty);
    for (final c in _optionControllers) { c.addListener(_markDirty); }
    for (final c in _acceptedAnswerControllers) { c.addListener(_markDirty); }
    _flashcardFrontTextController.addListener(_markDirty);
    _flashcardBackTextController.addListener(_markDirty);
    for (final c in _sortingControllers) { c.addListener(_markDirty); }
    for (final c in _setControllers) { c.addListener(_markDirty); }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final c in _optionControllers) c.dispose();
    for (final c in _acceptedAnswerControllers) c.dispose();
    _flashcardFrontTextController.dispose();
    _flashcardBackTextController.dispose();
    for (final c in _sortingControllers) c.dispose();
    for (final c in _setControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UnsavedChangesGuard(
      hasChanges: _hasChanges,
      message: l10n.unsavedChangesQuestion,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? l10n.editQuestionAppBarTitle : l10n.addQuestionAppBarTitle),
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
                    controller: _questionController,
                    decoration: InputDecoration(
                      labelText: l10n.questionLabel,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: null,
                    validator: (v) => v!.trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),

                  AnswerTypeSelector(
                    selected: _answerType,
                    onChanged: (v) => setState(() {
                      _answerType = v;
                      _isDirty = true;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_answerType == 'multipleChoice')
                    MultipleChoiceSection(
                      optionControllers: _optionControllers,
                      correctIndices: _correctIndices,
                      multipleCorrectEnabled: _multipleCorrectEnabled,
                      showCorrectCount: _showCorrectCount,
                      onCorrectIndicesChanged: (v) => setState(() {
                        _correctIndices = v;
                        _isDirty = true;
                      }),
                      onMultipleCorrectChanged: (v) => setState(() {
                        _multipleCorrectEnabled = v;
                        if (!v && _correctIndices.length > 1) {
                          _correctIndices = {_correctIndices.first};
                        }
                        _isDirty = true;
                      }),
                      onShowCorrectCountChanged: (v) => setState(() {
                        _showCorrectCount = v;
                        _isDirty = true;
                      }),
                      onAddOption: () {
                        final c = TextEditingController();
                        c.addListener(_markDirty);
                        setState(() => _optionControllers.add(c));
                      },
                      onRemoveOption: (i) => setState(() {
                        _optionControllers.removeAt(i).dispose();
                        _correctIndices = _correctIndices
                            .where((idx) => idx != i)
                            .map((idx) => idx > i ? idx - 1 : idx)
                            .toSet();
                        if (_correctIndices.isEmpty) _correctIndices = {0};
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'imageClick')
                    ImageClickSection(
                      pickerKey: _pickerKey,
                      imagePath: _imagePath,
                      selectedImageAreas: _selectedImageAreas,
                      onImageChanged: (path) => setState(() {
                        _imagePath = path;
                        _selectedImageAreas = [];
                        _isDirty = true;
                      }),
                      onAreasChanged: (areas) => setState(() {
                        _selectedImageAreas = areas;
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'typed')
                    TypedAnswerSection(
                      controllers: _acceptedAnswerControllers,
                      onAddVariant: () {
                        final c = TextEditingController();
                        c.addListener(_markDirty);
                        setState(() => _acceptedAnswerControllers.add(c));
                      },
                      onRemoveVariant: (index) => setState(() {
                        _acceptedAnswerControllers.removeAt(index).dispose();
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'flashcard')
                    FlashcardSection(
                      randomizeSides: _flashcardRandomizeSides,
                      onRandomizeChanged: (v) => setState(() {
                        _flashcardRandomizeSides = v;
                        _isDirty = true;
                      }),
                      frontTextController: _flashcardFrontTextController,
                      backTextController: _flashcardBackTextController,
                      frontImagePath: _flashcardFrontImagePath,
                      backImagePath: _flashcardBackImagePath,
                      frontPickerKey: _flashcardFrontPickerKey,
                      backPickerKey: _flashcardBackPickerKey,
                      onFrontImageChanged: (path) => setState(() {
                        _flashcardFrontImagePath = path;
                        _isDirty = true;
                      }),
                      onBackImageChanged: (path) => setState(() {
                        _flashcardBackImagePath = path;
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'set')
                    SetSection(
                      answerControllers: _setControllers,
                      onAddAnswer: () {
                        final c = TextEditingController();
                        c.addListener(_markDirty);
                        setState(() => _setControllers.add(c));
                      },
                      onRemoveAnswer: (i) => setState(() {
                        _setControllers.removeAt(i).dispose();
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'sorting')
                    SortingSection(
                      itemControllers: _sortingControllers,
                      showPreFilled: _sortingShowPreFilled,
                      onShowPreFilledChanged: (v) => setState(() {
                        _sortingShowPreFilled = v;
                        _isDirty = true;
                      }),
                      onAddItem: () {
                        final c = TextEditingController();
                        c.addListener(_markDirty);
                        setState(() => _sortingControllers.add(c));
                      },
                      onRemoveItem: (i) => setState(() {
                        _sortingControllers.removeAt(i).dispose();
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType != 'imageClick' && _answerType != 'flashcard') ...[
                    const SizedBox(height: 8),
                    _buildImageVariantsEditor(),
                    const SizedBox(height: 16),
                  ],

                  // Occlusion section — available for all types except imageClick
                  if (_answerType != 'imageClick') ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 4),
                    OcclusionSection(
                      imagePathForOcclusion: _occlusionImagePath,
                      occlusionData: _occlusionData,
                      onChanged: (data) => setState(() {
                        _occlusionData = data;
                        _isDirty = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextFormField(
                    controller: _explanationController,
                    decoration: InputDecoration(
                      labelText: l10n.explanationOptional,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text(widget.isEditing ? l10n.saveChanges : l10n.saveQuestion),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageVariantsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Question images (randomized)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            const Tooltip(
              message:
                  'A random image is shown each time this question appears.\n'
                  'Add multiple images of the same subject so students learn\n'
                  'the concept, not a specific image.',
              child: Icon(Icons.help_outline, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_imagePathVariants.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _imagePathVariants.asMap().entries.map((entry) {
              final index = entry.key;
              final path = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: AppImage(
                        path: path,
                        fit: BoxFit.cover,
                        width: 100,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _imagePathVariants.removeAt(index);
                        _isDirty = true;
                      }),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        if (_imagePathVariants.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addNewImageVariant,
                icon: const Icon(Icons.file_open_outlined, size: 16),
                label: const Text('New image'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addExistingImageVariant,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Existing image'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addNewImageVariant() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path == null) return;
    final saved = await _saveImageToStorage(result!.files.single.path!);
    if (saved != null && mounted) {
      setState(() {
        _imagePathVariants.add(saved);
        _isDirty = true;
      });
    }
  }

  Future<void> _addExistingImageVariant() async {
    final picked = await ImageBrowserDialog.show(context);
    if (picked == null) return;
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _imagePathVariants.add(picked);
        _isDirty = true;
      });
    }
  }

  Future<String?> _saveImageToStorage(String sourcePath) async {
    final fileName = p.basename(sourcePath);
    try {
      if (kDebugMode) {
        final dest = Directory(
            p.join(Directory.current.path, 'assets', 'images'));
        if (!dest.existsSync()) dest.createSync(recursive: true);
        await File(sourcePath).copy(p.join(dest.path, fileName));
        return 'assets/images/$fileName';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final dest = Directory(p.join(dir.path, 'images'));
        if (!dest.existsSync()) dest.createSync(recursive: true);
        final destPath = p.join(dest.path, fileName);
        await File(sourcePath).copy(destPath);
        return destPath;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final questionText = _questionController.text.trim();

    final String answerConfig;
    // imageClick/flashcard use a single imagePath; all other types use the
    // imagePathVariants list and derive imagePath from its first element.
    String? singleImagePath; // only set for imageClick / flashcard

    if (_answerType == 'multipleChoice') {
      if (_correctIndices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.selectAtLeastOneCorrect)));
        return;
      }
      answerConfig = jsonEncode({
        'options': _optionControllers.map((c) => c.text.trim()).toList(),
        'correctIndices': _correctIndices.toList(),
        'scrambleOptions': true,
        if (_multipleCorrectEnabled) 'multipleCorrect': true,
        if (_showCorrectCount) 'showCorrectCount': true,
      });
    } else if (_answerType == 'imageClick') {
      singleImagePath = await _pickerKey.currentState
          ?.applyAutoName('question_$questionText') ?? _imagePath;
      if (_selectedImageAreas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.pleaseDefineClickArea)));
        return;
      }
      answerConfig = jsonEncode(
          ImageClickConfig(correctAreas: _selectedImageAreas).toJson());
    } else if (_answerType == 'flashcard') {
      final frontText = _flashcardFrontTextController.text.trim();
      final backText = _flashcardBackTextController.text.trim();
      final frontImagePath = await _flashcardFrontPickerKey.currentState
          ?.applyAutoName('question_${questionText}_front')
          ?? _flashcardFrontImagePath;
      final backImagePath = await _flashcardBackPickerKey.currentState
          ?.applyAutoName('question_${questionText}_back')
          ?? _flashcardBackImagePath;

      if (frontText.isEmpty && (frontImagePath == null || frontImagePath.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.flashcardFrontRequired)));
        return;
      }
      if (backText.isEmpty && (backImagePath == null || backImagePath.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.flashcardBackRequired)));
        return;
      }

      answerConfig = jsonEncode(FlashcardConfig(
        frontText: frontText.isEmpty ? null : frontText,
        frontImagePath: frontImagePath,
        backText: backText.isEmpty ? null : backText,
        backImagePath: backImagePath,
        randomizeSides: _flashcardRandomizeSides,
      ).toJson());
    } else if (_answerType == 'sorting') {
      answerConfig = jsonEncode(SortingConfig(
        items: _sortingControllers.map((c) => c.text.trim()).toList(),
        showPreFilled: _sortingShowPreFilled,
      ).toJson());
    } else if (_answerType == 'set') {
      final answers = _setControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (answers.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.setAtLeastTwo)),
        );
        return;
      }
      answerConfig = jsonEncode(SetConfig(answers: answers).toJson());
    } else {
      // typed
      answerConfig = jsonEncode({
        'acceptedAnswers': _acceptedAnswerControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      });
    }

    // Build image fields for the companion.
    // imageClick / flashcard: singleImagePath, no variants.
    // All other types: variants list drives both columns.
    final bool usesVariants =
        _answerType != 'imageClick' && _answerType != 'flashcard';
    final String? finalImagePath = usesVariants
        ? (_imagePathVariants.isEmpty ? null : _imagePathVariants.first)
        : singleImagePath;
    final String? finalVariantsJson = usesVariants && _imagePathVariants.isNotEmpty
        ? jsonEncode(_imagePathVariants)
        : null;

    final explanation = _explanationController.text.trim();
    final String? occlusionConfigJson = (_occlusionData != null &&
            !_occlusionData!.isEmpty)
        ? jsonEncode(_occlusionData!.toJson())
        : null;

    final companion = QuestionsCompanion(
      questionText: Value(questionText),
      answerType: Value(_answerType),
      answerConfig: Value(answerConfig),
      explanation: Value(explanation.isEmpty ? null : explanation),
      imagePath: Value(finalImagePath),
      imagePathVariants: Value(finalVariantsJson),
      occlusionConfig: Value(occlusionConfigJson),
    );

    if (widget.isEditing) {
      await (widget.db.update(widget.db.questions)
        ..where((t) => t.id.equals(widget.question!.id)))
          .write(companion);
    } else {
      await widget.db.insertQuestionIntoQuiz(
        quizId: widget.quizId,
        question: companion,
      );
    }

    await QuestionService().refresh();
    if (mounted) Navigator.pop(context);
  }
}
