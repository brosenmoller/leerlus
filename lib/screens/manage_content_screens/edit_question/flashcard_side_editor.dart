import 'package:flutter/material.dart';
import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/media_attachment_button.dart';

/// One side of a flashcard: its text field with the attachment clip button on
/// the same row.
///
/// A side holds at most one attachment, so the button runs in single mode —
/// picking a second one replaces the first rather than appending.
class FlashcardSideEditor extends StatelessWidget {
  final String headerLabel;
  final String textOptionalLabel;
  final TextEditingController textController;
  final FocusNode? focusNode;
  final String? mediaPath;
  final Future<void> Function(MediaKind kind, String path) onAttach;
  final void Function(String path) onRemove;

  const FlashcardSideEditor({
    super.key,
    required this.headerLabel,
    required this.textOptionalLabel,
    required this.textController,
    this.focusNode,
    required this.mediaPath,
    required this.onAttach,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: textController,
                focusNode: focusNode,
                onTap: collapseSelectionOnTap(textController),
                decoration: InputDecoration(
                  labelText: textOptionalLabel,
                  border: const OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: MediaAttachmentButton(
                attachments: [if (mediaPath?.isNotEmpty == true) mediaPath!],
                multi: false,
                onAttach: onAttach,
                onRemove: onRemove,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
