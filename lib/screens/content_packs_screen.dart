import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/services/question_service.dart';

class ContentPacksScreen extends StatefulWidget {
  final AppDatabase db;

  const ContentPacksScreen({super.key, required this.db});

  @override
  State<ContentPacksScreen> createState() => _ContentPacksScreenState();
}

class _ContentPacksScreenState extends State<ContentPacksScreen> {
  List<_PackMeta>? _packs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      final raw = await rootBundle.loadString('assets/content_packs/index.json');
      final list = jsonDecode(raw) as List;
      setState(() {
        _packs = list.map((e) => _PackMeta.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _importPack(_PackMeta pack) async {
    try {
      final raw = await rootBundle.loadString('assets/content_packs/${pack.file}');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final count = await widget.db.importFromJson(data);
      await QuestionService().refresh();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0 ? l10n.contentPacksAlreadyUpToDate : l10n.contentPacksImportedCount(count),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contentPacksTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_packs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_packs!.isEmpty) {
      return const Center(child: Text('No content packs available.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _packs!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final pack = _packs![i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: const CircleAvatar(child: Icon(Icons.library_books_outlined)),
          title: Text(pack.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: pack.description != null ? Text(pack.description!) : null,
          trailing: FilledButton.tonal(
            onPressed: () => _importPack(pack),
            child: Text(l10n.contentPacksImport),
          ),
        );
      },
    );
  }
}

class _PackMeta {
  final String file;
  final String title;
  final String? description;

  const _PackMeta({required this.file, required this.title, this.description});

  factory _PackMeta.fromJson(Map<String, dynamic> json) => _PackMeta(
        file: json['file'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
      );
}
