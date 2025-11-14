import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature/paint/presentation/pages/paint_page.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Paint',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PaintPage(),
    );
  }
}
