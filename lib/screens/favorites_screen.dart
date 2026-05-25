import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/services/favorites_service.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/widgets/collapsible_app_bar_title.dart';
import 'package:leerlus/widgets/quiz_tile.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService favoritesService = FavoritesService();
  final QuestionService questionService = QuestionService();
  bool _initialized = false;

  List<QuizData> _favoriteQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      await favoritesService.init();

      final favoriteIds = favoritesService.allFavorites;

      _favoriteQuizzes = favoriteIds
          .map((id) => questionService.getQuiz(id))
          .whereType<QuizData>()
          .toList();
    } catch (_) {
      _favoriteQuizzes = [];
    }

    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double hPad = constraints.maxWidth > 900
              ? (constraints.maxWidth - 900) / 2 + 16
              : 16;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: colorScheme.secondary,
                iconTheme: IconThemeData(color: colorScheme.onSecondary),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(0, 0, 20, 16),
                  title: CollapsibleAppBarTitle(
                    child: Text(
                      l10n.favoritesTitle,
                      style: TextStyle(
                        color: colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.secondary,
                          colorScheme.primary,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24, bottom: 24),
                        child: Icon(
                          Icons.star_rounded,
                          size: 80,
                          color: colorScheme.onSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (!_initialized)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_favoriteQuizzes.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Text(l10n.favoritesEmpty)),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final quiz = _favoriteQuizzes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: QuizTile(
                            horizontal: true,
                            quiz: quiz,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuizSessionScreen(quizData: quiz),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _favoriteQuizzes.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
