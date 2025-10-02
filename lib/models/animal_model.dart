import 'package:cloud_firestore/cloud_firestore.dart';

class Animal {
  final String id;
  final String nome;
  final String raca;
  final String fotoUrl;
  final String status;

  Animal({
    required this.id,
    required this.nome,
    required this.raca,
    required this.fotoUrl,
    required this.status,
  });

  factory Animal.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Animal(
      id: doc.id,
      nome: data['nome'] ?? 'Sem nome',
      raca: data['raca'] ?? 'SRD',
      fotoUrl: data['fotoUrl'] ?? '',
      status: data['status'] ?? 'desconhecido',
    );
  }
}