import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/image_storage.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/media_preview.dart';

/// Picks an already-stored attachment of one [MediaKind] from the library.
///
/// Generalises the old image-only browser: the extension filter comes from
/// [extensionsFor] rather than a hardcoded list, so the same dialog serves
/// images, audio clips and video.
class MediaBrowserDialog extends StatefulWidget {
  final MediaKind kind;

  const MediaBrowserDialog({super.key, required this.kind});

  static Future<String?> show(BuildContext context, MediaKind kind) {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => MediaBrowserDialog(kind: kind),
    );
  }

  @override
  State<MediaBrowserDialog> createState() => _MediaBrowserDialogState();
}

class _MediaBrowserDialogState extends State<MediaBrowserDialog> {
  List<_MediaEntry> _entries = [];
  bool _loading = true;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  String get _noun => switch (widget.kind) {
        MediaKind.image => 'image',
        MediaKind.audio => 'audio clip',
        MediaKind.video => 'video',
      };

  String get _nounPlural => switch (widget.kind) {
        MediaKind.image => 'images',
        MediaKind.audio => 'audio clips',
        MediaKind.video => 'videos',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesKind(String path) =>
      extensionsFor(widget.kind).contains(p.extension(path).toLowerCase());

  Future<void> _load() async {
    final entries = <_MediaEntry>[];
    final bundledKeys = <String>{};

    // ── Bundled assets (content packs) ────────────────────────────
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final key in manifest.listAssets()) {
      if (key.startsWith('assets/images/') && _matchesKind(key)) {
        bundledKeys.add(key);
        entries.add(_MediaEntry(
          displayName: p.basename(key),
          path: key,
          source: 'Bundled',
        ));
      }
    }

    // ── Files in app storage ──────────────────────────────────────
    // Read through appImagesDir rather than the documents dir directly, so this
    // also finds debug-build attachments (which live in the repo's
    // assets/images/). Anything already listed from the bundle is skipped so a
    // debug asset doesn't appear twice.
    final dir = await appImagesDir();
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (!_matchesKind(file.path)) continue;
        final assetKey = 'assets/images/${p.basename(file.path)}';
        if (bundledKeys.contains(assetKey)) continue;
        entries.add(_MediaEntry(
          displayName: p.basename(file.path),
          path: file.path,
          source: 'My $_nounPlural',
        ));
      }
    }

    entries.sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<_MediaEntry> get _filtered {
    if (_search.isEmpty) return _entries;
    final q = _search.toLowerCase();
    return _entries
        .where((e) => e.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Choose existing $_noun',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onTap: collapseSelectionOnTap(_searchController),
                decoration: InputDecoration(
                  hintText: 'Search $_nounPlural...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _entries.isEmpty
                                ? 'No $_nounPlural found'
                                : 'No results for "$_search"',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : _buildGroupedList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = <String, List<_MediaEntry>>{};
    for (final e in _filtered) {
      groups.putIfAbsent(e.source, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              entry.key,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5),
            ),
          ),
          ...entry.value.map((e) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: SizedBox(
                  width: 56,
                  height: 56,
                  child: MediaThumbnail(path: e.path, size: 56),
                ),
                title:
                    Text(e.displayName, style: const TextStyle(fontSize: 14)),
                subtitle: Text(e.path,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, e.path),
              )),
        ],
      ],
    );
  }
}

class _MediaEntry {
  final String displayName;
  final String path;
  final String source;

  const _MediaEntry({
    required this.displayName,
    required this.path,
    required this.source,
  });
}
