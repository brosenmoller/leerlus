import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/media_player_widget.dart';

IconData iconForMediaKind(MediaKind kind) => switch (kind) {
      MediaKind.image => Icons.image_outlined,
      MediaKind.audio => Icons.music_note_outlined,
      MediaKind.video => Icons.movie_outlined,
    };

/// A square tile standing in for one attachment.
///
/// Images show themselves; audio and video have no still to show, so they get a
/// tinted icon tile carrying the filename — enough to tell two clips apart in
/// the manage list.
class MediaThumbnail extends StatelessWidget {
  final String path;
  final double size;

  /// Smallest tile that still fits the icon plus two lines of filename. Below
  /// this the label is dropped and the icon takes the whole tile: two lines of
  /// `labelSmall` alone run to roughly 30dp, so squeezing them into a 32dp
  /// row-leading tile overflows it — and at that scale the text is unreadable
  /// anyway, with the basename already spelled out beside the tile.
  static const _minSizeForLabel = 72.0;

  const MediaThumbnail({super.key, required this.path, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final kind = mediaKindOf(path);
    final theme = Theme.of(context);

    if (kind.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: AppImage(path: path, fit: BoxFit.cover, width: size),
        ),
      );
    }

    final showLabel = size >= _minSizeForLabel;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(showLabel ? 6 : 4),
      child: showLabel
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconForMediaKind(kind),
                    size: size * 0.34,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    p.basename(path),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            )
          : Icon(iconForMediaKind(kind),
              size: size * 0.6, color: theme.colorScheme.onSecondaryContainer),
    );
  }
}

/// Full view of a single attachment: the picture, or a player for a clip.
///
/// Deliberately a bare [Dialog] rather than an [AlertDialog]: AlertDialog wraps
/// its column in an `IntrinsicWidth`, so the box sizes to what the content
/// *would like* to be instead of to the window. That left the audio scrubber
/// sharing a near-minimum-width dialog with two buttons and a timestamp, and
/// boxed the video into a fraction of the screen. Here the size is stated
/// outright and the padding kept thin, because the whole point of opening a
/// preview is to see the attachment.
class MediaPreviewDialog extends StatelessWidget {
  final String path;

  const MediaPreviewDialog({super.key, required this.path});

  static Future<void> show(BuildContext context, String path) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => MediaPreviewDialog(path: path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = mediaKindOf(path);

    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 24, 1000.0);
    // Header row plus the body padding, held back so the media can never push
    // the dialog past the window.
    final mediaMaxHeight = math.max(screen.height * 0.85 - 72, 120.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    p.basename(path),
                    style: theme.textTheme.titleSmall,
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
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: kind.isImage
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: mediaMaxHeight),
                      child: AppImage(path: path, fit: BoxFit.contain),
                    )
                  : MediaPlayerWidget(
                      path: path,
                      maxHeight: mediaMaxHeight,
                      maxWidth: width - 16,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
