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
  String? _selectedColor;

  static const List<String> _animalColors = [
    'Preto',
    'Branco',
    'Marrom',
    'Caramelo',
    'Cinza',
    'Dourado',
    'Ruivo',
    'Tigrado',
    'Bicolor (Ex: Preto e Branco)',
    'Tricolor (Ex: Preto, Branco e Marrom)',
    'Outra',
  ];

  XFile? _imageFile;
  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;

  Uint8List? _imageBytes; // Para uso em Web/Multiplataforma

  String? _mlkitDebug;
  bool _isProcessing = false;

  List<String> _tags = [];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

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

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
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
        for (final label in labels) {
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
      } catch (e, st) {
        final msg = 'Erro ao processar imagem com ImageLabeler: $e';
        print('$msg\n$st');
        setState(() {
          _mlkitDebug = msg;
        });
      } finally {
        imageLabeler.close();
      }
    } else {
      setState(() {
        _mlkitDebug = 'ML Kit indisponível neste ambiente (Web/Desktop).';
      });
    }

    setState(() {
      _isProcessing = false;
    });
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

        _imageBytes = await pickedFile.readAsBytes();

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

  // OTIMIZAÇÃO: Retorna uma posição padrão após um timeout.
  Future<Position> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Serviço de localização desabilitado.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permissão de localização negada.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada para sempre.');
      }

      // Adiciona um timeout de 10 segundos
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print(
            'Timeout: Não foi possível obter localização a tempo. Usando [0, 0].',
          );
          return Position(
            latitude: 0,
            longitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        },
      );
    } catch (e) {
      print('Erro ao obter localização: $e');
      // Retorna posição padrão (0,0) se houver qualquer erro de permissão ou serviço
      return Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  Future<String> _uploadImage() async {
    if (_imageBytes == null) {
      throw Exception('Dados da imagem estão vazios.');
    }

    final fileName =
        'animal_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);

    // O upload com putData é robusto para todas as plataformas
    try {
      await storageRef.putData(_imageBytes!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      // Propaga o erro de upload
      throw Exception('Falha no upload da imagem para o Storage: $e');
    }
  }

  Future<void> _saveAnimal() async {
    if (_nameController.text.isEmpty ||
        _selectedColor == null ||
        _selectedRace == null ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha o Nome, a Cor, a Raça e selecione uma foto.',
          ),
        ),
      );
      return;
    }

    // Usamos o Overlay para mostrar o CircularProgressIndicator
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    Overlay.of(context).insert(overlayEntry);

    try {
      // 1. OTIMIZAÇÃO: Inicia as duas operações demoradas em paralelo
      final results = await Future.wait([
        _getCurrentLocation(), // TAREFA 1: Obtém a localização (com timeout)
        _uploadImage(), // TAREFA 2: Faz o upload da imagem
      ]);

      final position = results[0] as Position;
      final photoUrl = results[1] as String;

      // 2. Preparar dados para Firestore
      final animalData = {
        'id_usuario': "id_temporario_usuario",
        'nome': _nameController.text,
        'raca': _selectedRace,
        'cor': _selectedColor,
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

      // 3. Salvar no Firestore (esta é rápida)
      await _firestore.collection('animals').add(animalData);

      // 4. Sucesso e Limpeza
      overlayEntry.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Animal cadastrado com sucesso!')),
      );

      _nameController.clear();
      _ageController.clear();
      setState(() {
        _selectedStatus = 'NORMAL';
        _selectedRace = null;
        _selectedColor = null;
        _imageFile = null;
        _imageBytes = null;
        _tags = [];
        _mlkitDebug = null;
      });

      Navigator.pop(context);
    } catch (e) {
      // Em caso de erro, remove o loading e mostra a mensagem de erro
      overlayEntry?.remove();
      print('ERRO COMPLETO: $e');
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
            // CAMPO: Nome
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),

            // CAMPO: Raça (DropdownSearch)
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

            // CAMPO: Cor (DropdownButtonFormField)
            DropdownButtonFormField<String>(
              value: _selectedColor,
              decoration: const InputDecoration(labelText: 'Cor'),
              hint: const Text('Selecione a cor principal'),
              items: _animalColors.map<DropdownMenuItem<String>>((
                String value,
              ) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedColor = newValue;
                });
              },
            ),
            const SizedBox(height: 10),

            // CAMPO: Idade
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Idade'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),

            // CAMPO: Status
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

            // Botão Escolher Foto
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Escolher Foto'),
            ),
            const SizedBox(height: 8),

            // Debug ML Kit e Imagem
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
            if (_imageFile != null && _imageBytes != null) ...[
              const SizedBox(height: 10),
              // Exibe a imagem usando bytes (mais compatível)
              Image.memory(
                _imageBytes!,
                height: 150,
                fit: BoxFit.cover,
                semanticLabel: 'Prévia da foto do animal.',
              ),
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
            const SizedBox(height: 30),

            // Botão Cadastrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAnimal,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Cadastrar Animal',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
