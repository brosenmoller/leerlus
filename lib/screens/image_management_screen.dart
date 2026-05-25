import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/widgets/app_image.dart';

class ImageManagementScreen extends StatefulWidget {
  final AppDatabase db;

  const ImageManagementScreen({super.key, required this.db});

  @override
  State<ImageManagementScreen> createState() => _ImageManagementScreenState();
}

class _ImageManagementScreenState extends State<ImageManagementScreen> {
  List<_ImageInfo> _images = [];
  bool _loading = true;
  bool _showUnusedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final imgDir = await _getImagesDir();
    final rawUsageMap = await widget.db.getImageUsageMap();

    // In debug mode, folder/quiz icon paths are stored as relative
    // 'assets/images/...' strings. Convert them to absolute paths so they
    // match the entries from Directory.listSync() below.
    final Map<String, List<String>> usageMap;
    if (kDebugMode) {
      final base = Directory.current.path;
      usageMap = Map<String, List<String>>.from(rawUsageMap);
      for (final entry in rawUsageMap.entries) {
        if (entry.key.startsWith('assets/')) {
          final parts = entry.key.split('/');
          usageMap[p.joinAll([base, ...parts])] = entry.value;
        }
      }
    } else {
      usageMap = rawUsageMap;
    }

    // Bundled assets declared in pubspec.yaml — used to label built-in images.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundledAssets = manifest.listAssets().toSet();

    bool isBuiltIn(String absolutePath) {
      final rel = 'assets/images/${p.basename(absolutePath)}';
      return bundledAssets.contains(rel);
    }

    final files = <File>[];
    if (imgDir != null) {
      final dir = Directory(imgDir);
      if (dir.existsSync()) {
        files.addAll(
          dir.listSync().whereType<File>().where((f) => _isImageFile(f.path)),
        );
      }
    }

    final images = files
        .map((f) => _ImageInfo(
              path: f.path,
              filename: p.basename(f.path),
              usedBy: usageMap[f.path] ?? [],
              isBuiltIn: isBuiltIn(f.path),
            ))
        .toList()
      ..sort((a, b) => a.filename.compareTo(b.filename));

    // Also include any DB-referenced paths that exist on disk but weren't in
    // the directory listing (edge case: path stored differently).
    final seenPaths = images.map((i) => i.path).toSet();
    for (final entry in usageMap.entries) {
      if (!seenPaths.contains(entry.key) && File(entry.key).existsSync()) {
        images.add(_ImageInfo(
          path: entry.key,
          filename: p.basename(entry.key),
          usedBy: entry.value,
          isBuiltIn: isBuiltIn(entry.key),
        ));
      }
    }

    setState(() {
      _images = images;
      _loading = false;
    });
  }

  Future<String?> _getImagesDir() async {
    if (kDebugMode) {
      return '${Directory.current.path}/assets/images';
    }
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'images');
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }

  List<_ImageInfo> get _displayed =>
      _showUnusedOnly ? _images.where((i) => i.isUnused).toList() : _images;

  List<_ImageInfo> get _unusedImages => _images.where((i) => i.isUnused).toList();

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path;
    if (sourcePath == null) return;

    final fileName = p.basename(sourcePath);
    if (kDebugMode) {
      final dest = Directory(p.join(Directory.current.path, 'assets', 'images'));
      if (!dest.existsSync()) dest.createSync(recursive: true);
      await File(sourcePath).copy(p.join(dest.path, fileName));
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      final dest = Directory(p.join(docDir.path, 'images'));
      if (!dest.existsSync()) dest.createSync(recursive: true);
      await File(sourcePath).copy(p.join(dest.path, fileName));
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imageUploadSuccess)),
      );
    }
    await _load();
  }

  Future<void> _confirmDeleteUnused() async {
    final l10n = AppLocalizations.of(context);
    final unused = _unusedImages;
    if (unused.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.imageDeleteUnused),
        content: Text(l10n.imageDeleteUnusedConfirm(unused.length)),
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

    for (final img in unused) {
      try { await File(img.path).delete(); } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.imageDeleteUnusedSuccess(unused.length))),
    );
    await _load();
  }

  Future<void> _showImageDetail(_ImageInfo info) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ImageDetailDialog(
        info: info,
        l10n: l10n,
        onDelete: info.isUnused && AppDatabase.isUserImagePath(info.path)
            ? () async {
                Navigator.pop(ctx);
                try { await File(info.path).delete(); } catch (_) {}
                await _load();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayed = _displayed;
    final unusedCount = _unusedImages.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.imageLibraryTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showUnusedOnly
                  ? Icons.filter_list_off
                  : Icons.filter_list,
            ),
            tooltip: _showUnusedOnly ? l10n.imageLibraryTitle : l10n.imageNotUsed,
            onPressed: () => setState(() => _showUnusedOnly = !_showUnusedOnly),
          ),
          if (unusedCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.imageDeleteUnused,
              onPressed: _confirmDeleteUnused,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : displayed.isEmpty
              ? Center(child: Text(l10n.imageLibraryEmpty))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: displayed.length,
                  itemBuilder: (context, index) {
                    final img = displayed[index];
                    return _ImageTile(
                      info: img,
                      onTap: () => _showImageDetail(img),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadImage,
        tooltip: l10n.imageUpload,
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }
}

// ── Image tile ────────────────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  final _ImageInfo info;
  final VoidCallback onTap;

  const _ImageTile({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color badgeColor;
    final String badgeText;

    if (info.isBuiltIn) {
      badgeColor = Colors.blue.shade600;
      badgeText = l10n.imageBuiltIn;
    } else if (info.isUnused) {
      badgeColor = Colors.red;
      badgeText = l10n.imageNotUsed;
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
            AppImage(path: info.path, fit: BoxFit.cover),
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

// ── Image detail dialog ───────────────────────────────────────────────────────

class _ImageDetailDialog extends StatelessWidget {
  final _ImageInfo info;
  final AppLocalizations l10n;
  final VoidCallback? onDelete;

  const _ImageDetailDialog({
    required this.info,
    required this.l10n,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.imageUsedByTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: AppImage(path: info.path, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              info.filename,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (info.isBuiltIn)
              Text(
                l10n.imageBuiltIn,
                style: TextStyle(color: Colors.blue.shade600),
              ),
            if (info.isUnused)
              Text(
                l10n.imageNotUsed,
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
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.back),
        ),
        if (onDelete != null)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: onDelete,
            child: Text(l10n.delete),
          ),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ImageInfo {
  final String path;
  final String filename;
  final List<String> usedBy;
  final bool isBuiltIn;

  const _ImageInfo({
    required this.path,
    required this.filename,
    required this.usedBy,
    this.isBuiltIn = false,
  });

  bool get isUnused => usedBy.isEmpty && !isBuiltIn;
}
