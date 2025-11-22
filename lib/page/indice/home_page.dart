import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dados_animal.dart';
import 'main_menu_page.dart';
import 'perfil_page.dart';

// --- HOME PAGE ESTILIZADA ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String filtroSelecionado = 'Todos';

  // Cores baseadas no tema do app
  final Color azulFundo = const Color(0xFFBBD0FF);
  final Color azulEscuro = const Color(0xFF1B2B5B);
  final Color azulClaro = const Color(0xFF7C9EE7);

  // Busca
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> animal) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    final nome = (animal['nome'] ?? '').toString().toLowerCase();
    final raca = (animal['raca'] ?? '').toString().toLowerCase();

    return nome.contains(query) || raca.contains(query);
  }

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
                      page: const MainMenuPage(),
                    ),
                    // "Animais" representa a tela atual → sem navegação
                    _iconTop(
                      Icons.pets_rounded,
                      "Animais",
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

            const SizedBox(height: 8),

            // ===== FILTROS POR STATUS =====
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  _buildFiltroBotao('Todos'),
                  _buildFiltroBotao('Desaparecidos'),
                  _buildFiltroBotao('Encontrados'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ===== CAMPO DE BUSCA =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou raça...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.9),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ===== LISTA DE ANIMAIS =====
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('animals')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: azulClaro),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum animal cadastrado ainda.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1B2B5B),
                        ),
                      ),
                    );
                  }

                  // Primeiro filtra por status
                  final animaisPorStatus = snapshot.data!.docs.where((doc) {
                    final animal = doc.data() as Map<String, dynamic>;
                    final status = (animal['status'] as String?)
                            ?.trim()
                            .toUpperCase() ??
                        '';

                    if (filtroSelecionado == 'Desaparecidos') {
                      return status == 'DESAPARECIDO';
                    }
                    if (filtroSelecionado == 'Encontrados') {
                      return status == 'ENCONTRADO';
                    }

                    // "Todos" → sem filtro de status
                    return true;
                  }).toList();

                  // Depois aplica o filtro de busca (nome/raça)
                  final animaisFiltrados = animaisPorStatus.where((doc) {
                    final animal =
                        doc.data() as Map<String, dynamic>? ?? {};
                    return _matchesSearch(
                      Map<String, dynamic>.from(animal),
                    );
                  }).toList();

                  if (animaisFiltrados.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'Nenhum animal com status "$filtroSelecionado" encontrado.'
                            : 'Nenhum animal encontrado para os filtros atuais.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1B2B5B),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      mainAxisExtent: 260,
                    ),
                    itemCount: animaisFiltrados.length,
                    itemBuilder: (context, index) {
                      final doc = animaisFiltrados[index];
                      final animal = doc.data()! as Map<String, dynamic>;
                      final fotoUrl = (animal['foto_url'] as String?) ?? '';
                      final status = (animal['status'] as String?)
                              ?.trim()
                              .toUpperCase() ??
                          'NORMAL';

                      final Widget imageWidget = _buildFotoWidget(fotoUrl);

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AnimalDetailsPage(
                                animalId: doc.id,
                                animalData: animal,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          color: Colors.white.withOpacity(0.92),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Imagem no topo
                              Expanded(child: imageWidget),

                              // Bloco de textos compacto
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      (animal['nome'] ??
                                              'Animal sem nome')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: azulEscuro,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (animal['raca'] ??
                                              'Raça não informada')
                                          .toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Chip(
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.zero,
                                        visualDensity:
                                            VisualDensity.compact,
                                        labelPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6),
                                        label: Text(
                                          status,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        avatar: const Icon(
                                          Icons.pets,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        backgroundColor:
                                            _getStatusColor(status),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helper de foto: trata gs:// e http/https =====
  Widget _buildFotoWidget(String? url) {
    final isEmpty = url == null || url.trim().isEmpty;
    if (isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.pets, color: Colors.grey, size: 40),
        ),
      );
    }

    // Se vier do Storage como gs://bucket/...
    if (url.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.refFromURL(url).getDownloadURL(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image,
                    color: Colors.red, size: 40),
              ),
            );
          }
          return Image.network(
            snap.data!,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
                progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image,
                    color: Colors.red, size: 40),
              ),
            ),
          );
        },
      );
    }

    // http/https direto
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.red, size: 40),
        ),
      ),
    );
  }

  // ===== ÍCONES DO TOPO =====
  Widget _iconTop(IconData icon, String label, {Widget? page}) {
    return GestureDetector(
      onTap: page == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
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

  // ===== BOTÕES DE FILTRO =====
  Widget _buildFiltroBotao(String texto) {
    final bool selecionado = filtroSelecionado == texto;
    final Color corAtiva = const Color(0xFF1B2B5B);

    return GestureDetector(
      onTap: () => setState(() => filtroSelecionado = texto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? corAtiva : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selecionado ? corAtiva : const Color(0xFFCFD7EA),
            width: 1.5,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: selecionado ? Colors.white : corAtiva,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ===== COR DO STATUS =====
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DESAPARECIDO':
        return Colors.redAccent;
      case 'ENCONTRADO':
        return Colors.green;
      default:
        return const Color(0xFF1B2B5B);
    }
  }
}
