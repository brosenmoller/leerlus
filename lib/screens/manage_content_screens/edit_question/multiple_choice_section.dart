import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';

class MultipleChoiceSection extends StatelessWidget {
  final List<TextEditingController> optionControllers;
  final List<FocusNode> focusNodes;
  final Set<int> correctIndices;
  final bool multipleCorrectEnabled;
  final bool showCorrectCount;
  final ValueChanged<Set<int>> onCorrectIndicesChanged;
  final ValueChanged<bool> onMultipleCorrectChanged;
  final ValueChanged<bool> onShowCorrectCountChanged;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;

  const MultipleChoiceSection({
    super.key,
    required this.optionControllers,
    required this.focusNodes,
    required this.correctIndices,
    required this.multipleCorrectEnabled,
    required this.showCorrectCount,
    required this.onCorrectIndicesChanged,
    required this.onMultipleCorrectChanged,
    required this.onShowCorrectCountChanged,
    required this.onAddOption,
    required this.onRemoveOption,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRemove = optionControllers.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.optionsLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              '${optionControllers.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...optionControllers.asMap().entries.map((e) {
          final i = e.key;
          final isCorrect = correctIndices.contains(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (multipleCorrectEnabled)
                  Checkbox(
                    value: isCorrect,
                    onChanged: (checked) {
                      final updated = Set<int>.from(correctIndices);
                      if (checked!) {
                        updated.add(i);
                      } else if (updated.length > 1) {
                        updated.remove(i);
                      }
                      onCorrectIndicesChanged(updated);
                    },
                  )
                else
                  Radio<int>(
                    value: i,
                    groupValue: correctIndices.isEmpty ? -1 : correctIndices.first,
                    onChanged: (v) => onCorrectIndicesChanged({v!}),
                  ),
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    focusNode: focusNodes[i],
                    onTap: collapseSelectionOnTap(e.value),
                    decoration: InputDecoration(
                      labelText: l10n.optionN(i + 1),
                      border: const OutlineInputBorder(),
                      fillColor: isCorrect ? Colors.green.withValues(alpha: 0.1) : null,
                      filled: isCorrect,
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return l10n.required;
                      final trimmed = v.trim().toLowerCase();
                      for (int j = 0; j < optionControllers.length; j++) {
                        if (j != i &&
                            optionControllers[j].text.trim().toLowerCase() ==
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
                  onPressed: canRemove ? () => onRemoveOption(i) : null,
                ),
              ],
            ),
          );
        }),

        TextButton.icon(
          onPressed: onAddOption,
          icon: const Icon(Icons.add),
          label: Text(l10n.addOption),
        ),
        const SizedBox(height: 4),

        Text(
          multipleCorrectEnabled ? l10n.checkboxCorrectHint : l10n.radioCorrectHint,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.green),
        ),
        const SizedBox(height: 4),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.multipleCorrectAnswers),
          value: multipleCorrectEnabled,
          onChanged: onMultipleCorrectChanged,
        ),

        if (multipleCorrectEnabled)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.showCorrectCount),
            subtitle: Text(l10n.showCorrectCountSubtitle),
            value: showCorrectCount,
            onChanged: onShowCorrectCountChanged,
          ),
      ],
    );
  }
}
