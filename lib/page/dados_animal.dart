import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// CORREÇÃO DE IMPORT: Apontando para o nome do arquivo da página de mapa correto
import 'animal_location_map_page.dart';

// --- DEFINIÇÃO DE CORES PROFISSIONAIS ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E); // Azul Escuro
const Color kAccentLightBlue = Color(0xFF4FC3F7); // Azul Claro
const Color kBackgroundColor = Color(0xFFE3F2FD); // Fundo Suave
const Color kLostColor = Color(0xFFEF5350); // Vermelho para Desaparecido
const Color kFoundColor = Color(0xFF66BB6A); // Verde para Encontrado
const Color kInfoColor = Color(0xFF90CAF9); // Azul para info genérica
// --- FIM DEFINIÇÃO DE CORES ---

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

  // --- WIDGET AUXILIAR AGORA É RESPONSIVO ---
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    // Usa LayoutBuilder para obter o tamanho da tela e garantir que o texto não quebre
    return LayoutBuilder(
      builder: (context, constraints) {
        // Altura do widget é determinada pelo conteúdo (Padding e Row)
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
                    // Removido o SizedBox fixo (width: 250) e usamos o Column Expanded acima
                    // para que o texto use todo o espaço restante e quebre a linha se necessário.
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

  // --- WIDGET BUILD AGORA É RESPONSIVO ---
  @override
  Widget build(BuildContext context) {
    // Usamos MediaQuery para ajustar a altura da imagem
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight =
        screenWidth * 0.7; // A imagem ocupará 70% da largura da tela

    // Extrai os dados (lógica inalterada)
    final String nome = animalData['nome'] ?? 'Nome não informado';
    final String raca = animalData['raca'] ?? 'Raça não informada';
    final String cor = animalData['cor'] ?? 'Não informada';
    final int idade = animalData['idade'] ?? 0;
    final String status = animalData['status'] ?? 'NORMAL';
    final String descricao =
        animalData['descricao'] ??
        'O cuidador não forneceu uma descrição detalhada para este animal.';
    final String imageUrl = animalData['foto_url'] ?? '';

    final Map<String, dynamic>? ultimaLocalizacao =
        animalData['ultima_localizacao'] as Map<String, dynamic>?;

    final dataLocalizacao = ultimaLocalizacao != null
        ? _formatLocationDate(ultimaLocalizacao['data_hora'])
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          nome,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kPrimaryDarkBlue,
        elevation: 8,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEÇÃO DA IMAGEM RESPONSIVA ---
            if (imageUrl.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: Image.network(
                    imageUrl,
                    // Altura dinâmica baseada na largura da tela
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: imageHeight,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Center(
                  child: Text(
                    'Sem foto disponível',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                  ),
                ),
              ),

            // --- TÍTULO E STATUS ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment
                    .start, // Garante que o texto se alinha ao topo
                children: [
                  Expanded(
                    // Permite que o nome ocupe a maior parte do espaço
                    child: Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: kPrimaryDarkBlue,
                      ),
                      maxLines: 2, // Limita o nome para não quebrar o layout
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

            // --- INFORMAÇÕES PRINCIPAIS EM CARD ---
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.merge_type,
                    label: 'Raça:',
                    value: raca,
                  ),
                  _buildInfoRow(icon: Icons.palette, label: 'Cor:', value: cor),
                  _buildInfoRow(
                    icon: Icons.cake,
                    label: 'Idade:',
                    value: idade > 0 ? '$idade anos' : 'Não informada',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- ÚLTIMA LOCALIZAÇÃO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Última Localização:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryDarkBlue.withOpacity(0.9),
                ),
              ),
            ),
            _buildInfoRow(
              icon: Icons.access_time_filled,
              label: 'Data e Hora:',
              value: dataLocalizacao,
              color: kPrimaryDarkBlue.withOpacity(0.8),
            ),

            // --- DESCRIÇÃO ---
            Padding(
              padding: const EdgeInsets.only(
                top: 10,
                left:
                    36, // Mantendo o alinhamento com o ícone para um look clean
                right: 20,
                bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalhes e Descrição:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descricao,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- BOTÃO DE LOCALIZAÇÃO (Responsivo) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnimalLocationMapPage(
                          animalId: animalId,
                          animalName: nome,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.pin_drop, size: 24),
                  label: const Text(
                    'VISUALIZAR NO MAPA',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentLightBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
