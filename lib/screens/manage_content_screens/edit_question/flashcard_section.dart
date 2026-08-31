import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/media_kind.dart';
import 'flashcard_side_editor.dart';

class FlashcardSection extends StatelessWidget {
  final bool randomizeSides;
  final ValueChanged<bool> onRandomizeChanged;
  final TextEditingController frontTextController;
  final TextEditingController backTextController;
  final FocusNode? frontFocusNode;
  final FocusNode? backFocusNode;
  final String? frontImagePath;
  final String? backImagePath;
  final Future<void> Function(MediaKind kind, String path) onAttachFront;
  final Future<void> Function(MediaKind kind, String path) onAttachBack;
  final void Function(String path) onRemoveFront;
  final void Function(String path) onRemoveBack;

  const FlashcardSection({
    super.key,
    required this.randomizeSides,
    required this.onRandomizeChanged,
    required this.frontTextController,
    required this.backTextController,
    this.frontFocusNode,
    this.backFocusNode,
    required this.frontImagePath,
    required this.backImagePath,
    required this.onAttachFront,
    required this.onAttachBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlashcardSideEditor(
          headerLabel: l10n.flashcardFrontSide,
          textOptionalLabel: l10n.flashcardFrontTextOptional,
          textController: frontTextController,
          focusNode: frontFocusNode,
          mediaPath: frontImagePath,
          onAttach: onAttachFront,
          onRemove: onRemoveFront,
        ),
        const SizedBox(height: 16),
        FlashcardSideEditor(
          headerLabel: l10n.flashcardBackSide,
          textOptionalLabel: l10n.flashcardBackTextOptional,
          textController: backTextController,
          focusNode: backFocusNode,
          mediaPath: backImagePath,
          onAttach: onAttachBack,
          onRemove: onRemoveBack,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.flashcardRandomize),
          subtitle: Text(l10n.flashcardRandomizeSubtitle),
          value: randomizeSides,
          onChanged: onRandomizeChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
