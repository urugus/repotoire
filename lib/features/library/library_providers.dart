import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/local/library_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository(database: ref.watch(appDatabaseProvider));
});

final libraryQueryProvider = StateProvider<String>((ref) => '');

final libraryKeyFilterProvider = StateProvider<String>((ref) => '');

final libraryTagFilterProvider = StateProvider<String>((ref) => '');

final libraryScoresProvider = StreamProvider<List<ScoreListItem>>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  final query = ref.watch(libraryQueryProvider);
  final key = ref.watch(libraryKeyFilterProvider).trim();
  final tag = ref.watch(libraryTagFilterProvider).trim();
  return repository.watchScores(
    query: query,
    key: key.isEmpty ? null : key,
    tag: tag.isEmpty ? null : tag,
  );
});
