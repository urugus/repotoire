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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                SearchBar(
                  hintText: '楽譜名で検索',
                  leading: const Icon(Icons.search),
                  onChanged: (value) =>
                      ref.read(libraryQueryProvider.notifier).state = value,
                ),
                const SizedBox(height: 8),
                const _FilterFields(),
              ],
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
      text: result.files.single.name
          .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );
    final keyController = TextEditingController();
    final tagsController = TextEditingController();
    late final String title;
    String? key;
    late final List<String> tags;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('PDFを取り込む'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '楽譜名'),
                    autofocus: true,
                  ),
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(labelText: 'キー'),
                  ),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'タグ',
                      hintText: 'カンマ区切り',
                    ),
                  ),
                ],
              ),
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

      final titleText = titleController.text.trim();
      final keyText = keyController.text.trim();
      title = titleText.isEmpty ? result.files.single.name : titleText;
      key = keyText.isEmpty ? null : keyText;
      tags = _parseTags(tagsController.text);
    } finally {
      titleController.dispose();
      keyController.dispose();
      tagsController.dispose();
    }

    if (!context.mounted) {
      return;
    }

    final repository = ref.read(libraryRepositoryProvider);
    try {
      final importResult = await repository.importScore(
        ImportScoreRequest(
          pdfFile: File(result.files.single.path!),
          title: title,
          key: key,
          tags: tags,
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

class _FilterFields extends ConsumerStatefulWidget {
  const _FilterFields();

  @override
  ConsumerState<_FilterFields> createState() => _FilterFieldsState();
}

class _FilterFieldsState extends ConsumerState<_FilterFields> {
  final _keyController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = ref.watch(libraryKeyFilterProvider);
    final tag = ref.watch(libraryTagFilterProvider);
    final hasFilters = key.trim().isNotEmpty || tag.trim().isNotEmpty;
    if (_keyController.text != key) {
      _keyController.text = key;
    }
    if (_tagController.text != tag) {
      _tagController.text = tag;
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.music_note),
              labelText: 'キー',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(libraryKeyFilterProvider.notifier).state = value,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _tagController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.sell),
              labelText: 'タグ',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                ref.read(libraryTagFilterProvider.notifier).state = value,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '絞り込みをクリア',
          onPressed: hasFilters
              ? () {
                  ref.read(libraryKeyFilterProvider.notifier).state = '';
                  ref.read(libraryTagFilterProvider.notifier).state = '';
                }
              : null,
          icon: const Icon(Icons.filter_alt_off),
        ),
      ],
    );
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
          subtitle: Text(_subtitleFor(item)),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                await _editScore(context, ref, item);
              } else if (value == 'delete') {
                await _deleteScore(context, ref, item);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('編集')),
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    PdfViewerScreen(scoreId: item.id, title: item.title),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editScore(
    BuildContext context,
    WidgetRef ref,
    ScoreListItem item,
  ) async {
    final titleController = TextEditingController(text: item.title);
    final keyController = TextEditingController(text: item.key ?? '');
    final tagsController = TextEditingController(text: item.tags.join(', '));

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('楽譜情報を編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '楽譜名'),
                    autofocus: true,
                  ),
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(labelText: 'キー'),
                  ),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'タグ',
                      hintText: 'カンマ区切り',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !context.mounted) {
        return;
      }

      final title = titleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('楽譜名を入力してください')),
        );
        return;
      }

      final key = keyController.text.trim();
      await ref.read(libraryRepositoryProvider).updateMetadata(
            UpdateScoreMetadataRequest(
              scoreId: item.id,
              title: title,
              key: key.isEmpty ? null : key,
              tags: _parseTags(tagsController.text),
            ),
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('楽譜情報を保存しました')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      titleController.dispose();
      keyController.dispose();
      tagsController.dispose();
    }
  }

  Future<void> _deleteScore(
    BuildContext context,
    WidgetRef ref,
    ScoreListItem item,
  ) async {
    try {
      await ref.read(libraryRepositoryProvider).logicalDelete(item.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title}を削除しました')),
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

  String _subtitleFor(ScoreListItem item) {
    if (item.invalidReason != null) {
      return item.invalidReason!;
    }
    final parts = [
      if (item.key != null && item.key!.isNotEmpty) item.key!,
      if (item.tags.isNotEmpty) item.tags.join(', '),
    ];
    return parts.isEmpty ? 'PDF' : parts.join(' / ');
  }
}

List<String> _parseTags(String input) {
  return input
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
