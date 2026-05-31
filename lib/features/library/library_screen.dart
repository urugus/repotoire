import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/library_repository.dart';
import '../viewer/pdf_viewer_screen.dart';
import 'library_providers.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(libraryScoresProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repotoire'),
        actions: [
          IconButton(
            tooltip: 'PDFを取り込む',
            icon: const Icon(Icons.upload_file),
            onPressed: () => _pickAndImport(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchBar(
              hintText: '楽譜名で検索',
              leading: const Icon(Icons.search),
              onChanged: (value) =>
                  ref.read(libraryQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: scores.when(
              data: (items) => _ScoreList(items: items),
              error: (error, _) => _ErrorState(message: error.toString()),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final titleController = TextEditingController(
      text: result.files.single.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('PDFを取り込む'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: '楽譜名'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('取り込む'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final repository = ref.read(libraryRepositoryProvider);
    try {
      final importResult = await repository.importScore(
        ImportScoreRequest(
          pdfFile: File(result.files.single.path!),
          title: titleController.text.trim().isEmpty
              ? result.files.single.name
              : titleController.text.trim(),
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(importResult.policyResult.message)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _ScoreList extends ConsumerWidget {
  const _ScoreList({required this.items});

  final List<ScoreListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(child: Text('楽譜がありません'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(
            item.validity.name == 'invalid'
                ? Icons.warning_amber
                : Icons.picture_as_pdf,
          ),
          title: Text(item.title),
          subtitle: Text(item.invalidReason ?? item.key ?? 'PDF'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                ref.read(libraryRepositoryProvider).logicalDelete(item.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PdfViewerScreen(scoreId: item.id, title: item.title),
              ),
            );
          },
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
