// lib/main_menu_page.dart
import 'package:flutter/material.dart';
import 'animal_registration_page.dart';
import 'animal_list_page.dart'; // Vamos criar essa página em seguida

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Principal'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                // Navega para a página de cadastro de animal
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimalRegistrationPage(),
                  ),
                );
              },
              child: const Text('Cadastrar Animal'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Navega para a página de listagem de animais
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimalListPage(),
                  ),
                );
              },
              child: const Text('Ver Lista de Animais'),
            ),
          ],
        ),
      ),
    );
  }
}