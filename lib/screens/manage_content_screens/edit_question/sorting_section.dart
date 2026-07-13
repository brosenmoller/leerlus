import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';

class SortingSection extends StatelessWidget {
  final List<TextEditingController> itemControllers;
  final List<FocusNode> focusNodes;
  final bool showPreFilled;
  final ValueChanged<bool> onShowPreFilledChanged;
  final bool manualAddItems;
  final ValueChanged<bool> onManualAddItemsChanged;
  final VoidCallback onAddItem;
  final ValueChanged<int> onRemoveItem;

  const SortingSection({
    super.key,
    required this.itemControllers,
    required this.focusNodes,
    required this.showPreFilled,
    required this.onShowPreFilledChanged,
    required this.manualAddItems,
    required this.onManualAddItemsChanged,
    required this.onAddItem,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRemove = itemControllers.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.sortingItemsLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              '${itemControllers.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.sortingItemsHelp,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        ...itemControllers.asMap().entries.map((e) {
          final i = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Position badge
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    focusNode: focusNodes[i],
                    onTap: collapseSelectionOnTap(e.value),
                    decoration: InputDecoration(
                      labelText: l10n.sortingItemN(i + 1),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return l10n.required;
                      final trimmed = v.trim().toLowerCase();
                      for (int j = 0; j < itemControllers.length; j++) {
                        if (j != i &&
                            itemControllers[j].text.trim().toLowerCase() ==
                                trimmed) {
                          return l10n.duplicateOption;
                        }
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: canRemove ? Colors.red : Colors.grey,
                  ),
                  onPressed: canRemove ? () => onRemoveItem(i) : null,
                ),
              ],
            ),
          );
        }),

        TextButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add),
          label: Text(l10n.addItem),
        ),
        const SizedBox(height: 4),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showPreFilled),
          subtitle: Text(l10n.showPreFilledSubtitle),
          value: showPreFilled,
          onChanged: onShowPreFilledChanged,
        ),

        // Manual-add only applies to typed mode; drag mode always shows the chips.
        if (!showPreFilled)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.sortingManualAddItems),
            subtitle: Text(l10n.sortingManualAddItemsSubtitle),
            value: manualAddItems,
            onChanged: onManualAddItemsChanged,
          ),
      ],
    );
  }
}
