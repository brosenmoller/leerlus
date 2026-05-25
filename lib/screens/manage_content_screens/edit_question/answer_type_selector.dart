import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';

class AnswerTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const AnswerTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final answerTypes = [
      (value: 'multipleChoice', label: l10n.answerTypeMCLabel,         icon: Icons.list),
      (value: 'typed',          label: l10n.answerTypeTypedLabel,       icon: Icons.keyboard),
      (value: 'imageClick',     label: l10n.answerTypeImageClickLabel,  icon: Icons.mouse_rounded),
      (value: 'flashcard',      label: l10n.answerTypeFlashcardLabel,   icon: Icons.style_outlined),
      (value: 'sorting',        label: l10n.answerTypeSortingLabel,     icon: Icons.sort),
      (value: 'set',            label: l10n.answerTypeSetLabel,         icon: Icons.checklist_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 500) {
          return SegmentedButton<String>(
            segments: answerTypes
                .map((t) => ButtonSegment<String>(
                      value: t.value,
                      label: Text(t.label),
                      icon: Icon(t.icon),
                    ))
                .toList(),
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          );
        }

        return DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            labelText: l10n.answerTypeLabel,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: false,
          ),
          onChanged: (v) { if (v != null) onChanged(v); },
          items: answerTypes
              .map((t) => DropdownMenuItem(
                    value: t.value,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}
