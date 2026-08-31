import 'package:path/path.dart' as p;

/// What sort of media a stored path points at.
///
/// Deliberately derived from the file extension rather than stored alongside
/// the path. Every place that already carries media — the `imagePathVariants`
/// JSON array, `FlashcardConfig.front/backImagePath`, sync manifests, `.lus`
/// archives, orphan detection — carries a bare path or basename and never
/// inspects the content. Extension-derived kinds therefore let audio and video
/// ride through all of them with no schema change and no new sync fields. The
/// columns keep their historical `image*` names; they hold attachments now.
enum MediaKind {
  image,
  audio,
  video;

  bool get isImage => this == MediaKind.image;
  bool get isAudio => this == MediaKind.audio;
  bool get isVideo => this == MediaKind.video;

  /// Audio and video go through a player; images do not.
  bool get isPlayable => this != MediaKind.image;
}

const imageExtensions = <String>{
  '.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp',
};

const audioExtensions = <String>{
  '.mp3', '.m4a', '.aac', '.wav', '.ogg', '.oga', '.opus', '.flac', '.wma',
};

const videoExtensions = <String>{
  '.mp4', '.mov', '.webm', '.mkv', '.avi', '.m4v', '.wmv', '.mpeg', '.mpg',
};

/// The kind of media [path] points at, by extension.
///
/// Unknown extensions fall back to [MediaKind.image]: every path written before
/// audio and video existed is an image, so this keeps old data meaning exactly
/// what it always meant. A genuinely unrenderable file then shows the broken
/// image icon rather than spinning up a player on something that isn't media.
MediaKind mediaKindOf(String path) {
  final ext = p.extension(path).toLowerCase();
  if (audioExtensions.contains(ext)) return MediaKind.audio;
  if (videoExtensions.contains(ext)) return MediaKind.video;
  return MediaKind.image;
}

/// Extensions accepted for [kind] — used by the file picker and media browser.
Set<String> extensionsFor(MediaKind kind) => switch (kind) {
      MediaKind.image => imageExtensions,
      MediaKind.audio => audioExtensions,
      MediaKind.video => videoExtensions,
    };

/// Every extension this app treats as attachable media.
Set<String> get allMediaExtensions =>
    {...imageExtensions, ...audioExtensions, ...videoExtensions};

/// Whether [path] carries an extension this app can attach at all. Used by the
/// media library, which lists a directory and must not offer stray files.
bool isMediaPath(String path) =>
    allMediaExtensions.contains(p.extension(path).toLowerCase());
