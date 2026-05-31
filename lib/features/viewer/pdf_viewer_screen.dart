import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../library/library_providers.dart';

class PdfViewerScreen extends ConsumerWidget {
  const PdfViewerScreen({
    required this.scoreId,
    required this.title,
    super.key,
  });

  final String scoreId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<File?>(
        future: ref.read(libraryRepositoryProvider).currentPdfFile(scoreId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final file = snapshot.data;
          if (file == null) {
            return const Center(child: Text('PDFが見つかりません'));
          }
          return PdfViewer.file(
            file.path,
            params: const PdfViewerParams(
              minScale: 0.5,
              maxScale: 6,
              margin: 8,
            ),
          );
        },
      ),
    );
  }
}
