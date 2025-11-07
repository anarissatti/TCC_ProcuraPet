import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// mantém o seu caminho:
import 'src/features/auth/presentation/pages/index_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase (Android usa o google-services.json já colocado em android/app/)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Procura-se um Pet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 124, 158, 231),
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
      ),
      home: const WelcomePage(), // sua tela inicial
    );
  }
}
