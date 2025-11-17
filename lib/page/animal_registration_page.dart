import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 IMPORTANTE

// --- DEFINIÇÃO DE CORES (algumas ainda usadas em detalhes) ---
const Color kPrimaryDarkBlue = Color(0xFF1A237E);
const Color kAccentLightBlue = Color(0xFF4FC3F7);
const Color kBorderColor = Color(0xFF90CAF9);

class AnimalRegistrationPage extends StatefulWidget {
  const AnimalRegistrationPage({super.key});

  @override
  State<AnimalRegistrationPage> createState() => _AnimalRegistrationPageState();
}

class _AnimalRegistrationPageState extends State<AnimalRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedStatus;
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
    _descriptionController.dispose();
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
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desabilitado.');
    }

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
    if (_imageBytes != null) {
      await storageRef.putData(_imageBytes!);
      return await storageRef.getDownloadURL();
    } else {
      throw Exception('A imagem não foi carregada corretamente.');
    }
  }

  // NOVO: overlay de loading estilizado
  OverlayEntry _buildLoadingOverlay() {
    return OverlayEntry(
      builder: (context) => Container(
        color: Colors.black45,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kAccentLightBlue,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Cadastrando animal...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1B2B5B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NOVO: diálogo bonitinho de sucesso no centro da tela
  Future<void> _showSuccessDialog() async {
    final cs = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone circular
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 42,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Animal cadastrado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2B5B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O pet foi registrado com sucesso.\nObrigado por ajudar outros tutores! 🐾',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      // Fecha o dialog
                      Navigator.of(dialogContext).pop();
                      // Volta para a tela anterior (menu, home, etc.)
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Voltar ao menu',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // LÓGICA DE SALVAR COM NOVAS MENSAGENS + USER ID
  Future<void> _saveAnimal() async {
    // Validação básica
    if (_nameController.text.isEmpty ||
        _selectedColor == null ||
        _selectedRace == null ||
        _selectedStatus == null ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios!')),
      );
      return;
    }

    // Usuário logado
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para cadastrar um animal.'),
        ),
      );
      return;
    }
    final uid = user.uid;

    final overlay = _buildLoadingOverlay();
    Overlay.of(context).insert(overlay);

    try {
      final results = await Future.wait([
        _getCurrentLocation(),
        _uploadImage(),
      ]);
      final position = results[0] as Position;
      final photoUrl = results[1] as String;

      await _firestore.collection('animals').add({
        // 👇 Identificação do dono do cadastro
        'userId': uid,                // usado na PerfilPage
        'id_usuario': uid,            // opcional, pra compatibilidade

        'nome': _nameController.text,
        'raca': _selectedRace,
        'cor': _selectedColor,
        'idade': int.tryParse(_ageController.text) ?? 0,
        'status': _selectedStatus,
        'descricao': _descriptionController.text,
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

      await _showSuccessDialog();
    } catch (e) {
      overlay.remove();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao cadastrar: $e')));
    }
  }

  // ===== InputDecoration no mesmo estilo da LoginPage =====
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(.6),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFD7EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCFD7EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C9EE7), width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  // --- WIDGET BUILD COM MESMO ESTILO DA LOGINPAGE ---
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Mesmo tom da página de login
      backgroundColor: const Color(0xFFBBD0FF),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top: 40, right: 24, child: _bubble(70, opacity: .25)),
            Positioned(top: 90, left: 20, child: _bubble(58, opacity: .18)),
            Positioned(top: 140, left: -24, child: _bubble(96, opacity: .22)),

            // ===== CONTEÚDO =====
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho com patinha + título (igual padrão do login)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets_rounded,
                              size: 32, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Cadastro de Animal',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: 0.2,
                              color: Color(0xFF1B2B5B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cadastre um animal perdido ou encontrado\npara ajudar outras pessoas a encontrá-lo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card branco translúcido (igual login)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nome do animal
                            TextField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                label: 'NOME DO ANIMAL',
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Raça (DropdownSearch)
                            DropdownSearch<String>(
                              asyncItems: _fetchDogBreeds,
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchDelay:
                                    const Duration(milliseconds: 300),
                                showSelectedItems: true,
                                menuProps: MenuProps(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              dropdownDecoratorProps: DropDownDecoratorProps(
                                dropdownSearchDecoration: _inputDecoration(
                                  label: 'RAÇA',
                                ),
                              ),
                              selectedItem: _selectedRace,
                              onChanged: (value) =>
                                  setState(() => _selectedRace = value),
                            ),
                            const SizedBox(height: 14),

                            // Cor principal
                            DropdownButtonFormField<String>(
                              value: _selectedColor,
                              decoration: _inputDecoration(
                                label: 'COR PRINCIPAL',
                              ),
                              items: _animalColors
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedColor = v),
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                            ),
                            const SizedBox(height: 14),

                            // Idade
                            TextField(
                              controller: _ageController,
                              decoration: _inputDecoration(
                                label: 'IDADE (ANOS)',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 14),

                            // Status
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: _inputDecoration(
                                label: 'STATUS',
                              ),
                              items: const [
                                'DESAPARECIDO',
                                'ENCONTRADO',
                              ].map((s) {
                                return DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                );
                              }).toList(),
                              onChanged: (String? v) {
                                setState(() {
                                  _selectedStatus = v;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecione o status do animal';
                                }
                                return null;
                              },
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                            ),
                            const SizedBox(height: 18),

                            // Descrição
                            TextField(
                              controller: _descriptionController,
                              decoration: _inputDecoration(
                                label: 'Detalhes e Descrição',
                              ),
                              keyboardType: TextInputType.multiline,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),

                            // Botão Selecionar Foto
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isProcessing ? null : _pickImage,
                                icon: _isProcessing
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_back_outlined,
                                      ),
                                label: Text(
                                  _isProcessing
                                      ? 'Analisando imagem...'
                                      : 'Selecionar foto (obrigatório)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Preview da imagem
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
                                  const SizedBox(height: 12),
                                ],
                              ),

                            // Tags geradas pelo ML Kit
                            if (_tags.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    'Tags geradas (ML Kit):',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          kPrimaryDarkBlue.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                            if (_tags.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12.0),
                                child: Wrap(
                                  spacing: 8,
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
                                          backgroundColor:
                                              kAccentLightBlue.withOpacity(
                                            0.2,
                                          ),
                                          labelPadding:
                                              const EdgeInsets.symmetric(
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

                            if (_mlkitDebug != null)
                              Text(
                                _mlkitDebug!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                              ),

                            const SizedBox(height: 18),

                            // Botão de cadastro final
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _saveAnimal,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                ),
                                label: const Text(
                                  'Concluir cadastro',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Bolha decorativa (igual LoginPage) =====
  Widget _bubble(double size, {double opacity = .2}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity + .05),
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
          stops: const [0.2, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(opacity + .15),
          width: 1.2,
        ),
      ),
    );
  }
}
