import 'dart:io';
import 'package:flutter/material.dart';
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

    // Everything the library can offer lives in the content folder — nothing
    // ships bundled with the app any more. Entries carry the bare filename,
    // which is exactly what gets stored on a question.
    final dir = contentDir;
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (!_matchesKind(file.path)) continue;
        entries.add(_MediaEntry(
          name: p.basename(file.path),
          sizeBytes: file.statSync().size,
        ));
      }
    }

    entries.sort((a, b) => a.name.compareTo(b.name));
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
        .where((e) => e.name.toLowerCase().contains(q))
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
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final e in _filtered)
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: MediaThumbnail(path: e.name, size: 56),
            ),
            title: Text(e.name, style: const TextStyle(fontSize: 14)),
            subtitle: Text(e.readableSize,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            onTap: () => Navigator.pop(context, e.name),
          ),
      ],
    );
  }
}

class _MediaEntry {
  /// The bare filename — both what is shown and what gets stored.
  final String name;
  final int sizeBytes;

  const _MediaEntry({required this.name, required this.sizeBytes});

  String get readableSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).round()} KB';
    return '$sizeBytes B';
  }
}
