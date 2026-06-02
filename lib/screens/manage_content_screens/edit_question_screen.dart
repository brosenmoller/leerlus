import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:leerlus/models/answer_configs.dart' show FlashcardConfig, ImageClickConfig, MultipleChoiceConfig, SetConfig, SortingConfig, TypedAnswerConfig;
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/image_browser_dialog.dart';
import 'package:leerlus/widgets/image_picker_field.dart';
import 'package:leerlus/widgets/unsaved_changes_guard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:leerlus/models/occlusion_data.dart' show OcclusionData, OcclusionImageEntry;
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
  final Set<String> _pendingVariantSources = {};
  final Set<String> _removedSavedVariants = {};

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

  // Pending image flags — tracks whether the current image path for each slot
  // is a temp source file that hasn't been copied to app storage yet.
  // Needed to carry pending images across answer-type switches.
  bool _flashcardFrontImagePending = false;
  bool _flashcardBackImagePending = false;
  bool _imageClickImagePending = false;

  // Per-image occlusion: key = image path for variants, 'front'/'back' for flashcard.
  // Stored as v2 JSON {"v":2,"perImage":{...}} in the DB occlusionConfig column.
  Map<String, OcclusionData> _occlusionDataByImage = {};

  // Original image paths captured at init (edit mode only) for orphan detection on save.
  late final Set<String> _originalImagePaths;

  // Focus nodes — kept in sync with their corresponding controller lists.
  late final FocusNode _questionFocusNode;
  late final List<FocusNode> _optionFocusNodes;
  late final List<FocusNode> _acceptedAnswerFocusNodes;
  late final List<FocusNode> _sortingFocusNodes;
  late final List<FocusNode> _setFocusNodes;

  bool get _hasChanges => _isDirty;

  /// Images that support per-image occlusion for the current answer type.
  /// imageClick returns empty (not supported). Each entry carries a stable
  /// key ('front'/'back' or image path) and a display label.
  List<OcclusionImageEntry> get _occlusionImages {
    if (_answerType == 'imageClick') return [];
    if (_answerType == 'flashcard') {
      return [
        if (_flashcardFrontImagePath?.isNotEmpty == true)
          OcclusionImageEntry(key: 'front', label: 'Front', imagePath: _flashcardFrontImagePath!),
        if (_flashcardBackImagePath?.isNotEmpty == true)
          OcclusionImageEntry(key: 'back', label: 'Back', imagePath: _flashcardBackImagePath!),
      ];
    }
    return _imagePathVariants.asMap().entries.map((e) => OcclusionImageEntry(
      key: e.value,
      label: _imagePathVariants.length == 1 ? 'Image' : 'Image ${e.key + 1}',
      imagePath: e.value,
    )).toList();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void initState() {
    super.initState();
    final q = widget.question;

    _answerType = q?.answerType ?? 'typed';
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

    // Occlusion config — v2: {"v":2,"perImage":{...}}; legacy v1: raw OcclusionData JSON
    if (q?.occlusionConfig != null) {
      try {
        final occJson = jsonDecode(q!.occlusionConfig!) as Map<String, dynamic>;
        if (occJson.containsKey('perImage')) {
          final perImage = occJson['perImage'] as Map<String, dynamic>;
          _occlusionDataByImage = {
            for (final e in perImage.entries)
              e.key: OcclusionData.fromJson(e.value as Map<String, dynamic>)
          };
        } else {
          // Legacy v1 — assign to first applicable image
          final legacy = OcclusionData.fromJson(occJson);
          if (!legacy.isEmpty) {
            if (_answerType == 'flashcard') {
              _occlusionDataByImage = {'front': legacy};
            } else if (_imagePathVariants.isNotEmpty) {
              _occlusionDataByImage = {_imagePathVariants.first: legacy};
            }
          }
        }
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

    // Capture original image paths for orphan detection on save (edit mode only).
    if (widget.isEditing) {
      _originalImagePaths = <String>{};
      for (final p in _imagePathVariants) {
        if (AppDatabase.isUserImagePath(p)) _originalImagePaths.add(p);
      }
      if (AppDatabase.isUserImagePath(_imagePath)) _originalImagePaths.add(_imagePath!);
      if (AppDatabase.isUserImagePath(_flashcardFrontImagePath)) {
        _originalImagePaths.add(_flashcardFrontImagePath!);
      }
      if (AppDatabase.isUserImagePath(_flashcardBackImagePath)) {
        _originalImagePaths.add(_flashcardBackImagePath!);
      }
    } else {
      _originalImagePaths = {};
    }

    _questionFocusNode = FocusNode();
    _optionFocusNodes = List.generate(_optionControllers.length, (_) => FocusNode());
    _acceptedAnswerFocusNodes = List.generate(_acceptedAnswerControllers.length, (_) => FocusNode());
    _sortingFocusNodes = List.generate(_sortingControllers.length, (_) => FocusNode());
    _setFocusNodes = List.generate(_setControllers.length, (_) => FocusNode());

    if (_answerType != 'flashcard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _questionFocusNode.requestFocus();
      });
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
    _questionFocusNode.dispose();
    for (final fn in _optionFocusNodes) fn.dispose();
    for (final fn in _acceptedAnswerFocusNodes) fn.dispose();
    for (final fn in _sortingFocusNodes) fn.dispose();
    for (final fn in _setFocusNodes) fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: UnsavedChangesGuard(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                children: [
                  if (_answerType != 'flashcard') ...[
                    TextFormField(
                      controller: _questionController,
                      focusNode: _questionFocusNode,
                      onTap: collapseSelectionOnTap(_questionController),
                      decoration: InputDecoration(
                        labelText: l10n.questionLabel,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: null,
                      validator: (v) => v!.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  AnswerTypeSelector(
                    selected: _answerType,
                    onChanged: _onAnswerTypeChanged,
                  ),
                  const SizedBox(height: 16),

                  if (_answerType == 'multipleChoice')
                    MultipleChoiceSection(
                      optionControllers: _optionControllers,
                      focusNodes: _optionFocusNodes,
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
                        final fn = FocusNode();
                        c.addListener(_markDirty);
                        setState(() {
                          _optionControllers.add(c);
                          _optionFocusNodes.add(fn);
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) fn.requestFocus();
                        });
                      },
                      onRemoveOption: (i) => setState(() {
                        _optionControllers.removeAt(i).dispose();
                        _optionFocusNodes.removeAt(i).dispose();
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
                      onImageChanged: (path) {
                        final isPending = _pickerKey.currentState?.hasPendingSource ?? false;
                        setState(() {
                          _imagePath = path;
                          _imageClickImagePending = path != null && isPending;
                          _selectedImageAreas = [];
                          _isDirty = true;
                        });
                      },
                      onAreasChanged: (areas) => setState(() {
                        _selectedImageAreas = areas;
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'typed')
                    TypedAnswerSection(
                      controllers: _acceptedAnswerControllers,
                      focusNodes: _acceptedAnswerFocusNodes,
                      onAddVariant: () {
                        final c = TextEditingController();
                        final fn = FocusNode();
                        c.addListener(_markDirty);
                        setState(() {
                          _acceptedAnswerControllers.add(c);
                          _acceptedAnswerFocusNodes.add(fn);
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) fn.requestFocus();
                        });
                      },
                      onRemoveVariant: (index) => setState(() {
                        _acceptedAnswerControllers.removeAt(index).dispose();
                        _acceptedAnswerFocusNodes.removeAt(index).dispose();
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
                      onFrontImageChanged: (path) {
                        final isPending = _flashcardFrontPickerKey.currentState?.hasPendingSource ?? false;
                        setState(() {
                          if (path == null) _occlusionDataByImage.remove('front');
                          _flashcardFrontImagePath = path;
                          _flashcardFrontImagePending = path != null && isPending;
                          _isDirty = true;
                        });
                      },
                      onBackImageChanged: (path) {
                        final isPending = _flashcardBackPickerKey.currentState?.hasPendingSource ?? false;
                        setState(() {
                          if (path == null) _occlusionDataByImage.remove('back');
                          _flashcardBackImagePath = path;
                          _flashcardBackImagePending = path != null && isPending;
                          _isDirty = true;
                        });
                      },
                    ),

                  if (_answerType == 'set')
                    SetSection(
                      answerControllers: _setControllers,
                      focusNodes: _setFocusNodes,
                      onAddAnswer: () {
                        final c = TextEditingController();
                        final fn = FocusNode();
                        c.addListener(_markDirty);
                        setState(() {
                          _setControllers.add(c);
                          _setFocusNodes.add(fn);
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) fn.requestFocus();
                        });
                      },
                      onRemoveAnswer: (i) => setState(() {
                        _setControllers.removeAt(i).dispose();
                        _setFocusNodes.removeAt(i).dispose();
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType == 'sorting')
                    SortingSection(
                      itemControllers: _sortingControllers,
                      focusNodes: _sortingFocusNodes,
                      showPreFilled: _sortingShowPreFilled,
                      onShowPreFilledChanged: (v) => setState(() {
                        _sortingShowPreFilled = v;
                        _isDirty = true;
                      }),
                      onAddItem: () {
                        final c = TextEditingController();
                        final fn = FocusNode();
                        c.addListener(_markDirty);
                        setState(() {
                          _sortingControllers.add(c);
                          _sortingFocusNodes.add(fn);
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) fn.requestFocus();
                        });
                      },
                      onRemoveItem: (i) => setState(() {
                        _sortingControllers.removeAt(i).dispose();
                        _sortingFocusNodes.removeAt(i).dispose();
                        _isDirty = true;
                      }),
                    ),

                  if (_answerType != 'imageClick' && _answerType != 'flashcard') ...[
                    const SizedBox(height: 8),
                    _buildImageVariantsEditor(),
                    const SizedBox(height: 16),
                  ],

                  if (_occlusionImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OcclusionSection(
                      images: _occlusionImages,
                      occlusionDataByImage: _occlusionDataByImage,
                      onChanged: (map) => setState(() {
                        _occlusionDataByImage = map;
                        _isDirty = true;
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const Divider(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _explanationController,
                    onTap: collapseSelectionOnTap(_explanationController),
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
                  if (_answerType == 'flashcard') ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saveAndAddReversed,
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l10n.flashcardSaveAndAddReversed),
                    ),
                  ],
                ],
              ),
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
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        final removedPath = _imagePathVariants.removeAt(index);
                        _occlusionDataByImage.remove(removedPath);
                        if (_pendingVariantSources.remove(removedPath)) {
                          // Was a pending source — never copied, nothing to track.
                        } else if (widget.isEditing) {
                          _removedSavedVariants.add(removedPath);
                        }
                        _isDirty = true;
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
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
    final sourcePath = result!.files.single.path!;
    if (mounted) {
      setState(() {
        _imagePathVariants.add(sourcePath);
        _pendingVariantSources.add(sourcePath);
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

  Future<void> _showOrphanPromptAndDelete(Set<String> removedPaths) async {
    if (!widget.isEditing || removedPaths.isEmpty) return;
    final userPaths = removedPaths.where(AppDatabase.isUserImagePath).toSet();
    if (userPaths.isEmpty) return;
    final allReferenced = await widget.db.getAllReferencedUserImagePaths();
    final orphaned = userPaths.difference(allReferenced).toList();
    if (orphaned.isEmpty || !mounted) return;
    final l10n = AppLocalizations.of(context);
    bool deleteOrphans = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(l10n.saveOrphanImagesTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.saveOrphanImagesContent),
              const SizedBox(height: 12),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.deleteOrphanImages(orphaned.length),
                  style: const TextStyle(fontSize: 13),
                ),
                value: deleteOrphans,
                onChanged: (v) => setStateDlg(() => deleteOrphans = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && deleteOrphans) {
      for (final path in orphaned) {
        try { await File(path).delete(); } catch (_) {}
      }
    }
  }

  // ── Answer type switching ──────────────────────────────────────────────────

  /// Returns the set of occlusion keys (with non-empty data) that cannot be
  /// remapped to [newType] and will therefore be lost.
  Set<String> _computeLostOcclusionKeys(String newType) {
    if (_occlusionDataByImage.isEmpty) return {};
    final nonEmptyKeys = _occlusionDataByImage.entries
        .where((e) => !e.value.isEmpty)
        .map((e) => e.key)
        .toSet();
    if (nonEmptyKeys.isEmpty) return {};

    // imageClick: no occlusion at all
    if (newType == 'imageClick') return nonEmptyKeys;

    final oldIsVariant = _answerType != 'flashcard' && _answerType != 'imageClick';
    final newIsVariant = newType != 'flashcard' && newType != 'imageClick';

    // Between variant-based types: image paths carry over unchanged
    if (oldIsVariant && newIsVariant) return {};

    // imageClick → anything: nothing to lose (imageClick had no occlusion)
    if (_answerType == 'imageClick') return {};

    // flashcard → variant: 'front' remaps to carryImage; 'back' is lost
    if (_answerType == 'flashcard' && newIsVariant) {
      final canRemap = _flashcardFrontImagePath != null && nonEmptyKeys.contains('front');
      final lost = <String>{};
      if (nonEmptyKeys.contains('back')) lost.add('back');
      if (!canRemap && nonEmptyKeys.contains('front')) lost.add('front');
      return lost;
    }

    // variant → flashcard: first variant remaps to 'front'; others are lost
    if (oldIsVariant && newType == 'flashcard') {
      final carryImage = _imagePathVariants.isNotEmpty ? _imagePathVariants.first : null;
      return nonEmptyKeys.where((k) => k != carryImage).toSet();
    }

    return {};
  }

  /// Builds the new occlusion map after a type switch, remapping carried keys.
  Map<String, OcclusionData> _remapOcclusionForTypeSwitch(
      String newType, String? carryImage) {
    if (_occlusionDataByImage.isEmpty) return {};
    if (newType == 'imageClick') return {};

    final oldIsVariant = _answerType != 'flashcard' && _answerType != 'imageClick';
    final newIsVariant = newType != 'flashcard' && newType != 'imageClick';

    if (oldIsVariant && newIsVariant) return Map.from(_occlusionDataByImage);
    if (_answerType == 'imageClick') return {};

    if (_answerType == 'flashcard' && newIsVariant && carryImage != null) {
      final frontData = _occlusionDataByImage['front'];
      if (frontData != null && !frontData.isEmpty) return {carryImage: frontData};
      return {};
    }

    if (oldIsVariant && newType == 'flashcard' && carryImage != null) {
      final carryData = _occlusionDataByImage[carryImage];
      if (carryData != null && !carryData.isEmpty) return {'front': carryData};
      return {};
    }

    return {};
  }

  Future<void> _onAnswerTypeChanged(String newType) async {
    if (newType == _answerType) return;

    // Warn if occlusion data would be irreversibly lost
    final lostKeys = _computeLostOcclusionKeys(newType);
    if (lostKeys.isNotEmpty && mounted) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.occlusionTypeChangeTitle),
          content: Text(l10n.occlusionTypeChangeContent(lostKeys.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.occlusionTypeChangeContinue),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    // Determine carry-over image (carry even if pending — pending state preserved)
    String? carryImage;
    bool carryIsPending = false;
    if (_answerType == 'flashcard') {
      carryImage = _flashcardFrontImagePath;
      carryIsPending = _flashcardFrontImagePending;
    } else if (_answerType == 'imageClick') {
      carryImage = _imagePath;
      carryIsPending = _imageClickImagePending;
    } else if (_imagePathVariants.isNotEmpty) {
      carryImage = _imagePathVariants.first;
      carryIsPending = _pendingVariantSources.contains(carryImage);
    }

    final newOcclusion = _remapOcclusionForTypeSwitch(newType, carryImage);

    setState(() {
      // Clear old type's image state
      if (_answerType == 'flashcard') {
        _flashcardFrontImagePath = null;
        _flashcardBackImagePath = null;
        _flashcardFrontImagePending = false;
        _flashcardBackImagePending = false;
      } else if (_answerType == 'imageClick') {
        _imagePath = null;
        _imageClickImagePending = false;
        _selectedImageAreas = [];
      } else {
        // variant-based: track non-pending removed variants for orphan detection
        if (widget.isEditing) {
          for (final path in _imagePathVariants) {
            if (!_pendingVariantSources.contains(path)) {
              _removedSavedVariants.add(path);
            }
          }
        }
        _imagePathVariants.clear();
        _pendingVariantSources.clear();
      }

      // Apply carry-over to new type (preserve pending state)
      if (carryImage != null) {
        if (newType == 'flashcard') {
          _flashcardFrontImagePath = carryImage;
          _flashcardFrontImagePending = carryIsPending;
        } else if (newType == 'imageClick') {
          _imagePath = carryImage;
          _imageClickImagePending = carryIsPending;
        } else {
          _imagePathVariants.add(carryImage);
          if (carryIsPending) _pendingVariantSources.add(carryImage);
        }
      }

      _occlusionDataByImage = newOcclusion;
      _answerType = newType;
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    var questionText = _questionController.text.trim();

    final String answerConfig;
    // imageClick/flashcard use a single imagePath; all other types use the
    // imagePathVariants list and derive imagePath from its first element.
    String? singleImagePath; // only set for imageClick / flashcard
    // Wider-scoped so the orphan check below can read them after the if/else chain.
    String? resolvedFrontImagePath;
    String? resolvedBackImagePath;

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
      if (_imageClickImagePending && _imagePath != null) {
        singleImagePath = await _saveImageToStorage(_imagePath!);
        if (mounted) setState(() { _imagePath = singleImagePath; _imageClickImagePending = false; });
      } else {
        singleImagePath = await _pickerKey.currentState
            ?.applyAutoName('question_$questionText') ?? _imagePath;
      }
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
      // Auto-populate questionText from front side (used in list views)
      questionText = frontText.isNotEmpty ? frontText : backText.isNotEmpty ? backText : 'Flashcard';
      if (_flashcardFrontImagePending && _flashcardFrontImagePath != null) {
        resolvedFrontImagePath = await _saveImageToStorage(_flashcardFrontImagePath!);
        if (mounted) setState(() { _flashcardFrontImagePath = resolvedFrontImagePath; _flashcardFrontImagePending = false; });
      } else {
        resolvedFrontImagePath = await _flashcardFrontPickerKey.currentState
            ?.applyAutoName('question_${questionText}_front')
            ?? _flashcardFrontImagePath;
      }
      if (_flashcardBackImagePending && _flashcardBackImagePath != null) {
        resolvedBackImagePath = await _saveImageToStorage(_flashcardBackImagePath!);
        if (mounted) setState(() { _flashcardBackImagePath = resolvedBackImagePath; _flashcardBackImagePending = false; });
      } else {
        resolvedBackImagePath = await _flashcardBackPickerKey.currentState
            ?.applyAutoName('question_${questionText}_back')
            ?? _flashcardBackImagePath;
      }

      if (frontText.isEmpty && (resolvedFrontImagePath == null || resolvedFrontImagePath.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.flashcardFrontRequired)));
        return;
      }
      if (backText.isEmpty && (resolvedBackImagePath == null || resolvedBackImagePath.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.flashcardBackRequired)));
        return;
      }

      answerConfig = jsonEncode(FlashcardConfig(
        frontText: frontText.isEmpty ? null : frontText,
        frontImagePath: resolvedFrontImagePath,
        backText: backText.isEmpty ? null : backText,
        backImagePath: resolvedBackImagePath,
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

    // Flush pending image variants — copy source files to app storage now.
    if (_pendingVariantSources.isNotEmpty) {
      final oldPaths = List<String>.from(_imagePathVariants);
      final resolved = <String>[];
      for (final path in _imagePathVariants) {
        if (_pendingVariantSources.contains(path)) {
          resolved.add(await _saveImageToStorage(path) ?? path);
        } else {
          resolved.add(path);
        }
      }
      _imagePathVariants
        ..clear()
        ..addAll(resolved);
      _pendingVariantSources.clear();
      // Remap occlusion keys from old pending paths to new saved paths
      final remapped = <String, OcclusionData>{};
      for (int i = 0; i < oldPaths.length; i++) {
        final entry = _occlusionDataByImage[oldPaths[i]];
        if (entry != null) remapped[_imagePathVariants[i]] = entry;
      }
      for (final e in _occlusionDataByImage.entries) {
        if (!oldPaths.contains(e.key)) remapped[e.key] = e.value;
      }
      _occlusionDataByImage = remapped;
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
    final nonEmptyOcclusion = Map.fromEntries(
      _occlusionDataByImage.entries.where((e) => !e.value.isEmpty),
    );
    final String? occlusionConfigJson = nonEmptyOcclusion.isNotEmpty
        ? jsonEncode({
            'v': 2,
            'perImage': {
              for (final e in nonEmptyOcclusion.entries) e.key: e.value.toJson(),
            },
          })
        : null;

    final companion = QuestionsCompanion(
      questionText: Value(questionText),
      answerType: Value(_answerType),
      answerConfig: Value(answerConfig),
      explanation: Value(explanation.isEmpty ? null : explanation),
      imagePath: Value(finalImagePath),
      imagePathVariants: Value(finalVariantsJson),
      occlusionConfig: Value(occlusionConfigJson),
      updatedAt: Value(DateTime.now()),
    );

    final String questionId;
    if (widget.isEditing) {
      await (widget.db.update(widget.db.questions)
        ..where((t) => t.id.equals(widget.question!.id)))
          .write(companion);
      questionId = widget.question!.id;
    } else {
      questionId = await widget.db.insertQuestionIntoQuiz(
        quizId: widget.quizId,
        question: companion,
      );
    }

    await QuestionService().refresh();

    if (widget.isEditing && mounted) {
      final finalUserPaths = <String>{
        if (AppDatabase.isUserImagePath(finalImagePath)) finalImagePath!,
        for (final p in _imagePathVariants)
          if (AppDatabase.isUserImagePath(p)) p,
        if (AppDatabase.isUserImagePath(resolvedFrontImagePath)) resolvedFrontImagePath!,
        if (AppDatabase.isUserImagePath(resolvedBackImagePath)) resolvedBackImagePath!,
        if (AppDatabase.isUserImagePath(singleImagePath)) singleImagePath!,
      };
      await _showOrphanPromptAndDelete(_originalImagePaths.difference(finalUserPaths));
    }

    if (mounted) Navigator.pop(context, {'id': questionId, 'isNew': !widget.isEditing});
  }

  Future<void> _saveAndAddReversed() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);

    final frontText = _flashcardFrontTextController.text.trim();
    final backText = _flashcardBackTextController.text.trim();
    final questionText = frontText.isNotEmpty ? frontText : backText.isNotEmpty ? backText : 'Flashcard';

    String? frontImagePath;
    if (_flashcardFrontImagePending && _flashcardFrontImagePath != null) {
      frontImagePath = await _saveImageToStorage(_flashcardFrontImagePath!);
      if (mounted) setState(() { _flashcardFrontImagePath = frontImagePath; _flashcardFrontImagePending = false; });
    } else {
      frontImagePath = await _flashcardFrontPickerKey.currentState
          ?.applyAutoName('question_${questionText}_front')
          ?? _flashcardFrontImagePath;
    }
    String? backImagePath;
    if (_flashcardBackImagePending && _flashcardBackImagePath != null) {
      backImagePath = await _saveImageToStorage(_flashcardBackImagePath!);
      if (mounted) setState(() { _flashcardBackImagePath = backImagePath; _flashcardBackImagePending = false; });
    } else {
      backImagePath = await _flashcardBackPickerKey.currentState
          ?.applyAutoName('question_${questionText}_back')
          ?? _flashcardBackImagePath;
    }

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

    final explanation = _explanationController.text.trim();
    final nonEmptyOcclusionR = Map.fromEntries(
      _occlusionDataByImage.entries.where((e) => !e.value.isEmpty),
    );
    final occlusionConfigJson = nonEmptyOcclusionR.isNotEmpty
        ? jsonEncode({
            'v': 2,
            'perImage': {
              for (final e in nonEmptyOcclusionR.entries) e.key: e.value.toJson(),
            },
          })
        : null;

    final mainConfig = jsonEncode(FlashcardConfig(
      frontText: frontText.isEmpty ? null : frontText,
      frontImagePath: frontImagePath,
      backText: backText.isEmpty ? null : backText,
      backImagePath: backImagePath,
      randomizeSides: _flashcardRandomizeSides,
    ).toJson());

    final mainCompanion = QuestionsCompanion(
      questionText: Value(questionText),
      answerType: const Value('flashcard'),
      answerConfig: Value(mainConfig),
      explanation: Value(explanation.isEmpty ? null : explanation),
      occlusionConfig: Value(occlusionConfigJson),
      updatedAt: Value(DateTime.now()),
    );

    if (widget.isEditing) {
      await (widget.db.update(widget.db.questions)
        ..where((t) => t.id.equals(widget.question!.id)))
          .write(mainCompanion);
    } else {
      await widget.db.insertQuestionIntoQuiz(
        quizId: widget.quizId,
        question: mainCompanion,
      );
    }

    // Insert reversed sibling
    final reversedQuestionText = backText.isNotEmpty ? backText : frontText.isNotEmpty ? frontText : 'Flashcard';
    final reversedConfig = jsonEncode(FlashcardConfig(
      frontText: backText.isEmpty ? null : backText,
      frontImagePath: backImagePath,
      backText: frontText.isEmpty ? null : frontText,
      backImagePath: frontImagePath,
      randomizeSides: _flashcardRandomizeSides,
    ).toJson());

    final reversedId = await widget.db.insertQuestionIntoQuiz(
      quizId: widget.quizId,
      question: QuestionsCompanion(
        questionText: Value(reversedQuestionText),
        answerType: const Value('flashcard'),
        answerConfig: Value(reversedConfig),
        explanation: Value(explanation.isEmpty ? null : explanation),
      ),
    );

    await QuestionService().refresh();

    if (widget.isEditing && mounted) {
      final finalUserPaths = <String>{
        if (AppDatabase.isUserImagePath(frontImagePath)) frontImagePath!,
        if (AppDatabase.isUserImagePath(backImagePath)) backImagePath!,
      };
      await _showOrphanPromptAndDelete(_originalImagePaths.difference(finalUserPaths));
    }

    if (mounted) Navigator.pop(context, {'id': reversedId, 'isNew': true});
  }
}
