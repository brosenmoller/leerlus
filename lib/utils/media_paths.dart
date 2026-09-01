import 'dart:convert';

import 'package:path/path.dart' as p;

/// Reducing every media reference on a question to a bare filename.
///
/// Two callers need the identical transformation and must not drift apart:
/// [SyncService] normalizes before putting a question on the wire (an absolute
/// path is meaningless on the receiving device), and the one-time content-folder
/// migration normalizes what is already in the database. Both are `p.basename`
/// applied to the same awkward set of places.
///
/// Optionally collects the filenames it produces into [collect], which sync uses
/// to build the list of files it must transfer.

/// Flashcard front/back images live inside `answerConfig`, not in a column.
Map<String, dynamic> basenameConfigImagePaths(
  Map<String, dynamic> config,
  String answerType, {
  Set<String>? collect,
}) {
  if (answerType != 'flashcard') return config;
  final result = Map<String, dynamic>.from(config);
  for (final key in const ['frontImagePath', 'backImagePath']) {
    final value = result[key];
    if (value is! String || value.isEmpty) continue;
    final name = p.basename(value);
    collect?.add(name);
    result[key] = name;
  }
  return result;
}

/// The `perImage` map in `occlusionConfig` is keyed **by image path**, which is
/// why a migration modelled on the column list alone would silently detach every
/// occlusion from its image.
///
/// Flashcard occlusion is keyed `'front'`/`'back'` rather than by path, so those
/// keys are left exactly as they are.
Map<String, dynamic>? basenameOcclusionConfig(
  Object? occlusionConfigRaw,
  String answerType, {
  Set<String>? collect,
}) {
  if (occlusionConfigRaw == null) return null;
  final Map<String, dynamic> config;
  try {
    config = occlusionConfigRaw is String
        ? Map<String, dynamic>.from(jsonDecode(occlusionConfigRaw) as Map)
        : Map<String, dynamic>.from(occlusionConfigRaw as Map);
  } catch (_) {
    return null;
  }
  if (config['v'] != 2) return config;
  if (answerType == 'flashcard') return config;
  final perImage = Map<String, dynamic>.from(config['perImage'] as Map);
  final normalized = <String, dynamic>{};
  for (final entry in perImage.entries) {
    final name = p.basename(entry.key);
    collect?.add(name);
    normalized[name] = entry.value;
  }
  return {'v': 2, 'perImage': normalized};
}

/// The `imagePathVariants` JSON array, reduced to filenames.
List<String>? basenameVariants(String? variantsJson, {Set<String>? collect}) {
  if (variantsJson == null) return null;
  try {
    final decoded = jsonDecode(variantsJson) as List;
    final names = <String>[];
    for (final v in decoded) {
      if (v is! String || v.isEmpty) continue;
      final name = p.basename(v);
      collect?.add(name);
      names.add(name);
    }
    return names;
  } catch (_) {
    return null;
  }
}
