import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/screens/manage_content_screens/image_area_selector_screen.dart';
import 'package:leerlus/widgets/image_picker_field.dart';

class ImageClickSection extends StatelessWidget {
  final GlobalKey<ImagePickerFieldState> pickerKey;
  final String? imagePath;
  final List<List<Offset>> selectedImageAreas;
  final ValueChanged<String?> onImageChanged;
  final ValueChanged<List<List<Offset>>> onAreasChanged;

  const ImageClickSection({
    super.key,
    required this.pickerKey,
    required this.imagePath,
    required this.selectedImageAreas,
    required this.onImageChanged,
    required this.onAreasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImagePickerField(
          key: pickerKey,
          label: l10n.clickAreaImageLabel,
          initialPath: imagePath,
          onChanged: onImageChanged,
        ),
        const SizedBox(height: 12),
        if (imagePath != null && imagePath!.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<List<List<Offset>>>(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageAreaSelectorScreen(
                    imagePath: imagePath!,
                    initialAreas: selectedImageAreas,
                  ),
                ),
              );
              if (result != null) onAreasChanged(result);
            },
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(
              selectedImageAreas.isEmpty
                  ? l10n.defineClickAreas
                  : l10n.editClickAreas(selectedImageAreas.length),
            ),
          ),
        if (selectedImageAreas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.areasDefinedCount(selectedImageAreas.length),
              style: const TextStyle(color: Colors.green),
            ),
          ),
      ],
    );
  }
}
