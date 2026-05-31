import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repotoire/app.dart';
import 'package:repotoire/features/library/library_providers.dart';

void main() {
  testWidgets('shows the empty library state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryScoresProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const RepotoireApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Repotoire'), findsOneWidget);
    expect(find.text('楽譜がありません'), findsOneWidget);
  });
}
