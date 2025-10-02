// lib/animal_registration_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class AnimalRegistrationPage extends StatefulWidget {
  const AnimalRegistrationPage({super.key});

  @override
  State<AnimalRegistrationPage> createState() => _AnimalRegistrationPageState();
}

class _AnimalRegistrationPageState extends State<AnimalRegistrationPage> {
  final _nameController = TextEditingController();
  final _raceController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedStatus = 'NORMAL';

  File? _image;
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviço de localização desabilitado.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissão de localização negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissão de localização negada para sempre.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _saveAnimal() async {
    // Validações básicas
    if (_nameController.text.isEmpty || _raceController.text.isEmpty || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos e selecione uma foto.')),
      );
      return;
    }

    try {
      // 1. Obter a localização atual
      final position = await _getCurrentLocation();

      // 2. Fazer o upload da foto para o Firebase Storage
      final fileName = 'animal_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(_image!);
      final photoUrl = await storageRef.getDownloadURL();

      // 3. Criar o documento do animal no Firestore
      final animalData = {
        'id_usuario': "id_temporario_usuario", // Substituir por ID de usuário real depois
        'nome': _nameController.text,
        'raca': _raceController.text,
        'idade': int.tryParse(_ageController.text) ?? 0,
        'status': _selectedStatus,
        'foto_url': photoUrl,
        'data_registro': Timestamp.now(),
        'ultima_localizacao': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'data_hora': Timestamp.now(),
        },
      };

      await _firestore.collection('animals').add(animalData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animal cadastrado com sucesso!')),
      );

      _nameController.clear();
      _raceController.clear();
      _ageController.clear();
      setState(() {
        _selectedStatus = 'NORMAL';
        _image = null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar animal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Animal'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // ... (Campos de texto, DropdownButton) ...
            
            // Botão e pré-visualização da imagem
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Escolher Foto'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 10),
              Image.file(_image!, height: 150),
            ],

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveAnimal,
              child: const Text('Cadastrar Animal'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _raceController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}