import 'package:flutter/material.dart';

import 'features/library/library_screen.dart';

class RepotoireApp extends StatelessWidget {
  const RepotoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Repotoire',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2b6f6d),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
