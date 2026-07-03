import 'package:flutter/material.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/services/favorites_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/widgets/app_image.dart';

// Same palette as FolderTile for visual consistency.
const _kTileColors = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
  Color(0xFF26C6DA),
];

Color _colorForTitle(String title) {
  final hash = title.codeUnits.fold(0, (a, b) => a + b);
  // Offset by 3 so quizzes and folders in the same folder land on different hues.
  return _kTileColors[(hash + 3) % _kTileColors.length];
}

class QuizTile extends StatefulWidget {
  final QuizData quiz;
  final VoidCallback onTap;
  final bool horizontal;

  const QuizTile({
    super.key,
    required this.quiz,
    required this.onTap,
    this.horizontal = false,
  });

  @override
  State<QuizTile> createState() => _QuizTileState();
}

class _QuizTileState extends State<QuizTile> {
  final FavoritesService _favoritesService = FavoritesService();
  final SrsService _srsService = SrsService();

  bool _hovering = false;
  bool _isFavorite = false;
  bool _isSrsEnabled = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    try {
      await _favoritesService.init();
      await _srsService.init();

      _isFavorite = _favoritesService.isFavorite(widget.quiz.id);

      final questions = _srsService.getQuestionsForQuiz(quiz: widget.quiz);
      _isSrsEnabled = questions.isNotEmpty
          ? _srsService.getUserData(questions.first).spacedRepetitionEnabled
          : false;
    } catch (_) {
      // Leave defaults (false) on failure
    }

    if (mounted) setState(() => _initialized = true);
  }

  void _toggleFavorite() async {
    if (!_initialized) return;
    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) {
      await _favoritesService.addFavorite(widget.quiz.id);
    } else {
      await _favoritesService.removeFavorite(widget.quiz.id);
    }
  }

  void _toggleSrs() async {
    if (!_initialized) return;
    setState(() => _isSrsEnabled = !_isSrsEnabled);
    final questions = _srsService.getQuestionsForQuiz(quiz: widget.quiz);
    for (final question in questions) {
      await _srsService.setQuestionSrs(question, _isSrsEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.horizontal ? _buildHorizontal() : _buildGrid();
  }

  Widget _buildGrid() {
    final hasImage = widget.quiz.imagePath != null;
    final baseColor = _colorForTitle(widget.quiz.title);
    final questionCount = widget.quiz.questionIds.length;
    final lang = widget.quiz.languageCode;

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
                  ColoredBox(color: baseColor),
                  if (hasImage)
                    AppImage(
                      path: widget.quiz.imagePath,
                      fit: BoxFit.cover,
                    ),
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
                          stops: const [0.25, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (lang != null)
                              _Badge(label: lang.toUpperCase()),
                            const Spacer(),
                            _IconToggle(
                              icon: Icons.repeat_rounded,
                              active: _isSrsEnabled,
                              activeColor: Colors.lightBlueAccent,
                              onPressed: _toggleSrs,
                            ),
                            _IconToggle(
                              icon: _isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              active: _isFavorite,
                              activeColor: Colors.amberAccent,
                              onPressed: _toggleFavorite,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.quiz.title,
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
                        Center(
                          child: _Badge(
                            icon: Icons.quiz_outlined,
                            label: '$questionCount ${questionCount == 1 ? 'question' : 'questions'}',
                          ),
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

  Widget _buildHorizontal() {
    final hasImage = widget.quiz.imagePath != null;
    final baseColor = _colorForTitle(widget.quiz.title);
    final questionCount = widget.quiz.questionIds.length;
    final lang = widget.quiz.languageCode;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: _hovering ? 0.45 : 0.28),
                  blurRadius: _hovering ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 80,
                child: Row(
                  children: [
                    // Left image strip — only shown when there is a cover image
                    if (hasImage)
                      SizedBox(
                        width: 76,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppImage(path: widget.quiz.imagePath, fit: BoxFit.cover),
                            // Right-edge fade into the content area
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                  stops: const [0.4, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Content area
                    Expanded(
                      child: ColoredBox(
                        color: baseColor.withValues(alpha: 0.82),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.quiz.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black38),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _Badge(
                                    icon: Icons.quiz_outlined,
                                    label: '$questionCount ${questionCount == 1 ? 'question' : 'questions'}',
                                  ),
                                  if (lang != null) ...[
                                    const SizedBox(width: 6),
                                    _Badge(label: lang.toUpperCase()),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Icon toggles
                    ColoredBox(
                      color: baseColor.withValues(alpha: 0.82),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IconToggle(
                              icon: Icons.repeat_rounded,
                              active: _isSrsEnabled,
                              activeColor: Colors.lightBlueAccent,
                              onPressed: _toggleSrs,
                            ),
                            _IconToggle(
                              icon: _isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              active: _isFavorite,
                              activeColor: Colors.amberAccent,
                              onPressed: _toggleFavorite,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  const _IconToggle({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: active ? activeColor : Colors.white60,
        size: 20,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
      ),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(32, 32),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Badge({this.icon, required this.label});

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
          if (icon != null) ...[
            Icon(icon, color: Colors.white70, size: 11),
            const SizedBox(width: 4),
          ],
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
