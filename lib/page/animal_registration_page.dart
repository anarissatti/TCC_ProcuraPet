import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// Corrigido: o import deve ser apenas 'geolocator.dart'
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

// --- DEFINIÇÃO DE CORES PROFISSIONAIS ---
// Azul Escuro Principal (Navy Blue) - Para o AppBar e botões principais
const Color kPrimaryDarkBlue = Color(0xFF1A237E);
// Azul Claro/Ciano (Sky Blue) - Para acentuação e ícones
const Color kAccentLightBlue = Color(0xFF4FC3F7);
// Cinza Claro de Fundo
const Color kBackgroundColor = Color(0xFFE3F2FD);
// Cor de Borda dos Campos
const Color kBorderColor = Color(0xFF90CAF9);

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

  Uint8List? _imageBytes;

  String? _mlkitDebug;
  bool _isProcessing = false;

  List<String> _tags = [];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Lógica inalterada
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
        if (filter != null && filter.isNotEmpty) {
          return allBreeds
              .where(
                (breed) => breed.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList();
        }
        return allBreeds;
      }
      return ['Erro ao carregar raças'];
    } catch (e) {
      return ['Erro de conexão'];
    }
  }

  // Lógica inalterada
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
        'Cão',
        'Animal',
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
      } finally {
        imageLabeler.close();
        setState(() => _isProcessing = false);
      }
    } else {
      setState(() {
        _mlkitDebug = 'ML Kit indisponível neste ambiente.';
      });
    }
  }

  // Lógica inalterada
  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _imageFile = pickedFile);
        _imageBytes = await pickedFile.readAsBytes();
        await _processImageForLabels();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma imagem selecionada.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao selecionar imagem: $e')));
    }
  }

  // Lógica inalterada
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled)
      throw Exception('Serviço de localização desabilitado.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  // Lógica inalterada
  Future<String> _uploadImage() async {
    final fileName =
        'animal_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance.ref().child(fileName);
    // Usando `putData` com verificação para evitar Null Safety Warning
    if (_imageBytes != null) {
      await storageRef.putData(_imageBytes!);
      return await storageRef.getDownloadURL();
    } else {
      throw Exception('A imagem não foi carregada corretamente.');
    }
  }

  // Lógica inalterada
  Future<void> _saveAnimal() async {
    if (_nameController.text.isEmpty ||
        _selectedColor == null ||
        _selectedRace == null ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios!')),
      );
      return;
    }

    final overlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              // Usando a cor de acentuação para o indicador de progresso
              CircularProgressIndicator(color: kAccentLightBlue),
              SizedBox(height: 10),
              Text(
                'Cadastrando animal...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);

    try {
      final results = await Future.wait([
        _getCurrentLocation(),
        _uploadImage(),
      ]);
      final position = results[0] as Position;
      final photoUrl = results[1] as String;

      await _firestore.collection('animals').add({
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
      });

      overlay.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal cadastrado com sucesso! 🎉'),
          backgroundColor: kPrimaryDarkBlue,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      overlay.remove();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao cadastrar: $e')));
    }
  }

  // Função auxiliar para definir o estilo do campo de texto (Reutilizado do design anterior para consistência)
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kPrimaryDarkBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccentLightBlue, width: 2.0),
      ),
      prefixIcon: Icon(icon, color: kAccentLightBlue),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // --- WIDGET BUILD COM NOVO DESIGN ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '🐾 Cadastro de Animal Perdido',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: kPrimaryDarkBlue, // Azul Escuro no AppBar
        elevation: 8,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Campos de Entrada (TextField e Dropdowns)
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nome do Animal', Icons.pets),
                ),
                const SizedBox(height: 20),

                DropdownSearch<String>(
                  asyncItems: _fetchDogBreeds,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchDelay: const Duration(milliseconds: 300),
                    showSelectedItems: true,
                    menuProps: MenuProps(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: _inputDecoration(
                      'Raça (Pesquisar)',
                      Icons.merge_type,
                    ),
                  ),
                  selectedItem: _selectedRace,
                  onChanged: (value) => setState(() => _selectedRace = value),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _selectedColor,
                  decoration: _inputDecoration('Cor Principal', Icons.palette),
                  items: _animalColors
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedColor = v),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: kAccentLightBlue,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _ageController,
                  decoration: _inputDecoration('Idade (anos)', Icons.cake),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _inputDecoration('Status', Icons.info_outline),
                  items: ['NORMAL', 'DESAPARECIDO', 'ENCONTRADO']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: kAccentLightBlue,
                  ),
                ),
                const SizedBox(height: 30),

                // Botão Selecionar Foto (Azul Claro)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera_back, size: 24),
                    label: const Text(
                      'Selecionar Foto (Obrigatório)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentLightBlue, // Azul Claro
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Preview da Imagem
                if (_imageBytes != null)
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _imageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),

                // Tags Geradas (Chips estilizados)
                if (_tags.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Tags Geradas (ML Kit):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kPrimaryDarkBlue.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: _tags
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: const TextStyle(
                                  color: kPrimaryDarkBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: kAccentLightBlue.withOpacity(
                                0.2,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              side: const BorderSide(
                                color: kAccentLightBlue,
                                width: 1,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 10),

                // Botão de Cadastro Final (Azul Escuro Principal)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveAnimal,
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: const Text(
                      'CONCLUIR CADASTRO',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryDarkBlue, // Azul Escuro
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
