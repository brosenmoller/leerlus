import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/screens/manage_content_screens/image_occlusion_selector_screen.dart';

class OcclusionSection extends StatelessWidget {
  /// The image path to draw occlusion on. Null means no image is set yet.
  final String? imagePathForOcclusion;

  /// Current occlusion data, or null if none defined.
  final OcclusionData? occlusionData;

  /// Called with updated data (or null to clear).
  final ValueChanged<OcclusionData?> onChanged;

  const OcclusionSection({
    super.key,
    required this.imagePathForOcclusion,
    required this.occlusionData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasImage =
        imagePathForOcclusion != null && imagePathForOcclusion!.isNotEmpty;
    final hasData = occlusionData != null && !occlusionData!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.occlusionSectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (!hasImage)
          Text(
            l10n.occlusionNoImage,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () async {
              final result =
                  await Navigator.push<OcclusionData>(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageOcclusionSelectorScreen(
                    imagePath: imagePathForOcclusion!,
                    initialData: occlusionData ??
                        const OcclusionData(
                          hiddenAreas: [],
                          highlights: [],
                        ),
                  ),
                ),
              );
              if (result != null) onChanged(result);
            },
            icon: const Icon(Icons.layers_outlined),
            label: Text(
              hasData ? l10n.editOcclusionAreas : l10n.defineOcclusionAreas,
            ),
          ),
          if (hasData) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  l10n.occlusionSummary(
                    occlusionData!.hiddenAreas.length,
                    occlusionData!.highlights.length,
                  ),
                  style: const TextStyle(color: Colors.green, fontSize: 13),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Text(
                    l10n.occlusionClear,
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
