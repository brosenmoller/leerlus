import 'package:flutter/material.dart';

class ImageClickConfig {
  /// List of polygons. Each polygon is a list of normalized (0.0–1.0) points.
  final List<List<Offset>> correctAreas;

  ImageClickConfig({required this.correctAreas});

  bool isCorrect(Offset tapPosition) {
    return correctAreas.any(
      (polygon) => polygon.length >= 3 && _containsPoint(polygon, tapPosition),
    );
  }

  /// Ray-casting point-in-polygon test (normalized coordinates).
  static bool _containsPoint(List<Offset> polygon, Offset point) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          point.dx <
              (polygon[j].dx - polygon[i].dx) *
                      (point.dy - polygon[i].dy) /
                      (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  factory ImageClickConfig.fromJson(Map<String, dynamic> json) {
    // Backward compatibility: old format stored a single rect as 'correctArea'.
    if (json.containsKey('correctArea') && !json.containsKey('correctAreas')) {
      final area = json['correctArea'] as Map<String, dynamic>;
      final l = (area['left'] as num).toDouble();
      final t = (area['top'] as num).toDouble();
      final r = (area['right'] as num).toDouble();
      final b = (area['bottom'] as num).toDouble();
      return ImageClickConfig(correctAreas: [
        [Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b)],
      ]);
    }

    final areas = json['correctAreas'] as List<dynamic>;
    return ImageClickConfig(
      correctAreas: areas.map((polygon) {
        return (polygon as List<dynamic>)
            .map((p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ))
            .toList();
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'correctAreas': correctAreas
            .map((polygon) =>
                polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList())
            .toList(),
      };
}

class FlashcardConfig {
  final String? frontText;
  final String? frontImagePath;
  final String? backText;
  final String? backImagePath;
  final bool randomizeSides;

  FlashcardConfig({
    this.frontText,
    this.frontImagePath,
    this.backText,
    this.backImagePath,
    this.randomizeSides = false,
  });

  factory FlashcardConfig.fromJson(Map<String, dynamic> json) {
    return FlashcardConfig(
      frontText: json['frontText'] as String?,
      frontImagePath: json['frontImagePath'] as String?,
      backText: json['backText'] as String?,
      backImagePath: json['backImagePath'] as String?,
      randomizeSides: json['randomizeSides'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (frontText != null) map['frontText'] = frontText;
    if (frontImagePath != null) map['frontImagePath'] = frontImagePath;
    if (backText != null) map['backText'] = backText;
    if (backImagePath != null) map['backImagePath'] = backImagePath;
    if (randomizeSides) map['randomizeSides'] = true;
    return map;
  }
}

class MultipleChoiceConfig {
  final List<String> options;
  final List<int> correctIndices;
  final bool scrambleOptions;
  final bool multipleCorrect;
  final bool showCorrectCount;

  MultipleChoiceConfig({
    required this.options,
    required this.correctIndices,
    this.scrambleOptions = true,
    this.multipleCorrect = false,
    this.showCorrectCount = false,
  });

  /// Backward-compat accessor for code that still reads a single index.
  int get correctIndex => correctIndices.isNotEmpty ? correctIndices.first : 0;

  factory MultipleChoiceConfig.fromJson(Map<String, dynamic> json) {
    List<int> indices;
    if (json.containsKey('correctIndices')) {
      indices = List<int>.from(json['correctIndices'] as List);
    } else if (json.containsKey('correctIndex')) {
      indices = [json['correctIndex'] as int];
    } else {
      indices = [0];
    }
    return MultipleChoiceConfig(
      options: List<String>.from(json['options'] ?? []),
      correctIndices: indices,
      scrambleOptions: json['scrambleOptions'] as bool? ?? true,
      multipleCorrect: json['multipleCorrect'] as bool? ?? false,
      showCorrectCount: json['showCorrectCount'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'options': options,
    'correctIndices': correctIndices,
    'scrambleOptions': scrambleOptions,
    if (multipleCorrect) 'multipleCorrect': true,
    if (showCorrectCount) 'showCorrectCount': true,
  };
}

class SortingConfig {
  /// Items in the correct order (top → bottom).
  final List<String> items;

  /// Extra accepted forms, parallel to [items]. `alternatives[i]` widens the
  /// matching for `items[i]` in typed mode without surfacing to the student.
  final List<List<String>> alternatives;

  /// When true, the quiz shows items scrambled as draggable chips.
  /// When false, the quiz shows text fields the user must fill in.
  final bool showPreFilled;

  /// Typed mode only: when true the student is not shown a fixed number of
  /// blank fields (which would leak the item count) and instead adds each
  /// entry manually before ordering them.
  final bool manualAddItems;

  SortingConfig({
    required this.items,
    List<List<String>>? alternatives,
    this.showPreFilled = true,
    this.manualAddItems = false,
  }) : alternatives = _sizeAlternatives(items, alternatives);

  static List<List<String>> _sizeAlternatives(
      List<String> items, List<List<String>>? alternatives) {
    return [
      for (var i = 0; i < items.length; i++)
        (alternatives != null && i < alternatives.length)
            ? List<String>.from(alternatives[i])
            : <String>[],
    ];
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// All accepted spellings for slot [i] (canonical item first).
  List<String> formsAt(int i) => [items[i], ...alternatives[i]];

  /// Whether [input] matches the item at position [i] (normalized, so
  /// case- and punctuation-insensitive), taking alternatives into account.
  bool matchesAt(int i, String input) {
    final norm = _normalize(input);
    return formsAt(i).any((f) => _normalize(f) == norm);
  }

  factory SortingConfig.fromJson(Map<String, dynamic> json) {
    List<List<String>>? alternatives;
    if (json['alternatives'] is List) {
      alternatives = [
        for (final e in json['alternatives'] as List) List<String>.from(e ?? []),
      ];
    }
    return SortingConfig(
      items: List<String>.from(json['items'] ?? []),
      alternatives: alternatives,
      showPreFilled: json['showPreFilled'] as bool? ?? true,
      manualAddItems: json['manualAddItems'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items,
        if (alternatives.any((a) => a.isNotEmpty)) 'alternatives': alternatives,
        'showPreFilled': showPreFilled,
        if (manualAddItems) 'manualAddItems': manualAddItems,
      };
}

/// One required Set slot: a canonical answer plus alternative accepted forms.
class SetAnswerGroup {
  final String canonical;
  final List<String> alternatives;

  SetAnswerGroup({required this.canonical, this.alternatives = const []});

  /// All accepted spellings for this slot (canonical first).
  List<String> get forms => [canonical, ...alternatives];
}

class SetConfig {
  /// Canonical answers (one per required slot), shown as the "correct" answer.
  final List<String> answers;

  /// Extra accepted forms, parallel to [answers]. `alternatives[i]` widens the
  /// matching for `answers[i]` without surfacing to the student.
  final List<List<String>> alternatives;

  SetConfig({required this.answers, List<List<String>>? alternatives})
      : alternatives = _sizeAlternatives(answers, alternatives);

  static List<List<String>> _sizeAlternatives(
      List<String> answers, List<List<String>>? alternatives) {
    return [
      for (var i = 0; i < answers.length; i++)
        (alternatives != null && i < alternatives.length)
            ? List<String>.from(alternatives[i])
            : <String>[],
    ];
  }

  /// Grouped view (canonical + alternatives) for grading.
  List<SetAnswerGroup> get groups => [
        for (var i = 0; i < answers.length; i++)
          SetAnswerGroup(canonical: answers[i], alternatives: alternatives[i]),
      ];

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Returns the canonical answer whose accepted forms match [input], or null
  /// if none. Removes the matched group from [remaining] so each slot can only
  /// be claimed once per submission.
  static String? claimMatch(String input, List<SetAnswerGroup> remaining) {
    final norm = _normalize(input);
    final idx = remaining
        .indexWhere((g) => g.forms.any((f) => _normalize(f) == norm));
    if (idx == -1) return null;
    return remaining.removeAt(idx).canonical;
  }

  factory SetConfig.fromJson(Map<String, dynamic> json) {
    final answers = List<String>.from(json['answers'] ?? []);
    List<List<String>>? alternatives;
    if (json['alternatives'] is List) {
      alternatives = [
        for (final e in json['alternatives'] as List) List<String>.from(e ?? []),
      ];
    }
    return SetConfig(answers: answers, alternatives: alternatives);
  }

  Map<String, dynamic> toJson() => {
        'answers': answers,
        if (alternatives.any((a) => a.isNotEmpty)) 'alternatives': alternatives,
      };
}

class TypedAnswerConfig {
  final List<String> acceptedAnswers;

  TypedAnswerConfig({
    required this.acceptedAnswers,
  });

  bool isCorrect(String input) {
    String normalize(String text) {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final normalizedInput = normalize(input);

    return acceptedAnswers
        .map((a) => normalize(a))
        .contains(normalizedInput);
  }

  factory TypedAnswerConfig.fromJson(Map<String, dynamic> json) {
    return TypedAnswerConfig(
      acceptedAnswers: List<String>.from(json['acceptedAnswers'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'acceptedAnswers': acceptedAnswers,
  };
}
