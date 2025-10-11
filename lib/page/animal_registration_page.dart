// lib/animal_registration_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
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

  XFile? _imageFile;
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;

  Uint8List? _imageBytes;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS) {
        setState(() {
          _imageFile = pickedFile;
        });
      } else {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = pickedFile;
        });
      }
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
    if (_nameController.text.isEmpty ||
        _raceController.text.isEmpty ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha todos os campos e selecione uma foto.',
          ),
        ),
      );
      return;
    }

    try {
      final position = await _getCurrentLocation();
      final fileName =
          'animal_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      if (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS) {
        await storageRef.putFile(File(_imageFile!.path));
      } else {
        await storageRef.putData(_imageBytes!);
      }

      final photoUrl = await storageRef.getDownloadURL();

      final animalData = {
        'id_usuario': "id_temporario_usuario",
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
        _imageFile = null;
        _imageBytes = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao cadastrar animal: $e')));
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
            // Campos de texto e DropdownButton re-adicionados aqui
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _raceController,
              decoration: const InputDecoration(labelText: 'Raça'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Idade'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: <String>['NORMAL', 'DESAPARECIDO', 'ENCONTRADO']
                  .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  })
                  .toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedStatus = newValue!;
                });
              },
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Escolher Foto'),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              if (Theme.of(context).platform == TargetPlatform.android ||
                  Theme.of(context).platform == TargetPlatform.iOS)
                Image.file(File(_imageFile!.path), height: 150)
              else
                Image.memory(_imageBytes!, height: 150),
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
