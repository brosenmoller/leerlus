import 'package:flutter/material.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/folder_data.dart';
import 'package:leerlus/models/quiz_data.dart';
import 'package:leerlus/screens/folder_browser_screen.dart';
import 'package:leerlus/screens/quiz_session_screen.dart';
import 'package:leerlus/services/question_service.dart';

class GlobalSearchDelegate extends SearchDelegate<void> {
  GlobalSearchDelegate({required String hint}) : super(searchFieldLabel: hint);

  final QuestionService _service = QuestionService();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = query.toLowerCase().trim();

    if (q.isEmpty) {
      return Center(child: Text(l10n.searchHint));
    }

    final folders = _service
        .getAllFolders()
        .where((f) => f.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final quizzes = _service
        .getAllQuizzes()
        .where((quiz) => quiz.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    if (folders.isEmpty && quizzes.isEmpty) {
      return Center(child: Text(l10n.searchNoResults));
    }

    return ListView(
      children: [
        if (folders.isNotEmpty) ...[
          _SectionHeader(title: l10n.foldersSection),
          ...folders.map((f) => _FolderResult(
                folder: f,
                parentTitle: f.parentFolderId != null
                    ? _service.getFolder(f.parentFolderId!)?.title
                    : null,
                onTap: () {
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderBrowserScreen(folder: f),
                    ),
                  );
                },
              )),
        ],
        if (quizzes.isNotEmpty) ...[
          _SectionHeader(title: l10n.quizzesSection),
          ...quizzes.map((quiz) => _QuizResult(
                quiz: quiz,
                parentTitle: quiz.parentFolderId != null
                    ? _service.getFolder(quiz.parentFolderId!)?.title
                    : null,
                onTap: () {
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizSessionScreen(quizData: quiz),
                    ),
                  );
                },
              )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _FolderResult extends StatelessWidget {
  final FolderData folder;
  final String? parentTitle;
  final VoidCallback onTap;

  const _FolderResult({
    required this.folder,
    required this.parentTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.title),
      subtitle: parentTitle != null ? Text(parentTitle!) : null,
      onTap: onTap,
    );
  }
}

class _QuizResult extends StatelessWidget {
  final QuizData quiz;
  final String? parentTitle;
  final VoidCallback onTap;

  const _QuizResult({
    required this.quiz,
    required this.parentTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.quiz_outlined),
      title: Text(quiz.title),
      subtitle: parentTitle != null ? Text(parentTitle!) : null,
      onTap: onTap,
    );
  }
}
