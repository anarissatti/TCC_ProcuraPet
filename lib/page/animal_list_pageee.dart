import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tcc_procurapet/page/indice/dados_animal.dart';

// --- CORES ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E);
const Color kAccentLightBlue = Color(0xFF4FC3F7);
const Color kBackgroundColor = Color(0xFFE3F2FD);
const Color kLostColor = Color(0xFFEF5350);   // Perdidos
const Color kFoundColor = Color(0xFF66BB6A);  // Encontrados
const Color kBorderColor = Color(0xFF90CAF9);

// Largura máxima de cada card
const double kMaxItemWidth = 200.0;

class AnimalListPage extends StatefulWidget {
  const AnimalListPage({super.key});

  @override
  State<AnimalListPage> createState() => _AnimalListPageState();
}

class _AnimalListPageState extends State<AnimalListPage> {
  /// Opções: 'Todos', 'Perdidos', 'Encontrados'
  String filtroSelecionado = 'Todos';

  // ===== BOTÕES DE FILTRO (TOPO) =====
  Widget _buildFiltroBotao(String texto) {
    final bool selecionado = filtroSelecionado == texto;

    Color corPrincipal;
    switch (texto) {
      case 'Perdidos':
        corPrincipal = kLostColor;
        break;
      case 'Encontrados':
        corPrincipal = kFoundColor;
        break;
      default:
        corPrincipal = kPrimaryDarkBlue;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          filtroSelecionado = texto;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? corPrincipal : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selecionado ? corPrincipal : kBorderColor,
            width: 1.5,
          ),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: corPrincipal.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: selecionado ? Colors.white : corPrincipal,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String statusUpper) {
    switch (statusUpper) {
      case 'DESAPARECIDO':
      case 'PERDIDO':
        return Icons.location_off;
      case 'ENCONTRADO':
        return Icons.check_circle;
      default:
        return Icons.pets;
    }
  }

  Color _getStatusColor(String statusUpper) {
    switch (statusUpper) {
      case 'DESAPARECIDO':
      case 'PERDIDO':
        return kLostColor;
      case 'ENCONTRADO':
        return kFoundColor;
      default:
        return kPrimaryDarkBlue.withOpacity(0.7);
    }
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '🐶 Encontre seu Amigo! 🐱',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kPrimaryDarkBlue,
        centerTitle: true,
        elevation: 8,
      ),
      body: Column(
        children: [
          // --- Filtros de Status (Todos / Perdidos / Encontrados) ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 12.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 12,
                children: [
                  _buildFiltroBotao('Todos'),
                  _buildFiltroBotao('Perdidos'),
                  _buildFiltroBotao('Encontrados'),
                ],
              ),
            ),
          ),

          // --- Lista de animais (GridView) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('animals')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: kAccentLightBlue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum animal cadastrado ainda.',
                      style: TextStyle(fontSize: 16, color: kPrimaryDarkBlue),
                    ),
                  );
                }

                // --- FILTRO POR STATUS (usando campo "status") ---
                final animais = snapshot.data!.docs.where((doc) {
                  final animal = doc.data() as Map<String, dynamic>;
                  final statusUpper =
                      (animal['status'] ?? '').toString().toUpperCase();

                  if (filtroSelecionado == 'Perdidos') {
                    return statusUpper == 'PERDIDO' ||
                        statusUpper == 'DESAPARECIDO';
                  }
                  if (filtroSelecionado == 'Encontrados') {
                    return statusUpper == 'ENCONTRADO';
                  }
                  return true; // 'Todos'
                }).toList();

                if (animais.isEmpty && filtroSelecionado != 'Todos') {
                  final label = filtroSelecionado == 'Perdidos'
                      ? 'perdido'
                      : 'encontrado';

                  return Center(
                    child: Text(
                      'Nenhum animal marcado como $label.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: kPrimaryDarkBlue,
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: kMaxItemWidth,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: animais.length,
                  itemBuilder: (context, index) {
                    final doc = animais[index];
                    final animal = doc.data()! as Map<String, dynamic>;

                    final rawFotoUrl = animal['foto_url'];
                    final fotoUrl = (rawFotoUrl ?? '').toString().trim();

                    // status em duas versões: original p/ exibir, upper p/ lógica
                    final rawStatus = (animal['status'] ?? 'Perdido').toString();
                    final statusUpper = rawStatus.toUpperCase();

                    // --- IMAGEM ---
                    Widget imageWidget;
                    if (fotoUrl.isEmpty) {
                      imageWidget = Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.pets,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      );
                    } else {
                      imageWidget = Image.network(
                        fotoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: kAccentLightBlue,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                              'ERRO AO CARREGAR IMAGEM (LISTA): $error');
                          debugPrint('URL LISTA: "$fotoUrl"');
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      );
                    }

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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryDarkBlue.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Foto
                            Expanded(
                              flex: 2,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                child: imageWidget,
                              ),
                            ),

                            // Detalhes
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text(
                                      animal['nome'] ?? 'Animal sem nome',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: kPrimaryDarkBlue,
                                      ),
                                    ),
                                    Text(
                                      animal['raca'] ?? 'Raça não informada',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        rawStatus,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      avatar: Icon(
                                        _getStatusIcon(statusUpper),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      backgroundColor:
                                          _getStatusColor(statusUpper),
                                      padding: EdgeInsets.zero,
                                      labelPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 0,
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
}
