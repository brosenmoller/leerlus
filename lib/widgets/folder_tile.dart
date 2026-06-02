import 'package:flutter/material.dart';
import 'package:leerlus/models/folder_data.dart';
import 'package:leerlus/widgets/app_image.dart';

// A small palette of saturated colors for folders without a cover image.
const _kTileColors = [
  Color(0xFF5C6BC0), // indigo
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFFAB47BC), // purple
  Color(0xFF42A5F5), // blue
  Color(0xFF66BB6A), // green
  Color(0xFFFF7043), // deep orange
  Color(0xFF26C6DA), // cyan
];

Color _colorForTitle(String title) {
  final hash = title.codeUnits.fold(0, (a, b) => a + b);
  return _kTileColors[hash % _kTileColors.length];
}

class FolderTile extends StatefulWidget {
  final FolderData folder;
  final VoidCallback onTap;
  final VoidCallback? onPlayAll;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onPlayAll,
  });

  @override
  State<FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<FolderTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.folder.imagePath != null;
    final baseColor = _colorForTitle(widget.folder.title);

    final subCount = widget.folder.subfolderIds.length;
    final quizCount = widget.folder.quizIds.length;
    final countLabel = [
      if (subCount > 0) '$subCount ${subCount == 1 ? 'folder' : 'folders'}',
      if (quizCount > 0) '$quizCount ${quizCount == 1 ? 'quiz' : 'quizzes'}',
    ].join(' · ');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: _hovering ? 0.45 : 0.3),
                  blurRadius: _hovering ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base color
                  ColoredBox(color: baseColor),

                  // Cover image
                  if (hasImage)
                    AppImage(
                      path: widget.folder.imagePath,
                      fit: BoxFit.cover,
                    ),

                  // Gradient overlay — transparent top, dark bottom
                  AnimatedOpacity(
                    opacity: _hovering ? 0.85 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: hasImage ? 0.72 : 0.45),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Play-all button
                  if (widget.onPlayAll != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: widget.onPlayAll,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.folder.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                blurRadius: 6,
                                color: Colors.black54,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _Badge(
                          icon: Icons.folder_outlined,
                          label: countLabel.isNotEmpty ? countLabel : 'Empty',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
