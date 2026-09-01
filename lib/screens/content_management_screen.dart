import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/utils/image_storage.dart';
import 'package:leerlus/utils/text_field_selection_fix.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/media_attachment_button.dart';
import 'package:leerlus/widgets/media_player_widget.dart';
import 'package:leerlus/widgets/media_preview.dart';
import 'package:leerlus/widgets/screen_shortcuts.dart';

/// Browses everything sitting in the content folder — images, audio and video
/// alike — and shows what each file is used by, so an orphan can be found and
/// deleted.
class ContentManagementScreen extends StatefulWidget {
  final AppDatabase db;

  const ContentManagementScreen({super.key, required this.db});

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  List<_ContentInfo> _files = [];
  bool _loading = true;
  bool _showUnusedOnly = false;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _searching = false;
  String _query = '';

  /// Which kinds the grid shows. All three on by default — the library is for
  /// finding one file, and starting from "nothing is shown" would mean a chip
  /// tap before every visit.
  final Set<MediaKind> _kinds = {...MediaKind.values};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Ctrl+F and the search action. Pressing it again with the bar already open
  /// puts the caret back in the field instead of doing nothing.
  ///
  /// Focus is requested imperatively rather than with `autofocus: true`:
  /// [ScreenShortcuts] wraps the screen in its own autofocusing [Focus], and
  /// competing autofocus requests resolve first-registered-wins.
  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Stored references and directory entries are both bare filenames, so they
    // compare directly — this used to need a debug-mode asset-key remap and a
    // separate pass for paths that had been stored in a different form.
    final usageMap = await widget.db.getImageUsageMap();

    final files = <_ContentInfo>[];
    if (contentDir.existsSync()) {
      for (final f in contentDir.listSync().whereType<File>()) {
        // Any attachable media, not only pictures — audio and video live in the
        // same directory and would otherwise be invisible here, leaving an
        // orphaned clip with no way to find or delete it.
        if (!isMediaPath(f.path)) continue;
        final name = p.basename(f.path);
        files.add(_ContentInfo(
          path: name,
          filename: name,
          kind: mediaKindOf(name),
          usedBy: usageMap[name] ?? [],
        ));
      }
    }
    files.sort((a, b) => a.filename.compareTo(b.filename));

    setState(() {
      _files = files;
      _loading = false;
    });
  }

  /// Everything currently on screen: the kind chips, the search text and the
  /// unused-only toggle applied in turn.
  List<_ContentInfo> get _displayed {
    final query = _query.trim().toLowerCase();
    return _files.where((f) {
      if (!_kinds.contains(f.kind)) return false;
      if (_showUnusedOnly && !f.isUnused) return false;
      if (query.isNotEmpty && !f.filename.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// The unused files *among those on screen*. The sweep deletes what the user
  /// can actually see, so a filtered view can never take out files it is
  /// hiding — and the count in the confirmation matches the grid.
  List<_ContentInfo> get _unusedFiles =>
      _displayed.where((i) => i.isUnused).toList();

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // allMediaExtensions carries the leading dot; file_picker wants it off.
      allowedExtensions: allMediaExtensions.map((e) => e.substring(1)).toList(),
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path;
    if (sourcePath == null) return;

    if (!mounted) return;
    if (!await confirmIfLargeMedia(context, sourcePath)) return;

    final stored = await copyMediaIntoStorage(sourcePath);
    if (stored == null) return;

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.contentUploadSuccess)),
      );
    }
    await _load();
  }

  Future<void> _confirmDeleteUnused() async {
    final l10n = AppLocalizations.of(context);
    final unused = _unusedFiles;
    if (unused.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.contentDeleteUnused),
        content: Text(l10n.contentDeleteUnusedConfirm(unused.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    for (final file in unused) {
      await deleteAppImageFile(file.path);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contentDeleteUnusedSuccess(unused.length))),
    );
    await _load();
  }

  Future<void> _showDetail(_ContentInfo info) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ContentDetailDialog(
        info: info,
        l10n: l10n,
        onDelete: info.isUnused && AppDatabase.isUserImagePath(info.path)
            ? () async {
                Navigator.pop(ctx);
                await deleteAppImageFile(info.path);
                await _load();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScreenShortcuts(
      onSearch: _startSearch,
      onNew: _uploadMedia,
      // Escape / back closes the search bar before leaving the screen.
      onEscape: _searching ? _stopSearch : null,
      child: _buildScaffold(l10n),
    );
  }

  Widget _buildScaffold(AppLocalizations l10n) {
    final displayed = _displayed;
    final unusedCount = _unusedFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onTap: collapseSelectionOnTap(_searchController),
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: l10n.contentSearchHint,
                  border: InputBorder.none,
                ),
              )
            : Text(l10n.contentLibraryTitle),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: l10n.searchTooltip,
            onPressed: _searching ? _stopSearch : _startSearch,
          ),
          IconButton(
            icon: Icon(
              _showUnusedOnly
                  ? Icons.filter_list_off
                  : Icons.filter_list,
            ),
            tooltip: _showUnusedOnly
                ? l10n.contentLibraryTitle
                : l10n.contentNotUsed,
            onPressed: () => setState(() => _showUnusedOnly = !_showUnusedOnly),
          ),
          if (unusedCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.contentDeleteUnused,
              onPressed: _confirmDeleteUnused,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    _buildKindChips(l10n),
                    Expanded(
                      child: displayed.isEmpty
                          ? Center(child: Text(_emptyLabel(l10n)))
                          : _buildGrid(displayed),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadMedia,
        tooltip: l10n.contentUpload,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  /// "Nothing here at all" and "nothing matches" are different problems, and
  /// only the second one is the user's to fix.
  String _emptyLabel(AppLocalizations l10n) =>
      _files.isEmpty ? l10n.contentLibraryEmpty : l10n.searchNoResults;

  /// Always visible, not just while searching: narrowing to clips is as much a
  /// browsing tool as a search one.
  Widget _buildKindChips(AppLocalizations l10n) {
    Widget chip(MediaKind kind, String label) => FilterChip(
          avatar: Icon(iconForMediaKind(kind), size: 18),
          label: Text(label),
          selected: _kinds.contains(kind),
          onSelected: (on) => setState(() {
            if (on) {
              _kinds.add(kind);
            } else {
              _kinds.remove(kind);
            }
          }),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          chip(MediaKind.image, l10n.contentFilterImages),
          chip(MediaKind.audio, l10n.contentFilterAudio),
          chip(MediaKind.video, l10n.contentFilterVideo),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_ContentInfo> displayed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on narrow (mobile), scaling up for wider windows.
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 8);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: displayed.length,
          itemBuilder: (context, index) {
            final file = displayed[index];
            return _ContentTile(
              info: file,
              onTap: () => _showDetail(file),
            );
          },
        );
      },
    );
  }
}

// ── Content tile ──────────────────────────────────────────────────────────────

class _ContentTile extends StatelessWidget {
  final _ContentInfo info;
  final VoidCallback onTap;

  const _ContentTile({required this.info, required this.onTap});

  /// Audio and video have no still to show. They get a tinted icon tile rather
  /// than [MediaThumbnail], which at this size draws the basename itself and
  /// would double up with the caption this tile already stacks on top.
  Widget _preview(BuildContext context) {
    final kind = info.kind;
    if (kind.isImage) return AppImage(path: info.path, fit: BoxFit.cover);

    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        color: scheme.secondaryContainer,
        alignment: Alignment.center,
        child: Icon(
          iconForMediaKind(kind),
          size: constraints.maxWidth * 0.4,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color badgeColor;
    final String badgeText;

    if (info.isUnused) {
      badgeColor = Colors.red;
      badgeText = l10n.contentNotUsed;
    } else {
      badgeColor = Colors.white24;
      badgeText = '${info.usedBy.length}';
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(context),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        info.filename,
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content detail dialog ─────────────────────────────────────────────────────

/// One file at full size, with the list of what references it.
///
/// A bare [Dialog], not an [AlertDialog], for the reason spelled out on
/// [MediaPreviewDialog]: AlertDialog wraps its column in an `IntrinsicWidth`,
/// so the only way to stop it collapsing is `width: double.maxFinite` — which
/// pins the box to the whole window and leaves a short, extremely wide preview
/// band. Stating the size outright gives a picture as tall as it is wide.
class _ContentDetailDialog extends StatelessWidget {
  final _ContentInfo info;
  final AppLocalizations l10n;
  final VoidCallback? onDelete;

  const _ContentDetailDialog({
    required this.info,
    required this.l10n,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = info.kind;

    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 48, 800.0);
    final mediaHeight = (screen.height * 0.55).clamp(240.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: screen.height - 64,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    l10n.contentUsedByTitle,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _media(kind, mediaHeight, width),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(info.filename, style: theme.textTheme.bodySmall),
            ),
            // Flexible so a file used by dozens of quizzes scrolls its own list
            // instead of pushing the dialog past maxHeight.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (info.isUnused)
                      Text(
                        l10n.contentNotUsed,
                        style: TextStyle(color: Colors.red.shade400),
                      )
                    else if (info.usedBy.isNotEmpty) ...[
                      const Divider(),
                      ...info.usedBy.map(
                        (name) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.quiz_outlined, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: onDelete,
                      child: Text(l10n.delete),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Audio deliberately skips the tall box: it renders a fixed-height transport
  /// bar, and 560dp of empty space around a scrubber is just dead air.
  Widget _media(MediaKind kind, double mediaHeight, double width) {
    // Centred: both players cap their own width (audio at 520dp, video at its
    // aspect ratio), and the column aligns to start, so without this they hug
    // the left edge of a wide dialog.
    if (kind.isAudio) {
      return Center(
        child: MediaPlayerWidget(path: info.path, maxWidth: width - 32),
      );
    }
    if (kind.isVideo) {
      return Center(
        child: MediaPlayerWidget(
          path: info.path,
          maxHeight: mediaHeight,
          maxWidth: width - 32,
        ),
      );
    }
    return SizedBox(
      height: mediaHeight,
      width: double.infinity,
      child: AppImage(path: info.path, fit: BoxFit.contain),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ContentInfo {
  final String path;
  final String filename;

  /// Derived once at load: the kind chips re-filter on every keystroke and
  /// every tile asks for it again while painting.
  final MediaKind kind;
  final List<String> usedBy;

  const _ContentInfo({
    required this.path,
    required this.filename,
    required this.kind,
    required this.usedBy,
  });

  bool get isUnused => usedBy.isEmpty;
}
