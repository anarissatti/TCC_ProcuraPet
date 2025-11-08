import 'package:flutter/material.dart';
import 'animal_registration_page.dart';
import 'animal_list_page.dart';
import 'package:tcc_procurapet/page/buscar_animal.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Cabeçalho com imagem e boas-vindas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF60A5FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      //Image.asset('assets/pet_banner.png')
                      'assets/pet_banner.png', // 🐾 imagem no topo (adicione depois)
                      height: 120,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Seja Bem-vindo!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Ajude a encontrar ou cadastrar um pet perdido 🐶🐱',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 🔹 Botões estilizados
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildMenuCard(
                      context,
                      title: 'Cadastrar Pet Perdido',
                      subtitle: 'Registrar um animal desaparecido',
                      color: const Color(0xFF60A5FA),
                      icon: Icons.pets,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const AnimalRegistrationPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildMenuCard(
                      context,
                      title: 'Buscar Animal',
                      subtitle: 'Procurar por um pet desaparecido',
                      color: const Color(0xFF34D399),
                      icon: Icons.search,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const BuscarAnimalPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildMenuCard(
                      context,
                      title: 'Mapa de Animais Perdidos',
                      subtitle: 'Visualizar onde os pets foram vistos',
                      color: const Color(0xFFFBBF24),
                      icon: Icons.map,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AnimalListPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Função auxiliar para criar cartões com estilo moderno
  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
