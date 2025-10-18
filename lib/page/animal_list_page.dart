import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tcc_procurapet/page/dados_animal.dart';

class AnimalListPage extends StatelessWidget {
  const AnimalListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Animais Cadastrados'),
        backgroundColor: Colors.lightGreen,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('animals').snapshots(),
        builder: (context, snapshot) {
          // 1. Lógica para verificar o estado da conexão
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Lógica para verificar se há erros
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          // 3. Lógica para verificar se não há dados
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Nenhum animal cadastrado ou encontrado.'),
            );
          }

          // 4. Lógica para exibir a lista de dados
          final animals = snapshot.data!.docs;

          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final DocumentSnapshot doc = animals[index];
              final String animalId = doc.id;
              final Map<String, dynamic> animal =
                  doc.data()! as Map<String, dynamic>;

              // Exibindo os dados de cada animal em um Card
              return Card(
                elevation: 4, // Adiciona uma pequena sombra
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: const Icon(Icons.pets, color: Colors.lightGreen),
                  title: Text(
                    animal['nome'] ?? 'Sem nome',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Raça: ${animal['raca'] ?? 'Não informada'} | Status: ${animal['status'] ?? 'Não informado'}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // *** AÇÃO DE NAVEGAÇÃO PARA A PÁGINA DE DETALHES ***
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnimalDetailsPage(
                          animalId: animalId,
                          animalData: animal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
