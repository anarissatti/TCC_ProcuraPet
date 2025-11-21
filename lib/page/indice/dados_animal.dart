import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../animal_location_map_page.dart';

// --- DEFINIÇÃO DE CORES ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E); // Azul Escuro
const Color kAccentLightBlue = Color(0xFF4FC3F7); // Azul Claro
const Color kBackgroundColor = Color(0xFFE3F2FD); // (mantida se quiser usar em outro lugar)
const Color kLostColor = Color(0xFFEF5350); // Vermelho para Desaparecido
const Color kFoundColor = Color(0xFF66BB6A); // Verde para Encontrado
const Color kInfoColor = Color(0xFF90CAF9); // Azul para info genérica

class AnimalDetailsPage extends StatelessWidget {
  final String animalId;
  final Map<String, dynamic> animalData;

  const AnimalDetailsPage({
    required this.animalId,
    required this.animalData,
    Key? key,
  }) : super(key: key);

  String _formatLocationDate(dynamic locationDate) {
    if (locationDate == null) {
      return 'Não há localização registrada.';
    }

    if (locationDate is Timestamp) {
      final dateTime = locationDate.toDate();
      Intl.defaultLocale = 'pt_BR';
      return DateFormat(
        "dd 'de' MMMM 'de' yyyy 'às' HH:mm:ss",
      ).format(dateTime);
    }

    if (locationDate is String) {
      return locationDate;
    }

    return 'Data de localização inválida.';
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: kAccentLightBlue, size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryDarkBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: color ?? Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = screenWidth * 0.6;

    final String nome = animalData['nome'] ?? 'Nome não informado';
    final String raca = animalData['raca'] ?? 'Raça não informada';
    final String cor = animalData['cor'] ?? 'Não informada';
    final int idade = animalData['idade'] ?? 0;
    final int telefone = animalData['telefone'] ?? 0;
    final String status = animalData['status'] ?? 'NORMAL';
    final String descricao =
        animalData['descricao'] ??
            'O cuidador não forneceu uma descrição detalhada para este animal.';

    final String imageUrl =
        (animalData['foto_url'] ?? '').toString().trim();

    final Map<String, dynamic>? ultimaLocalizacao =
        animalData['ultima_localizacao'] as Map<String, dynamic>?;

    final dataLocalizacao = ultimaLocalizacao != null
        ? _formatLocationDate(
            ultimaLocalizacao['data_hora'] ?? ultimaLocalizacao['timestamp'],
          )
        : 'Não há localização registrada.';

    Color statusColor;
    if (status.toUpperCase() == 'DESAPARECIDO') {
      statusColor = kLostColor;
    } else if (status.toUpperCase() == 'ENCONTRADO') {
      statusColor = kFoundColor;
    } else {
      statusColor = kInfoColor;
    }

    return Scaffold(
      // mesmo fundo padrão das outras telas
      backgroundColor: const Color(0xFFBBD0FF),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top: 40, right: 24, child: _bubble(70, opacity: .25)),
            Positioned(top: 90, left: 20, child: _bubble(58, opacity: .18)),
            Positioned(top: 140, left: -24, child: _bubble(96, opacity: .22)),

            // ===== CONTEÚDO =====
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header com botão de voltar + título
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: const Color(0xFF1B2B5B),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.pets_rounded,
                              size: 28, color: cs.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Dados do Animal',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2B5B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Card principal
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.80),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // IMAGEM
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                imageUrl,
                                height: imageHeight,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  debugPrint(
                                      'ERRO AO CARREGAR IMAGEM (DETALHES): $error');
                                  debugPrint(
                                      'URL DETALHES: "$imageUrl"');
                                  return Container(
                                    height: imageHeight,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : Container(
                                height: imageHeight,
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    'Sem foto disponível',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      nome,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: kPrimaryDarkBlue,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Chip(
                                    label: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: statusColor,
                                    avatar: Icon(
                                      status.toUpperCase() == 'DESAPARECIDO'
                                          ? Icons.error_outline
                                          : Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // INFO PRINCIPAIS
                            Card(
                              margin:
                              const EdgeInsets.symmetric(horizontal: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    icon: Icons.merge_type,
                                    label: 'Raça:',
                                    value: raca,
                                  ),
                                  _buildInfoRow(
                                    icon: Icons.palette,
                                    label: 'Cor:',
                                    value: cor,
                                  ),
                                  _buildInfoRow(
                                    icon: Icons.cake,
                                    label: 'Idade:',
                                    value: idade > 0
                                        ? '$idade anos'
                                        : 'Não informada',
                                  ),
                                     _buildInfoRow(
                                    icon: Icons.cake,
                                    label: 'Telefone para contato:',
                                    value: telefone > 999999999
                                        ? '$telefone'
                                        : 'Não informado',
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // ÚLTIMA LOCALIZAÇÃO
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                'Última localização',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryDarkBlue.withOpacity(0.9),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.access_time_filled,
                                    size: 20,
                                    color: kAccentLightBlue,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      dataLocalizacao,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                        kPrimaryDarkBlue.withOpacity(0.85),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // DESCRIÇÃO
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  18, 4, 18, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detalhes e descrição',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryDarkBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    descricao,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // BOTÃO MAPA
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  18, 0, 18, 18),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AnimalLocationMapPage(
                                              animalId: animalId,
                                              animalName: nome,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.pin_drop),
                                  label: const Text(
                                    'Visualizar no mapa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Bolha decorativa (mesmo padrão das outras telas) =====
  Widget _bubble(double size, {double opacity = .2}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity + .05),
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
          stops: const [0.2, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(opacity + .15),
          width: 1.2,
        ),
      ),
    );
  }
}
