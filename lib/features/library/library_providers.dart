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

final libraryScoresProvider = StreamProvider<List<ScoreListItem>>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  final query = ref.watch(libraryQueryProvider);
  return repository.watchScores(query: query);
});
