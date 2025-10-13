// lib/animal_registration_page.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class AnimalRegistrationPage extends StatefulWidget {
  const AnimalRegistrationPage({super.key});

  @override
  State<AnimalRegistrationPage> createState() => _AnimalRegistrationPageState();
}

class _AnimalRegistrationPageState extends State<AnimalRegistrationPage> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedStatus = 'NORMAL';
  String? _selectedRace;

  XFile? _imageFile;
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;

  Uint8List? _imageBytes;

  String? _mlkitDebug;
  bool _isProcessing = false;

  List<String> _tags = [];

  Future<List<String>> _fetchDogBreeds(String? filter) async {
    try {
      final response = await http.get(
        Uri.parse('https://dog.ceo/api/breeds/list/all'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> breeds = data['message'];

        final List<String> allBreeds = breeds.keys.toList();

        allBreeds.insert(0, 'Vira-Lata / SRD');

        return allBreeds;
      } else {
        print('Erro ao buscar raças: ${response.statusCode}');
        return ['Erro ao carregar raças'];
      }
    } catch (e) {
      print('Erro de rede: $e');
      return ['Erro de conexão'];
    }
  }

  Future<void> _processImageForLabels() async {
    if (_imageFile == null) return;

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      setState(() {
        _mlkitDebug =
            'ML Kit de etiquetagem de imagens só é suportado no Android e iOS.';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mlkitDebug!)));
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _mlkitDebug = 'Processando imagem...';
    });

    final inputImage = InputImage.fromFilePath(_imageFile!.path);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    final List<String> generatedTags = [];
    final List<String> ignoredTags = [
      'Planta',
      'Árvore',
      'Natureza',
      'Gramado',
      'Ao ar livre',
      'Rua',
    ];

    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );
      print('Quantidade de labels retornadas: ${labels.length}');

      for (final label in labels) {
        print('Label: ${label.label} - confidence: ${label.confidence}');
        if (label.confidence >= 0.70 && !ignoredTags.contains(label.label)) {
          generatedTags.add(label.label);
        }
      }

      setState(() {
        _tags = generatedTags;
        _mlkitDebug = generatedTags.isNotEmpty
            ? 'Tags geradas: ${generatedTags.join(', ')}'
            : 'Nenhuma tag relevante encontrada.';
      });

      print(_mlkitDebug);
    } catch (e, st) {
      final msg = 'Erro ao processar imagem com ImageLabeler: $e';
      print('$msg\n$st');
      setState(() {
        _mlkitDebug = msg;
      });
    } finally {
      imageLabeler.close();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _mlkitDebug = 'Selecionando imagem...';
      });

      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
        await _processImageForLabels();
      } else {
        setState(() {
          _mlkitDebug = 'Nenhuma imagem selecionada.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma imagem selecionada.')),
        );
      }
    } catch (e) {
      setState(() {
        _mlkitDebug = 'Erro ao selecionar imagem: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao selecionar imagem: $e')));
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
        _selectedRace == null ||
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

      await storageRef.putFile(File(_imageFile!.path));

      final photoUrl = await storageRef.getDownloadURL();

      final animalData = {
        'id_usuario': "id_temporario_usuario",
        'nome': _nameController.text,
        'raca': _selectedRace,
        'idade': int.tryParse(_ageController.text) ?? 0,
        'status': _selectedStatus,
        'foto_url': photoUrl,
        'data_registro': Timestamp.now(),
        'ultima_localizacao': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'data_hora': Timestamp.now(),
        },
        'tags': _tags,
      };

      await _firestore.collection('animals').add(animalData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animal cadastrado com sucesso!')),
      );

      _nameController.clear();
      _ageController.clear();
      setState(() {
        _selectedStatus = 'NORMAL';
        _selectedRace = null;
        _imageFile = null;
        _imageBytes = null;
        _tags = [];
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            DropdownSearch<String>(
              asyncItems: _fetchDogBreeds,
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                showSelectedItems: true,
              ),
              selectedItem: _selectedRace,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Raça',
                  hintText: 'Selecione a raça',
                ),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRace = newValue;
                });
              },
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
            const SizedBox(height: 8),
            if (_mlkitDebug != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    if (_isProcessing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mlkitDebug!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              if (kIsWeb || !(Platform.isAndroid || Platform.isIOS))
                if (_imageBytes != null)
                  Image.memory(_imageBytes!, height: 150)
                else
                  const SizedBox.shrink()
              else
                Image.file(File(_imageFile!.path), height: 150),
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8.0,
                    children: _tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.blue[50],
                          ),
                        )
                        .toList(),
                  ),
                ),
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
    _ageController.dispose();
    super.dispose();
  }
}
