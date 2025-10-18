import 'package:flutter/material.dart';
// Imports dos arquivos que estão na mesma pasta (assumindo a estrutura padrão)
import 'animal_registration_page.dart';
import 'animal_list_page.dart';

// Imports dos arquivos que estão na subpasta 'page/'
import 'package:tcc_procurapet/page/buscar_animal.dart';
// NOTE: O import abaixo não é mais necessário aqui, pois a navegação é feita de AnimalDetailsPage
// import 'package:tcc_procurapet/page/animal_location_map_page.dart';

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
            // Botão: Cadastrar Animal
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimalRegistrationPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 60),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cadastrar Animal',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Botão: Ver Lista de Animais
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimalListPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 60),
                backgroundColor: Colors.lightGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Ver Lista de Animais',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Botão: Buscar Animal
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BuscarAnimalPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 60),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Buscar Animal',
                style: TextStyle(fontSize: 18),
              ),
            ),

            // NOTA: O botão "Adicionar Localização" foi removido daqui.
            // O fluxo correto é: Lista -> Detalhes -> Mapa de Localização.
          ],
        ),
      ),
    );
  }
}
