import 'package:flutter/material.dart';

import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/widgets/media_player_widget.dart';
import 'package:leerlus/widgets/question_image.dart';

/// Renders whatever attachment a question resolved to.
///
/// Images go straight through to [QuestionImage], occlusion overlay and all, so
/// that path is entirely unchanged. Audio and video get a player instead: audio
/// starts on its own (a listening drill shouldn't need a tap), video waits for
/// one so it never surprises the user with sound.
class QuestionMedia extends StatelessWidget {
  final String path;
  final double maxHeight;

  /// Only ever set for images — occlusion is an image-only feature.
  final OcclusionData? occlusionData;
  final bool occlusionRevealed;

  const QuestionMedia({
    super.key,
    required this.path,
    this.maxHeight = 260,
    this.occlusionData,
    this.occlusionRevealed = false,
  });

  @override
  Widget build(BuildContext context) {
    final kind = mediaKindOf(path);
    if (kind.isImage) {
      return QuestionImage(
        path: path,
        maxHeight: maxHeight,
        occlusionData: occlusionData,
        occlusionRevealed: occlusionRevealed,
      );
    }
    return Center(
      child: MediaPlayerWidget(
        // Keyed on the path so switching questions builds a fresh player
        // instead of reusing one that is still holding the previous clip.
        key: ValueKey(path),
        path: path,
        autoPlay: kind.isAudio,
        maxHeight: maxHeight,
      ),
    );
  }
}
