import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/image_storage.dart';
import 'package:leerlus/widgets/media_browser_dialog.dart';
import 'package:leerlus/widgets/media_preview.dart';

/// Where a newly attached file comes from.
enum MediaSource {
  /// The OS file picker.
  newFile,

  /// The app's own media library ([MediaBrowserDialog]).
  existing,
}

/// Big attachments are allowed, but not silently: they slow sync down and
/// bloat `.lus` exports, and the user should know that before committing.
///
/// Shared by the clip button and the content library, which both accept a
/// freshly picked file of any kind.
Future<bool> confirmIfLargeMedia(BuildContext context, String path) async {
  final size = await mediaFileSize(path);
  if (size == null || size <= largeMediaWarningBytes) return true;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final mb = (size / (1024 * 1024)).toStringAsFixed(1);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.attachmentsLargeFileTitle),
      content: Text(l10n.attachmentsLargeFileContent(p.basename(path), mb)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.attachmentsAttachAnyway),
        ),
      ],
    ),
  );
  return ok == true;
}



/// The clip button: one compact icon that opens a cascading menu for attaching
/// images, audio clips and video to a question.
///
/// Replaces the pair of full-width "New image" / "Existing image" buttons that
/// used to sit under every field, so the attachment affordance costs one icon
/// on the field's own row instead of a row of its own.
///
/// Built on [MenuAnchor] rather than [PopupMenuButton] because the design needs
/// real cascading submenus (kind then source, plus the manage list), which
/// PopupMenuButton has no support for.
///
/// On a narrow screen the cascade is dropped entirely: a submenu needs room
/// *beside* its parent, and with none to be had Flutter flips it back on top,
/// so the two levels sit stacked and unreadable. Below [_cascadeMinWidth] the
/// same tree is shown as a drill-down modal bottom sheet instead — one level
/// visible at a time, full-width rows, no overlay possible by construction.
///
/// Two shapes, chosen by [multi]:
///  * **multi** (the randomized attachments list) — "Add ..." entries append,
///    and a separate "Manage attachments (N)" submenu lists what is already
///    there so it can be viewed or removed. This is the add-vs-edit split.
///  * **single** (one flashcard side) — when empty it offers the same "Add ..."
///    entries; once filled they become "Replace with ...", joined by
///    View/Remove.
class MediaAttachmentButton extends StatelessWidget {
  /// Paths currently attached to this slot. Single mode holds 0 or 1.
  final List<String> attachments;

  /// Whether this slot holds a list (append + manage) or exactly one item.
  final bool multi;

  /// Which kinds this slot accepts. Kinds outside this set are not offered —
  /// imageClick, for instance, is image-only.
  final Set<MediaKind> allowedKinds;

  /// Invoked once the user has picked a file. The parent owns the list, so it
  /// decides whether to append or replace.
  final Future<void> Function(MediaKind kind, String path) onAttach;

  final void Function(String path) onRemove;

  const MediaAttachmentButton({
    super.key,
    required this.attachments,
    required this.onAttach,
    required this.onRemove,
    this.multi = true,
    this.allowedKinds = const {
      MediaKind.image,
      MediaKind.audio,
      MediaKind.video,
    },
  });

  // ── Picking ────────────────────────────────────────────────────────────────

  static const _pickerTypes = {
    MediaKind.image: FileType.image,
    MediaKind.audio: FileType.audio,
    MediaKind.video: FileType.video,
  };

  Future<void> _pick(
      BuildContext context, MediaKind kind, MediaSource source) async {
    String? path;

    if (source == MediaSource.existing) {
      path = await MediaBrowserDialog.show(context, kind);
      if (path == null) return;
    } else {
      final result =
          await FilePicker.platform.pickFiles(type: _pickerTypes[kind]!);
      path = result?.files.single.path;
      if (path == null) return;
      if (!context.mounted) return;
      if (!await confirmIfLargeMedia(context, path)) return;
    }

    // The bytes behind this path may have changed since it was last shown here.
    // The image cache keys on the path alone and would otherwise serve the stale
    // decode, in the preview and in the occlusion editor alike.
    await evictImageCache(path);
    await onAttach(kind, path);
  }

  // ── Labels ─────────────────────────────────────────────────────────────────

  String _kindLabel(AppLocalizations l10n, MediaKind kind) {
    // A single slot that already holds something replaces rather than adds.
    final replacing = !multi && attachments.isNotEmpty;
    return switch (kind) {
      MediaKind.image =>
        replacing ? l10n.attachmentsReplaceImage : l10n.attachmentsAddImage,
      MediaKind.audio =>
        replacing ? l10n.attachmentsReplaceAudio : l10n.attachmentsAddAudio,
      MediaKind.video =>
        replacing ? l10n.attachmentsReplaceVideo : l10n.attachmentsAddVideo,
    };
  }

  (String, String) _sourceLabels(AppLocalizations l10n, MediaKind kind) =>
      switch (kind) {
        MediaKind.image => (
            l10n.attachmentsNewImage,
            l10n.attachmentsExistingImage
          ),
        MediaKind.audio => (
            l10n.attachmentsNewAudio,
            l10n.attachmentsExistingAudio
          ),
        MediaKind.video => (
            l10n.attachmentsNewVideo,
            l10n.attachmentsExistingVideo
          ),
      };

  // ── Menu ───────────────────────────────────────────────────────────────────

  /// Narrowest window that still fits a menu and its submenu side by side.
  /// A root menu row runs to roughly 280dp and a source submenu to roughly
  /// 230dp; below their sum plus screen padding the submenu has nowhere to go
  /// but back over its parent.
  static const _cascadeMinWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (MediaQuery.sizeOf(context).width < _cascadeMinWidth) {
      return _withBadge(
        context,
        IconButton(
          tooltip: l10n.attachmentsTooltip,
          icon: const Icon(Icons.attach_file),
          isSelected: attachments.isNotEmpty,
          onPressed: () => _openSheet(context),
        ),
      );
    }

    return MenuAnchor(
      menuChildren: _menuChildren(context, l10n),
      builder: (context, controller, _) => _withBadge(
        context,
        IconButton(
          tooltip: l10n.attachmentsTooltip,
          icon: const Icon(Icons.attach_file),
          isSelected: attachments.isNotEmpty,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }

  /// Wraps the button in a small count badge, so an attached-but-collapsed slot
  /// still reads as occupied without opening anything.
  Widget _withBadge(BuildContext context, Widget button) {
    final count = attachments.length;
    if (count == 0) return button;
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 2,
          top: 2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow-screen sheet ────────────────────────────────────────────────────

  /// The sheet only *chooses*; it pops with an intent and this button carries it
  /// out. Running the file picker or a dialog from inside the sheet would leave
  /// them anchored to a route that is about to close, so the follow-up work is
  /// deliberately done back here, against the button's own live context.
  Future<void> _openSheet(BuildContext context) async {
    final intent = await showModalBottomSheet<_AttachmentIntent>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AttachmentSheet(button: this),
    );
    if (intent == null || !context.mounted) return;
    switch (intent) {
      case _PickIntent(:final kind, :final source):
        await _pick(context, kind, source);
      case _ViewIntent(:final path):
        await MediaPreviewDialog.show(context, path);
      case _RemoveIntent(:final path):
        onRemove(path);
    }
  }

  List<Widget> _menuChildren(BuildContext context, AppLocalizations l10n) {
    final children = <Widget>[];

    for (final kind in MediaKind.values) {
      if (!allowedKinds.contains(kind)) continue;
      final (newLabel, existingLabel) = _sourceLabels(l10n, kind);
      children.add(
        SubmenuButton(
          leadingIcon: Icon(iconForMediaKind(kind)),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.file_open_outlined),
              onPressed: () => _pick(context, kind, MediaSource.newFile),
              child: Text(newLabel),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.photo_library_outlined),
              onPressed: () => _pick(context, kind, MediaSource.existing),
              child: Text(existingLabel),
            ),
          ],
          child: Text(_kindLabel(l10n, kind)),
        ),
      );
    }

    if (attachments.isEmpty) return children;

    children.add(const Divider(height: 1));

    if (multi) {
      children.add(
        SubmenuButton(
          leadingIcon: const Icon(Icons.collections_outlined),
          menuChildren: [
            for (final path in attachments)
              _ManageRow(
                path: path,
                onView: () => MediaPreviewDialog.show(context, path),
                onRemove: () => onRemove(path),
              ),
          ],
          child: Text(l10n.attachmentsManage(attachments.length)),
        ),
      );
    } else {
      final path = attachments.first;
      children.addAll([
        MenuItemButton(
          leadingIcon: const Icon(Icons.visibility_outlined),
          onPressed: () => MediaPreviewDialog.show(context, path),
          child: Text(l10n.attachmentsView),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete_outline),
          onPressed: () => onRemove(path),
          child: Text(l10n.attachmentsRemove),
        ),
      ]);
    }

    return children;
  }
}

/// One row of the manage submenu: thumbnail, filename, and a remove button.
///
/// The row itself opens the preview; the trailing X removes. The X is its own
/// button so it takes the tap instead of the enclosing menu item.
class _ManageRow extends StatelessWidget {
  final String path;
  final VoidCallback onView;
  final VoidCallback onRemove;

  const _ManageRow({
    required this.path,
    required this.onView,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuItemButton(
      leadingIcon: MediaThumbnail(path: path, size: 32),
      trailingIcon: IconButton(
        tooltip: l10n.attachmentsRemoveTooltip,
        icon: const Icon(Icons.close, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          // Close first — the list this row is built from is about to change
          // under it, and a stale open submenu would rebuild mid-removal.
          MenuController.maybeOf(context)?.close();
          onRemove();
        },
      ),
      onPressed: onView,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(p.basename(path), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

// ── Narrow-screen sheet ──────────────────────────────────────────────────────

/// What the user chose in the sheet. The sheet pops one of these and
/// [MediaAttachmentButton] performs it; see `_openSheet`.
sealed class _AttachmentIntent {
  const _AttachmentIntent();
}

class _PickIntent extends _AttachmentIntent {
  final MediaKind kind;
  final MediaSource source;
  const _PickIntent(this.kind, this.source);
}

class _ViewIntent extends _AttachmentIntent {
  final String path;
  const _ViewIntent(this.path);
}

class _RemoveIntent extends _AttachmentIntent {
  final String path;
  const _RemoveIntent(this.path);
}

/// The narrow-screen stand-in for the cascading menu: the same three levels
/// (kinds → sources, and the manage list), but shown one at a time in place
/// with a back arrow, so nothing is ever drawn over anything else.
class _AttachmentSheet extends StatefulWidget {
  /// Borrowed purely for its labels and its attachment list — the sheet never
  /// calls the button's callbacks, it pops an intent instead.
  final MediaAttachmentButton button;

  const _AttachmentSheet({required this.button});

  @override
  State<_AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<_AttachmentSheet> {
  /// Which page is showing: null for the root list, a kind for its two sources.
  MediaKind? _kind;
  bool _manage = false;

  void _pop(_AttachmentIntent intent) => Navigator.pop(context, intent);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _kind != null
                ? _sourcePage(l10n, _kind!)
                : _manage
                    ? _managePage(l10n)
                    : _rootPage(l10n),
          ),
        ),
      ),
    );
  }

  /// Title row of a drilled-in page: back arrow plus where you are.
  Widget _header(String title) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => setState(() {
            _kind = null;
            _manage = false;
          }),
        ),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  List<Widget> _rootPage(AppLocalizations l10n) {
    final b = widget.button;
    return [
      for (final kind in MediaKind.values)
        if (b.allowedKinds.contains(kind))
          ListTile(
            leading: Icon(iconForMediaKind(kind)),
            title: Text(b._kindLabel(l10n, kind)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _kind = kind),
          ),
      if (b.attachments.isNotEmpty) ...[
        const Divider(height: 1),
        if (b.multi)
          ListTile(
            leading: const Icon(Icons.collections_outlined),
            title: Text(l10n.attachmentsManage(b.attachments.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _manage = true),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: Text(l10n.attachmentsView),
            onTap: () => _pop(_ViewIntent(b.attachments.first)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.attachmentsRemove),
            onTap: () => _pop(_RemoveIntent(b.attachments.first)),
          ),
        ],
      ],
    ];
  }

  List<Widget> _sourcePage(AppLocalizations l10n, MediaKind kind) {
    final b = widget.button;
    final (newLabel, existingLabel) = b._sourceLabels(l10n, kind);
    return [
      _header(b._kindLabel(l10n, kind)),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.file_open_outlined),
        title: Text(newLabel),
        onTap: () => _pop(_PickIntent(kind, MediaSource.newFile)),
      ),
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: Text(existingLabel),
        onTap: () => _pop(_PickIntent(kind, MediaSource.existing)),
      ),
    ];
  }

  List<Widget> _managePage(AppLocalizations l10n) {
    final b = widget.button;
    return [
      _header(l10n.attachmentsManage(b.attachments.length)),
      const Divider(height: 1),
      for (final path in b.attachments)
        ListTile(
          leading: MediaThumbnail(path: path, size: 40),
          title: Text(p.basename(path), overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: l10n.attachmentsRemoveTooltip,
            icon: const Icon(Icons.close),
            onPressed: () => _pop(_RemoveIntent(path)),
          ),
          onTap: () => _pop(_ViewIntent(path)),
        ),
    ];
  }
}
