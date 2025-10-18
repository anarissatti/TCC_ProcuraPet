import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// CORREÇÃO DE IMPORT: Apontando para o nome do arquivo da página de mapa correto
import 'animal_location_map_page.dart';

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

    // Se o dado for um Timestamp (salvo pela página de cadastro), formate-o.
    if (locationDate is Timestamp) {
      final dateTime = locationDate.toDate();
      // Define o local para formatar o mês em português
      Intl.defaultLocale = 'pt_BR';
      return DateFormat(
        "dd 'de' MMMM 'de' yyyy 'às' HH:mm:ss",
      ).format(dateTime);
    }

    // Se for uma String (para registros antigos), retorna direto.
    if (locationDate is String) {
      return locationDate;
    }

    // Se o tipo for desconhecido (fallback)
    return 'Data de localização inválida.';
  }

  @override
  Widget build(BuildContext context) {
    // Extrai os dados
    final String nome = animalData['nome'] ?? 'Nome não informado';
    final String raca = animalData['raca'] ?? 'Raça não informada';
    final String cor = animalData['cor'] ?? 'Não informada';
    final int idade = animalData['idade'] ?? 0;
    final String status = animalData['status'] ?? 'Status não informado';
    final String descricao = animalData['descricao'] ?? 'Sem descrição.';
    final String imageUrl = animalData['foto_url'] ?? '';

    // Tenta obter a última localização, se existir
    final Map<String, dynamic>? ultimaLocalizacao =
        animalData['ultima_localizacao'] as Map<String, dynamic>?;

    final dataLocalizacao = ultimaLocalizacao != null
        ? _formatLocationDate(ultimaLocalizacao['data_hora'])
        : 'Não há localização registrada.';

    return Scaffold(
      appBar: AppBar(title: Text(nome), backgroundColor: Colors.pinkAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem do Animal (Foto)
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  imageUrl,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50),
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
                child: const Center(
                  child: Text(
                    'Sem foto',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Título (Nome do Animal)
            Text(
              nome,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
            ),
            const Divider(height: 30, color: Colors.pinkAccent),

            // Informações principais
            _buildInfoRow(icon: Icons.pets, label: 'Raça:', value: raca),
            _buildInfoRow(icon: Icons.color_lens, label: 'Cor:', value: cor),
            _buildInfoRow(
              icon: Icons.cake,
              label: 'Idade:',
              value: idade > 0 ? '$idade anos' : 'Não informada',
            ),
            _buildInfoRow(
              icon: Icons.warning_amber_rounded,
              label: 'Status:',
              value: status,
              color: status.toUpperCase() == 'DESAPARECIDO'
                  ? Colors.red
                  : status.toUpperCase() == 'ENCONTRADO'
                  ? Colors.green
                  : Colors.blueGrey,
            ),
            _buildInfoRow(
              icon: Icons.access_time_filled,
              label: 'Última Localização Registrada:',
              value: dataLocalizacao,
            ),
            const SizedBox(height: 20),

            // Descrição (mantenha a lógica atual, pode ser atualizada depois)
            const Text(
              'Descrição:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 40),

            // Botão para Marcar Localização
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // *** CORREÇÃO DE NAVEGAÇÃO ***
                  // Usando AnimalLocationMapPage (a classe que existe)
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
                  'Ver e Marcar Localização',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para construir linhas de informação
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color ?? Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
