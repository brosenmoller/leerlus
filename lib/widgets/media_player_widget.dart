import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/media_kind.dart';
import 'package:leerlus/utils/image_storage.dart';

/// How much of media_kit's control overlay a picture is big enough to carry.
/// See [_MediaPlayerWidgetState._controlsTierFor].
enum _ControlsTier { full, compact, none }

/// Plays an audio clip or a video attachment.
///
/// Audio renders as a compact transport bar (play/pause, scrubber, elapsed and
/// total time); video renders the picture with a tap-to-start poster overlay.
/// The player is owned by this widget's state and disposed with it, so leaving
/// a question always stops the sound.
class MediaPlayerWidget extends StatefulWidget {
  final String path;

  /// Starts playback as soon as the widget mounts. Audio questions use this so
  /// a listening drill plays without an extra tap; video never does, so it
  /// can't surprise the user with sound.
  final bool autoPlay;

  /// Cap for the video picture. Ignored for audio, which is a fixed-height bar.
  final double maxHeight;

  /// Cap for the width of either player. Left unbounded by default so the
  /// picture grows into whatever the caller gives it; the preview dialog passes
  /// its real width so a video fills the window instead of a hardcoded box.
  final double maxWidth;

  const MediaPlayerWidget({
    super.key,
    required this.path,
    this.autoPlay = false,
    this.maxHeight = 260,
    this.maxWidth = double.infinity,
  });

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  late final Player _player;
  VideoController? _videoController;

  bool _playing = false;
  bool _started = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// The clip's own pixel size, so the picture can be laid out at its real
  /// aspect ratio instead of inside a fixed box with black bars.
  int? _videoWidth;
  int? _videoHeight;

  /// Set while the user drags the audio scrubber. The position stream keeps
  /// ticking during a drag and would otherwise yank the thumb back out from
  /// under the finger, so the drag value wins until the finger lifts.
  double? _dragValue;

  bool get _isVideo => mediaKindOf(widget.path).isVideo;

  /// 16:9 until the real size arrives — a sane box for the first frame rather
  /// than a jump from square to widescreen.
  double get _aspectRatio {
    final w = _videoWidth ?? 0;
    final h = _videoHeight ?? 0;
    return (w > 0 && h > 0) ? w / h : 16 / 9;
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    if (_isVideo) _videoController = VideoController(_player);

    _player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    _player.stream.position.listen((v) {
      if (mounted) setState(() => _position = v);
    });
    _player.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    });
    _player.stream.width.listen((v) {
      if (mounted) setState(() => _videoWidth = v);
    });
    _player.stream.height.listen((v) {
      if (mounted) setState(() => _videoHeight = v);
    });
    // Leave the last frame/position visible instead of snapping back to zero.
    _player.stream.completed.listen((done) {
      if (done && mounted) setState(() => _playing = false);
    });

    _open();
  }

  Future<void> _open() async {
    // play: false always — autoplay is applied explicitly below so video can
    // open (and show its first frame) without ever starting on its own.
    await _player.open(Media(mediaFileFor(widget.path).path), play: false);
    if (!mounted) return;
    if (widget.autoPlay && !_isVideo) {
      _started = true;
      await _player.play();
    }
  }

  @override
  void didUpdateWidget(MediaPlayerWidget old) {
    super.didUpdateWidget(old);
    if (widget.path != old.path) {
      _started = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _videoWidth = null;
      _videoHeight = null;
      _dragValue = null;
      _open();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    _started = true;
    // Past the end, play() would no-op; rewind first so the button always plays.
    if (!_playing && _duration > Duration.zero && _position >= _duration) {
      await _player.seek(Duration.zero);
    }
    await _player.playOrPause();
  }

  Future<void> _restart() async {
    _started = true;
    await _player.seek(Duration.zero);
    await _player.play();
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return _isVideo ? _buildVideo(context) : _buildAudio(context);
  }

  Widget _buildVideo(BuildContext context) {
    final controller = _videoController;
    if (controller == null) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.maxHeight,
        maxWidth: widget.maxWidth,
      ),
      // The picture defines the box, not the other way round. media_kit's
      // Video is a Container with null width/height flooded with `fill`
      // (black), so inside a fixed-height box it letterboxes itself; sizing the
      // box to the clip's own ratio removes the bars entirely.
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          // Inside the AspectRatio the constraints are tight, so this reports
          // the picture's real size — which is what decides how much control
          // bar it can carry.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tier = _controlsTierFor(constraints.biggest);
              return _withControlsTheme(
                tier,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(
                      controller: controller,
                      // Always the real controls. media_kit's VideoState
                      // captures `controls` once into a `late final` and
                      // defines no didUpdateWidget, so a builder picked from
                      // state here freezes on whatever it was at first build —
                      // which is how the seek bar, volume and pause button went
                      // missing entirely. What the bar *contains* is tuned
                      // through the themes below, which are read live.
                      controls: AdaptiveVideoControls,
                    ),
                    // Poster overlay: the first frame is already showing
                    // underneath, so this is just the affordance that playback
                    // needs a tap. It covers the controls, but only until that
                    // first tap — except at [_ControlsTier.none], where there
                    // are no controls to cover and it stays as the only one.
                    if (!_started || tier == _ControlsTier.none)
                      Positioned.fill(
                        child: Material(
                          color: _playing ? Colors.transparent : Colors.black26,
                          child: InkWell(
                            onTap: _toggle,
                            // While it plays the overlay is nothing but a tap
                            // target: a badge parked over a picture this small
                            // would hide more than it offers.
                            child: _playing
                                ? const SizedBox.expand()
                                : Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: tier == _ControlsTier.none ? 36 : 56,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// media_kit's control overlays are laid out at fixed sizes and will happily
  /// overflow a picture that is smaller than they are: the desktop bar stacks a
  /// 56dp top row, a 36dp seek bar and a 56dp button row, and its volume button
  /// widens by ~70dp the moment the pointer touches it. A question thumbnail or
  /// a flashcard face on a phone is nowhere near that big, so the overlay is
  /// scaled back to what the picture can actually hold.
  _ControlsTier _controlsTierFor(Size size) {
    if (size.width >= 360 && size.height >= 200) return _ControlsTier.full;
    if (size.width >= 180 && size.height >= 110) return _ControlsTier.compact;
    return _ControlsTier.none;
  }

  /// Both control themes are declared, not just the one for this platform:
  /// they are plain [InheritedWidget]s, cost nothing when unused, and this way
  /// the widget doesn't have to duplicate `AdaptiveVideoControls`' own
  /// platform switch. Fullscreen always gets the package defaults — there is
  /// room for everything on a whole screen.
  Widget _withControlsTheme(_ControlsTier tier, Widget child) {
    final (desktop, mobile) = switch (tier) {
      _ControlsTier.full => (
          const MaterialDesktopVideoControlsThemeData(),
          const MaterialVideoControlsThemeData(),
        ),
      _ControlsTier.compact => (
          const MaterialDesktopVideoControlsThemeData(
            buttonBarHeight: 36,
            buttonBarButtonSize: 20,
            seekBarContainerHeight: 20,
            seekBarMargin: EdgeInsets.symmetric(horizontal: 6),
            bottomButtonBarMargin: EdgeInsets.symmetric(horizontal: 4),
            primaryButtonBar: [],
            // No volume button: its hover expansion is exactly what was
            // painting overflow stripes across the picture.
            bottomButtonBar: [
              MaterialDesktopPlayOrPauseButton(),
              Spacer(),
              MaterialDesktopPositionIndicator(),
              SizedBox(width: 4),
              MaterialDesktopFullscreenButton(),
            ],
          ),
          const MaterialVideoControlsThemeData(
            buttonBarHeight: 36,
            buttonBarButtonSize: 20,
            seekBarContainerHeight: 20,
            bottomButtonBarMargin: EdgeInsets.symmetric(horizontal: 8),
            primaryButtonBar: [MaterialPlayOrPauseButton(iconSize: 32)],
            bottomButtonBar: [
              MaterialPositionIndicator(),
              Spacer(),
              MaterialFullscreenButton(),
            ],
          ),
        ),
      // Every bar emptied and the seek bar dropped, so the overlay cannot be
      // taller or wider than the picture whatever its size. The poster overlay
      // above stays put and carries play/pause on its own.
      _ControlsTier.none => (
          const MaterialDesktopVideoControlsThemeData(
            buttonBarHeight: 0,
            displaySeekBar: false,
            primaryButtonBar: [],
            bottomButtonBar: [],
          ),
          const MaterialVideoControlsThemeData(
            buttonBarHeight: 0,
            displaySeekBar: false,
            primaryButtonBar: [],
            bottomButtonBar: [],
          ),
        ),
    };

    return MaterialDesktopVideoControlsTheme(
      normal: desktop,
      fullscreen: const MaterialDesktopVideoControlsThemeData(),
      child: MaterialVideoControlsTheme(
        normal: mobile,
        fullscreen: const MaterialVideoControlsThemeData(),
        child: child,
      ),
    );
  }

  /// Below this the transport buttons and the scrubber can't share a line
  /// without squeezing the scrubber down to a few dozen pixels, so it gets a
  /// full-width row of its own underneath.
  static const _stackedMaxWidth = 380.0;

  Widget _buildAudio(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final total = _duration.inMilliseconds;
    final pos =
        _position.inMilliseconds.clamp(0, total == 0 ? 1 : total).toDouble();

    final seekBar = SliderTheme(
      // The card sits on surfaceContainerHighest, which is exactly the M3
      // default inactive track colour — the bar was invisible against its own
      // background. Spell both track colours out, and fatten the track so it
      // reads as something draggable.
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: theme.colorScheme.primary,
        inactiveTrackColor:
            theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        thumbColor: theme.colorScheme.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: total == 0 ? 0 : (_dragValue ?? pos),
        max: total == 0 ? 1 : total.toDouble(),
        onChanged: total == 0 ? null : (v) => setState(() => _dragValue = v),
        onChangeEnd: total == 0
            ? null
            : (v) {
                setState(() => _dragValue = null);
                _player.seek(Duration(milliseconds: v.round()));
              },
      ),
    );

    final timeLabel = Text(
      '${_fmt(_position)} / ${_fmt(_duration)}',
      style: theme.textTheme.bodySmall,
    );

    final playButton = IconButton(
      onPressed: _toggle,
      tooltip: _playing ? l10n.mediaPause : l10n.mediaPlay,
      icon:
          Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
      iconSize: 36,
    );

    final replayButton = IconButton(
      onPressed: _restart,
      tooltip: l10n.mediaReplay,
      icon: const Icon(Icons.replay),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.min(520.0, widget.maxWidth)),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _stackedMaxWidth) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // Column here for its height only. A Slider fills whatever
                // bounded height it is handed, and a Row passes its own down
                // as the cross-axis max — so on a tall desktop face the
                // scrubber grew to the full height and stretched the card's
                // background with it. A min-height Column hands the row
                // unbounded height, which is what makes the Slider fall back
                // to its natural size — the same path the stacked layout
                // below already takes, hence the identical bar there.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        playButton,
                        replayButton,
                        Expanded(child: seekBar),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: timeLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      playButton,
                      replayButton,
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: timeLabel,
                      ),
                    ],
                  ),
                  seekBar,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
