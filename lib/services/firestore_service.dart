import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Adiciona um novo documento de animal com dados iniciais
  Future<DocumentReference> addAnimal(Map<String, dynamic> animalData) {
    return _db.collection('animals').add(animalData);
  }

  // Atualiza um animal existente (por exemplo, para adicionar a URL da foto)
  Future<void> updateAnimal(String docId, Map<String, dynamic> dataToUpdate) {
    return _db.collection('animals').doc(docId).update(dataToUpdate);
  }
}