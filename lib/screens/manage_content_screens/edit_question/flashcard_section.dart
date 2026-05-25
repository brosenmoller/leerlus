import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/widgets/image_picker_field.dart';
import 'flashcard_side_editor.dart';

class FlashcardSection extends StatelessWidget {
  final bool randomizeSides;
  final ValueChanged<bool> onRandomizeChanged;
  final TextEditingController frontTextController;
  final TextEditingController backTextController;
  final String? frontImagePath;
  final String? backImagePath;
  final GlobalKey<ImagePickerFieldState> frontPickerKey;
  final GlobalKey<ImagePickerFieldState> backPickerKey;
  final ValueChanged<String?> onFrontImageChanged;
  final ValueChanged<String?> onBackImageChanged;

  const FlashcardSection({
    super.key,
    required this.randomizeSides,
    required this.onRandomizeChanged,
    required this.frontTextController,
    required this.backTextController,
    required this.frontImagePath,
    required this.backImagePath,
    required this.frontPickerKey,
    required this.backPickerKey,
    required this.onFrontImageChanged,
    required this.onBackImageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.flashcardRandomize),
          subtitle: Text(l10n.flashcardRandomizeSubtitle),
          value: randomizeSides,
          onChanged: onRandomizeChanged,
        ),
        const SizedBox(height: 8),
        FlashcardSideEditor(
          headerLabel: l10n.flashcardFrontSide,
          textOptionalLabel: l10n.flashcardFrontTextOptional,
          imageOptionalLabel: l10n.flashcardFrontImageOptional,
          textController: frontTextController,
          imagePath: frontImagePath,
          pickerKey: frontPickerKey,
          onImageChanged: onFrontImageChanged,
        ),
        const SizedBox(height: 16),
        FlashcardSideEditor(
          headerLabel: l10n.flashcardBackSide,
          textOptionalLabel: l10n.flashcardBackTextOptional,
          imageOptionalLabel: l10n.flashcardBackImageOptional,
          textController: backTextController,
          imagePath: backImagePath,
          pickerKey: backPickerKey,
          onImageChanged: onBackImageChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
