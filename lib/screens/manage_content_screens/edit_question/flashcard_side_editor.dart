import 'package:flutter/material.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/image_picker_field.dart';

class FlashcardSideEditor extends StatelessWidget {
  final String headerLabel;
  final String textOptionalLabel;
  final String imageOptionalLabel;
  final TextEditingController textController;
  final String? imagePath;
  final GlobalKey<ImagePickerFieldState> pickerKey;
  final ValueChanged<String?> onImageChanged;

  const FlashcardSideEditor({
    super.key,
    required this.headerLabel,
    required this.textOptionalLabel,
    required this.imageOptionalLabel,
    required this.textController,
    required this.imagePath,
    required this.pickerKey,
    required this.onImageChanged,
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
        TextFormField(
          controller: textController,
          onTap: collapseSelectionOnTap(textController),
          decoration: InputDecoration(
            labelText: textOptionalLabel,
            border: const OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 8),
        ImagePickerField(
          key: pickerKey,
          label: imageOptionalLabel,
          initialPath: imagePath,
          onChanged: onImageChanged,
        ),
      ],
    );
  }
}
