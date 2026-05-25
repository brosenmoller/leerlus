import 'dart:io';
import 'package:flutter/material.dart';
import 'package:leerlus/models/occlusion_data.dart';
import 'package:leerlus/widgets/app_image.dart';
import 'package:leerlus/widgets/occluded_image.dart';

/// Displays a question image, optionally with an occlusion overlay.
///
/// When [occlusionData] is supplied, the widget loads the image's aspect ratio
/// asynchronously so the occlusion overlay can be painted in exactly the right
/// position (using [AspectRatio] to guarantee the image fills the paint area
/// without letterboxing).
class QuestionImage extends StatefulWidget {
  final String path;
  final double maxHeight;

  /// When non-null, draws an occlusion overlay on the image.
  final OcclusionData? occlusionData;

  /// Whether hidden areas should be revealed (faded out).
  final bool occlusionRevealed;

  const QuestionImage({
    super.key,
    required this.path,
    this.maxHeight = 260,
    this.occlusionData,
    this.occlusionRevealed = false,
  });

  @override
  State<QuestionImage> createState() => _QuestionImageState();
}

class _QuestionImageState extends State<QuestionImage> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    if (widget.occlusionData != null) {
      resolveImageAspectRatio(widget.path).then((r) {
        if (mounted) setState(() => _aspectRatio = r);
      });
    }
  }

  @override
  void didUpdateWidget(QuestionImage old) {
    super.didUpdateWidget(old);
    if (widget.occlusionData != null && widget.path != old.path) {
      setState(() => _aspectRatio = null);
      resolveImageAspectRatio(widget.path).then((r) {
        if (mounted) setState(() => _aspectRatio = r);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (widget.occlusionData != null && _aspectRatio != null) {
      // Use AspectRatio so the OccludedImage stack fills the image exactly.
      child = AspectRatio(
        aspectRatio: _aspectRatio!,
        child: OccludedImage(
          imagePath: widget.path,
          occlusionData: widget.occlusionData!,
          revealed: widget.occlusionRevealed,
        ),
      );
    } else {
      // Default: plain image (or image while aspect ratio is loading)
      child = widget.path.startsWith('assets/')
          ? Image.asset(widget.path, fit: BoxFit.contain)
          : Image.file(File(widget.path), fit: BoxFit.contain);
    }

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: widget.maxHeight, maxWidth: 700),
      child: Center(child: child),
    );
  }
}
