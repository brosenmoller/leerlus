import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_image.dart';
import 'image_browser_dialog.dart';

String _toSlug(String text, {int maxLength = 40}) {
  final slug = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.length > maxLength ? slug.substring(0, maxLength) : slug;
}

class ImagePickerField extends StatefulWidget {
  final String? initialPath;
  final ValueChanged<String?> onChanged;
  final String label;

  const ImagePickerField({
    super.key,
    this.initialPath,
    required this.onChanged,
    this.label = 'Image',
  });

  @override
  State<ImagePickerField> createState() => ImagePickerFieldState();
}

class ImagePickerFieldState extends State<ImagePickerField> {
  String? _currentPath;
  bool _dragging = false;
  bool _autoName = true;
  // True only when the user picked/dropped a new file in this session;
  // false for the initial path or images chosen from the existing browser.
  bool _needsRename = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
  }

  /// Copy a new file into the app images directory using its original filename.
  Future<String> _saveImage(String sourcePath) async {
    final fileName = p.basename(sourcePath);

    if (kDebugMode) {
      final dest = Directory(
          p.join(Directory.current.path, 'assets', 'images'));
      if (!dest.existsSync()) dest.createSync(recursive: true);
      await File(sourcePath).copy(p.join(dest.path, fileName));
      return 'assets/images/$fileName';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dest = Directory(p.join(dir.path, 'images'));
      if (!dest.existsSync()) dest.createSync(recursive: true);
      final destPath = p.join(dest.path, fileName);
      await File(sourcePath).copy(destPath);
      return destPath;
    }
  }

  /// Called from the parent's save method.
  /// If auto-naming is enabled and the user picked a new file this session,
  /// renames the stored file to match [suggestedName] and returns the new path.
  /// Otherwise returns the current path unchanged.
  Future<String?> applyAutoName(String suggestedName) async {
    if (!_autoName || !_needsRename || _currentPath == null) {
      return _currentPath;
    }

    final path = _currentPath!;
    final ext = p.extension(path);
    final slug = _toSlug(suggestedName);
    if (slug.isEmpty) return path;

    final newFileName = '$slug$ext';
    String newPath;

    if (kDebugMode) {
      final destDir = Directory(
          p.join(Directory.current.path, 'assets', 'images'));
      final srcFile = File(p.join(destDir.path, p.basename(path)));
      newPath = 'assets/images/$newFileName';
      final dstFile = File(p.join(destDir.path, newFileName));
      if (srcFile.existsSync() && srcFile.path != dstFile.path) {
        await srcFile.rename(dstFile.path);
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(dir.path, 'images'));
      newPath = p.join(imgDir.path, newFileName);
      final srcFile = File(path);
      if (srcFile.existsSync() && path != newPath) {
        await srcFile.rename(newPath);
      }
    }

    setState(() {
      _currentPath = newPath;
      _needsRename = false;
    });
    widget.onChanged(newPath);
    return newPath;
  }

  Future<void> _pickFromExisting() async {
    final picked = await ImageBrowserDialog.show(context);
    if (picked == null) return;
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _currentPath = picked;
        _needsRename = false; // existing image — never rename
        _autoName = false;    // force off: renaming would affect other content
      });
      widget.onChanged(picked);
    }
  }

  Future<void> _pickFromExplorer() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.single.path == null) return;
    final saved = await _saveImage(result!.files.single.path!);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _currentPath = saved;
        _needsRename = true;
      });
      widget.onChanged(saved);
    }
  }

  Future<void> _handleDrop(String sourcePath) async {
    final ext = p.extension(sourcePath).toLowerCase();
    const allowed = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    if (!allowed.contains(ext)) return;
    final saved = await _saveImage(sourcePath);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _currentPath = saved;
        _needsRename = true;
      });
      widget.onChanged(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        // ── Drop zone ─────────────────────────────────────────────
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (detail) {
            setState(() => _dragging = false);
            if (detail.files.isNotEmpty) {
              _handleDrop(detail.files.first.path);
            }
          },
          child: GestureDetector(
            onTap: _pickFromExplorer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dragging
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  width: _dragging ? 2 : 1,
                ),
                color: _dragging
                    ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.07)
                    : Colors.grey.shade50,
              ),
              child: _currentPath != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: AppImage(
                  path: _currentPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 36, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text('Click or drag an image here',
                      style:
                      TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Action buttons ────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromExplorer,
                icon: const Icon(Icons.file_open_outlined, size: 16),
                label: const Text('New image'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromExisting,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Existing image'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
            if (_currentPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: 'Remove image',
                onPressed: () {
                  setState(() {
                    _currentPath = null;
                    _needsRename = false;
                  });
                  widget.onChanged(null);
                },
              ),
            ],
          ],
        ),

        // ── Auto-name toggle ──────────────────────────────────────
        // Only available for newly picked files; disabled for existing images
        // to prevent renaming a file that other content may depend on.
        Row(
          children: [
            Checkbox(
              value: _autoName,
              // Disable when not a new file — the user chose an existing image
              onChanged: _needsRename
                  ? (v) => setState(() => _autoName = v ?? true)
                  : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(
              _needsRename
                  ? 'Auto-name image from title on save'
                  : _currentPath != null
                      ? 'Auto-name disabled (existing image)'
                      : 'Auto-name (pick a new image to enable)',
              style: TextStyle(
                fontSize: 12,
                color: _needsRename
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),

        if (_currentPath != null) ...[
          const SizedBox(height: 4),
          Text(
            _currentPath!,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 4),
        Text(
          kDebugMode
              ? 'New images saved to assets/images/'
              : 'New images saved to local app storage',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}
