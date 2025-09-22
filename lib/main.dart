import 'package:flutter/material.dart';
// ajuste o import conforme sua pasta:
import 'src/features/auth/presentation/pages/index_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Procura-se um Pet',
      // ⬇️ sua tela inicial para testar
      home: const IndexPage(),
    );
  }
}
