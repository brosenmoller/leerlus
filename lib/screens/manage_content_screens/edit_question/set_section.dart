import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';

class SetSection extends StatelessWidget {
  final List<TextEditingController> answerControllers;
  final VoidCallback onAddAnswer;
  final ValueChanged<int> onRemoveAnswer;

  const SetSection({
    super.key,
    required this.answerControllers,
    required this.onAddAnswer,
    required this.onRemoveAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRemove = answerControllers.length > 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.setAnswersLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        ...answerControllers.asMap().entries.map((e) {
          final i = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    decoration: InputDecoration(
                      labelText: l10n.setAnswerN(i + 1),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v!.trim().isEmpty) return l10n.required;
                      final trimmed = v.trim().toLowerCase();
                      for (int j = 0; j < answerControllers.length; j++) {
                        if (j != i &&
                            answerControllers[j].text.trim().toLowerCase() ==
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
                  onPressed: canRemove ? () => onRemoveAnswer(i) : null,
                ),
              ],
            ),
          );
        }),

        TextButton.icon(
          onPressed: onAddAnswer,
          icon: const Icon(Icons.add),
          label: Text(l10n.setAddAnswer),
        ),
      ],
    );
  }
}
