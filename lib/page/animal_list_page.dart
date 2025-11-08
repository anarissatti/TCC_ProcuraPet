import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Certifique-se de que este import está correto no seu projeto
import 'package:tcc_procurapet/page/dados_animal.dart';

// --- DEFINIÇÃO DE CORES PROFISSIONAIS ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E);
const Color kAccentLightBlue = Color(0xFF4FC3F7);
const Color kBackgroundColor = Color(0xFFE3F2FD);
const Color kLostColor = Color(0xFFEF5350);
const Color kFoundColor = Color(0xFF66BB6A);
const Color kBorderColor = Color(0xFF90CAF9);

// --- CONSTANTE PARA RESPONSIVIDADE ---
// Define a largura máxima que cada item do grid pode ter.
// O Flutter calculará quantas colunas cabem.
const double kMaxItemWidth = 200.0;

class AnimalListPage extends StatefulWidget {
  const AnimalListPage({super.key});

  @override
  State<AnimalListPage> createState() => _AnimalListPageState();
}

class _AnimalListPageState extends State<AnimalListPage> {
  String filtroSelecionado = 'Todos';

  // --- Funções de Estilo (Inalteradas) ---
  Widget _buildFiltroBotao(String texto) {
    final bool selecionado = filtroSelecionado == texto;

    Color corPrincipal;
    if (texto == 'Todos') {
      corPrincipal = kPrimaryDarkBlue;
    } else if (texto == 'Cachorros') {
      corPrincipal = kAccentLightBlue;
    } else {
      corPrincipal = kLostColor;
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

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'DESAPARECIDO':
        return Icons.location_off;
      case 'ENCONTRADO':
        return Icons.check_circle;
      default:
        return Icons.pets;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DESAPARECIDO':
        return kLostColor;
      case 'ENCONTRADO':
        return kFoundColor;
      default:
        return kPrimaryDarkBlue.withOpacity(0.7);
    }
  }

  // --- WIDGET BUILD COM CORREÇÃO DE RESPONSIVIDADE ---
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
          // --- Filtros Elegantes no Topo ---
          // Wrap é ideal para botões, mas a versão anterior usava Row.
          // Mantenho o SingleChildScrollView e Row para não alterar drasticamente a estrutura,
          // mas o uso de 'spacing' em Row é incomum a menos que você esteja usando um pacote
          // como o 'flex_layout'. Se estiver dando erro, use 'Wrap' em vez de 'Row'.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18.0,
              vertical: 12.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Nota: Mude 'Row(spacing: 12, children: [...])' para 'Wrap(spacing: 12, children: [...])'
              // se Row não tiver o parâmetro 'spacing' na sua versão.
              child: Wrap(
                spacing: 12,
                children: [
                  _buildFiltroBotao('Todos'),
                  _buildFiltroBotao('Cachorros'),
                  _buildFiltroBotao('Gatos'),
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

                final animais = snapshot.data!.docs.where((doc) {
                  final animal = doc.data() as Map<String, dynamic>;
                  final raca = (animal['raca']?.toLowerCase() ?? '');

                  if (filtroSelecionado == 'Todos') return true;
                  if (filtroSelecionado == 'Cachorros') {
                    return !raca.contains('gato') && raca.isNotEmpty;
                  }
                  if (filtroSelecionado == 'Gatos') {
                    return raca.contains('gato');
                  }
                  return true;
                }).toList();

                if (animais.isEmpty && filtroSelecionado != 'Todos') {
                  return Center(
                    child: Text(
                      'Nenhum animal da categoria "$filtroSelecionado" encontrado.',
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
                  // MUDANÇA PRINCIPAL AQUI PARA RESPONSIVIDADE:
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: kMaxItemWidth, // Largura máxima do item
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.75, // Proporção altura/largura
                  ),
                  // FIM MUDANÇA PRINCIPAL
                  itemCount: animais.length,
                  itemBuilder: (context, index) {
                    final doc = animais[index];
                    final animal = doc.data()! as Map<String, dynamic>;
                    final fotoUrl = animal['foto_url'] as String? ?? '';
                    final status = animal['status'] as String? ?? 'NORMAL';

                    Widget imageWidget;
                    if (fotoUrl.isEmpty) {
                      imageWidget = Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.pets, color: Colors.grey, size: 40),
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
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ),
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
                            // Foto do animal
                            Expanded(
                              flex: 2,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                child: imageWidget, // Usando o widget da imagem
                              ),
                            ),

                            // Detalhes (Nome, Raça, Status)
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
                                    // Status em destaque (Chip)
                                    Chip(
                                      label: Text(
                                        status,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      avatar: Icon(
                                        _getStatusIcon(status),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      backgroundColor: _getStatusColor(status),
                                      padding: EdgeInsets.zero,
                                      labelPadding: const EdgeInsets.symmetric(
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
