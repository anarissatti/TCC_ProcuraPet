import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAnimalPhoto(String animalId, File imageFile) async {
    try {
      // Cria a referência no Storage com o caminho 'animals/ID_DO_ANIMAL.jpg'
      final ref = _storage.ref().child('animals').child('$animalId.jpg');
      
      // Faz o upload do arquivo
      UploadTask uploadTask = ref.putFile(imageFile);
      
      // Espera o upload ser concluído
      TaskSnapshot snapshot = await uploadTask;
      
      // Pega a URL de download
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Erro no upload da imagem: $e");
      rethrow;
    }
  }
}