import 'package:flutter/material.dart';

import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/widgets/media_browser_dialog.dart';

/// Image-only entry point to the media library.
///
/// Kept as a thin wrapper over [MediaBrowserDialog] so the slots that are
/// deliberately image-only — folder and quiz cover art, and the imageClick
/// question image — keep calling exactly what they always did.
class ImageBrowserDialog {
  const ImageBrowserDialog._();

  static Future<String?> show(BuildContext context) =>
      MediaBrowserDialog.show(context, MediaKind.image);
}
