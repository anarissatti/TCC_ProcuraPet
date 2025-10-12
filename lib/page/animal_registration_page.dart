// lib/animal_registration_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';
import 'dart:io';

// Importação do ML Kit
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

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

  // Mensagem de debug visível na UI para diagnosticar problemas com ML Kit
  String? _mlkitDebug;
  bool _isProcessing = false;

  // Lista para armazenar as tags
  List<String> _tags = [];

  // Nova função para processar a imagem e obter as tags
  Future<void> _processImageForLabels() async {
    if (_imageFile == null) return;

    // Detecta plataforma suportada: google_mlkit_image_labeling funciona apenas em Android/iOS
    if (kIsWeb) {
      setState(() {
        _mlkitDebug = 'ML Kit não é suportado na Web.';
      });
      print(_mlkitDebug);
      // Mostra diálogo mais visível em vez de snack para Web/Desktop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Informação'),
            content: Text(_mlkitDebug!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
      return;
    }
    // Para desktop, mostramos mensagem também (plugin fornece builds nativos mobile)
    if (!(Platform.isAndroid || Platform.isIOS)) {
      setState(() {
        _mlkitDebug =
            'ML Kit não é suportado nesta plataforma (apenas Android/iOS).';
      });
      print(_mlkitDebug);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Informação'),
            content: Text(_mlkitDebug!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _mlkitDebug = 'Processando imagem...';
    });

    // Converte a imagem para o formato que o ML Kit entende
    InputImage inputImage;
    File? _tempFile;
    try {
      if (_imageFile!.path.isNotEmpty && File(_imageFile!.path).existsSync()) {
        // Normalmente em mobile o caminho do arquivo funciona
        inputImage = InputImage.fromFilePath(_imageFile!.path);
      } else if (_imageBytes != null) {
        // Se temos bytes (ex.: desktop), escrevemos em um arquivo temporário
        _tempFile = await File(
          '${Directory.systemTemp.path}/mlkit_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ).writeAsBytes(_imageBytes!);
        inputImage = InputImage.fromFilePath(_tempFile.path);
      } else {
        // fallback: tenta a partir do path mesmo assim
        inputImage = InputImage.fromFilePath(_imageFile!.path);
      }
    } catch (e) {
      // Log detalhado para diagnosticar problemas de construção do InputImage
      print('Erro ao criar InputImage: $e');
      // limpa arquivo temporário se criado
      try {
        if (_tempFile != null && _tempFile.existsSync()) _tempFile.deleteSync();
      } catch (_) {}
      return;
    }

    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    final List<String> generatedTags = [];

    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      print('Quantidade de labels retornadas: ${labels.length}');

      // Itera sobre as tags e adiciona à lista se a confiança for alta
      for (final label in labels) {
        print('Label: ${label.label} - confidence: ${label.confidence}');
        // Usamos uma confiança baixa para diagnósticos; depois você ajusta para produção
        if (label.confidence >= 0.0) {
          generatedTags.add(label.label);
        }
      }

      setState(() {
        _tags = generatedTags;
        _mlkitDebug = generatedTags.isNotEmpty
            ? 'Tags geradas: ${generatedTags.join(', ')}'
            : 'Nenhuma tag gerada (labels vazias ou filtradas)';
      });

      print(_mlkitDebug);
    } catch (e, st) {
      final msg = 'Erro ao processar imagem com ImageLabeler: $e';
      print('$msg\n$st');
      setState(() {
        _mlkitDebug = msg;
      });
    } finally {
      try {
        imageLabeler.close();
      } catch (e) {
        print('Erro ao fechar imageLabeler: $e');
      }
      // Limpa arquivo temporário, se houver
      try {
        if (_tempFile != null && _tempFile.existsSync())
          await _tempFile.delete();
      } catch (e) {
        print('Erro ao deletar arquivo temporário: $e');
      }
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

        // Chama a função para processar a imagem e obter as tags
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
        'tags': _tags, // Adiciona as tags geradas
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
        _tags = []; // Limpa as tags
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
            const SizedBox(height: 8),
            // Mostra status/diagnóstico do ML Kit diretamente na UI
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
              if (Theme.of(context).platform == TargetPlatform.android ||
                  Theme.of(context).platform == TargetPlatform.iOS)
                Image.file(File(_imageFile!.path), height: 150)
              else
                Image.memory(_imageBytes!, height: 150),

              // Exibe as tags geradas
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
    _raceController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}
