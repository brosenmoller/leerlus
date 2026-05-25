import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';

class TypedAnswerSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAddVariant;
  final ValueChanged<int> onRemoveVariant;

  const TypedAnswerSection({
    super.key,
    required this.controllers,
    required this.onAddVariant,
    required this.onRemoveVariant,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.acceptedAnswersLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...controllers.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    decoration: InputDecoration(
                      labelText: l10n.acceptedAnswerN(e.key + 1),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        e.key == 0 && v!.trim().isEmpty
                            ? l10n.atLeastOneRequired
                            : null,
                  ),
                ),
                if (e.key > 0)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => onRemoveVariant(e.key),
                  ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAddVariant,
          icon: const Icon(Icons.add),
          label: Text(l10n.addVariant),
        ),
      ],
    );
  }
}
