import 'dart:io';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

class SearchService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<List<dynamic>> findSimilarAnimals(File imageFile) async {
    try {
      // 1. Converte a imagem para base64
      final bytes = await imageFile.readAsBytes();
      final String imageBase64 = base64Encode(bytes);

      // 2. Chama a Cloud Function
      HttpsCallable callable = _functions.httpsCallable('findSimilarAnimals');
      final response = await callable.call<List<dynamic>>({'image': imageBase64});
      
      return response.data;
    } on FirebaseFunctionsException catch (e) {
      print('Erro ao chamar a Cloud Function: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Ocorreu um erro inesperado: $e');
      rethrow;
    }
  }
}