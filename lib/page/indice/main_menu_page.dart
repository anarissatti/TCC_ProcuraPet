import 'package:flutter/material.dart';
import '../animal_registration_page.dart';
import 'package:tcc_procurapet/page/buscar_animal.dart';
import 'home_page.dart'; // para acessar as páginas dos ícones superiores
import 'perfil_page.dart';
import 'map_page.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final Color azulFundo = const Color(0xFFBBD0FF);
  final Color azulEscuro = const Color(0xFF1B2B5B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: azulFundo,
      body: SafeArea(
        child: Column(
          children: [
            // ===== ÍCONES SUPERIORES =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _iconTop(
                      Icons.menu_rounded,
                      "Menu",
                    ),
                    // "Animais" representa a tela atual → sem navegação
                    _iconTop(
                      Icons.pets_rounded,
                      "Animais",
                      page: const HomePage(),
                    ),
                    _iconTop(
                      Icons.person_outline_rounded,
                      "Perfil",
                      page: const PerfilPage(),
                    ),
                  ],
                ),
              ),
            ),

              const SizedBox(height: 30),

              // ===== CARDS DE AÇÃO =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildMenuCard(
                      context,
                      title: 'Cadastrar Pet Perdido',
                      subtitle: 'Registrar um animal desaparecido',
                      color: const Color(0xFF7C9EE7),
                      icon: Icons.pets_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AnimalRegistrationPage(),
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
                      icon: Icons.search_rounded,
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
                      icon: Icons.map_rounded,
                      onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LostAnimalsMapPage(),
                        ),
                      );
                    },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      );
  }

  // ===== ÍCONES DO TOPO (MESMO DA HOME) =====
  Widget _iconTop(IconData icon, String label, {Widget? page}) {
  return GestureDetector(
    onTap: page == null
        ? null
        : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page!),
            );
          },
    child: Column(
      children: [
        Icon(icon, size: 28, color: const Color(0xFF1B2B5B)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1B2B5B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

  // ===== CARDS DE MENU =====
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
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 28),
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
