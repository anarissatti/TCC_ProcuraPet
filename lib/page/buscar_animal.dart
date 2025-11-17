// lib/page/buscar_animal.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

class BuscarAnimalPage extends StatefulWidget {
  const BuscarAnimalPage({super.key});

  @override
  _BuscarAnimalPageState createState() => _BuscarAnimalPageState();
}

class _BuscarAnimalPageState extends State<BuscarAnimalPage> {
  File? _selectedImage;
  final _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _foundAnimals = [];
  bool _isLoading = false;

  String? _selectedRace;
  String? _selectedColor;
  List<String> _imageTags = [];

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

  static const List<String> _animalIdentityTags = [
    'Animal',
    'Cachorro',
    'Cão',
    'Gato',
    'Vertebrado',
    'Mamífero',
    'Pet',
  ];

  static const List<String> _relevantSearchTags = [
    'Coleira',
    'Pelo longo',
    'Pelo curto',
    'Porte pequeno',
    'Porte grande',
    'Brinquedo',
    'Gato',
    'Cachorro',
    'Orelhas caídas',
    'Orelhas pontudas',
    'Laço',
    'Arreio',
  ];

  static const List<String> _commonIgnoredTags = [
    'Animal',
    'Vertebrado',
    'Mamífero',
    'Natureza',
    'Ao ar livre',
    'Planta',
    'Árvore',
    'Gramado',
    'Rua',
    'Focinho',
    'Olho',
    'Fotografia',
    'Pet',
  ];

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
      } else {
        return ['Erro ao carregar raças'];
      }
    } catch (e) {
      return ['Erro de conexão'];
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    setState(() {
      _selectedImage = pickedFile != null ? File(pickedFile.path) : null;
      _imageTags = [];
    });
  }

  Future<bool> _isAnimalInImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());

    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );
      const double minConfidence = 0.80;

      for (final label in labels) {
        if (label.confidence >= minConfidence &&
            _animalIdentityTags.contains(label.label)) {
          imageLabeler.close();
          return true;
        }
      }
      imageLabeler.close();
      return false;
    } catch (_) {
      imageLabeler.close();
      return false;
    }
  }

  Future<List<String>> _processImageWithMLKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    final List<String> tags = [];
    const double minConfidence = 0.75;

    for (final label in labels) {
      if (label.confidence >= minConfidence &&
          _relevantSearchTags.contains(label.label) &&
          !_commonIgnoredTags.contains(label.label)) {
        tags.add(label.label);
      }
    }
    imageLabeler.close();
    return tags.toSet().toList();
  }

  Future<void> _searchAnimals() async {
    setState(() {
      _isLoading = true;
      _foundAnimals = [];
    });

    final isRaceSelected =
        _selectedRace != null && _selectedRace != 'Vira-Lata / SRD';
    final isColorSelected = _selectedColor != null;
    final isImageSelected = _selectedImage != null;

    if (!isRaceSelected && !isColorSelected && !isImageSelected) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha pelo menos um filtro.')),
      );
      return;
    }

    if (isImageSelected) {
      final isAnimal = await _isAnimalInImage(_selectedImage!);
      if (!isAnimal) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A imagem não parece conter um animal.'),
          ),
        );
        return;
      }
      _imageTags = await _processImageWithMLKit(_selectedImage!);
    }

    await _runStrictSearch(race: _selectedRace, color: _selectedColor);

    setState(() => _isLoading = false);
  }

  Future<void> _runStrictSearch({String? race, String? color}) async {
    try {
      Query query = _firestore.collection('animals');
      if (race != null && race != 'Vira-Lata / SRD') {
        query = query.where('raca', isEqualTo: race);
      }
      final querySnapshot = await query.get();
      List<DocumentSnapshot> results = querySnapshot.docs;

      if (color != null) {
        results = results
            .where(
              (doc) => (doc.data() as Map<String, dynamic>)['cor'] == color,
            )
            .toList();
      }

      setState(() {
        _foundAnimals = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao buscar animais.')));
    }
  }

  // ===== InputDecoration no mesmo estilo da LoginPage / Cadastro =====
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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Mesmo fundo da LoginPage e Cadastro de Animal
      backgroundColor: const Color(0xFFBBD0FF),
      body: SafeArea(
        child: Stack(
          children: [
            // ===== BOLHAS DECORATIVAS (mesmo padrão) =====
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho com patinha + título
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets_rounded,
                              size: 32, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Buscar Animal',
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
                        'Use filtros e/ou uma foto para localizar\nanimais cadastrados no sistema.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card principal branco translúcido
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
                            // Card interno de imagem
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _selectedImage == null
                                      ? Column(
                                          children: [
                                            Icon(
                                              Icons.image_outlined,
                                              size: 60,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Selecione uma imagem de um animal\npara buscar por semelhança (opcional).',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.black
                                                    .withOpacity(0.65),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.file(
                                            _selectedImage!,
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _pickImage,
                                      icon: const Icon(Icons.photo),
                                      label: const Text(
                                        'Selecionar imagem',
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

                            const SizedBox(height: 16),

                            // Filtro por cor
                            DropdownButtonFormField<String>(
                              decoration: _inputDecoration(
                                label: 'FILTRAR POR COR',
                                hint: 'Selecione a cor do animal',
                              ),
                              value: _selectedColor,
                              items: _animalColors
                                  .map(
                                    (color) => DropdownMenuItem(
                                      value: color,
                                      child: Text(color),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedColor = value),
                              icon:
                                  const Icon(Icons.arrow_drop_down_rounded),
                            ),
                            const SizedBox(height: 14),

                            // Filtro por raça
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
                              dropdownDecoratorProps:
                                  DropDownDecoratorProps(
                                dropdownSearchDecoration: _inputDecoration(
                                  label: 'FILTRAR POR RAÇA',
                                  hint: 'Digite para buscar a raça',
                                ),
                              ),
                              selectedItem: _selectedRace,
                              onChanged: (String? value) =>
                                  setState(() => _selectedRace = value),
                            ),

                            const SizedBox(height: 18),

                            // Botão de busca
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
                                onPressed: _isLoading ? null : _searchAnimals,
                                icon: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                                label: Text(
                                  _isLoading
                                      ? 'Buscando...'
                                      : 'Buscar animais',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Título resultados
                            Text(
                              'Resultados (${_foundAnimals.length})',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2B5B),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Lista de resultados
                            _foundAnimals.isEmpty && !_isLoading
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Nenhum animal encontrado.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _foundAnimals.length,
                                    itemBuilder: (context, index) {
                                      final animal =
                                          _foundAnimals[index].data()
                                              as Map<String, dynamic>;

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.all(10),
                                          leading: animal['foto_url'] != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    10,
                                                  ),
                                                  child: Image.network(
                                                    animal['foto_url'],
                                                    width: 56,
                                                    height: 56,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.pets,
                                                  size: 40,
                                                  color:
                                                      Color(0xFF1B2B5B),
                                                ),
                                          title: Text(
                                            animal['nome'] ?? 'Sem nome',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Raça: ${animal['raca'] ?? 'N/A'}\nCor: ${animal['cor'] ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black
                                                  .withOpacity(0.75),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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

  // ===== Bolha decorativa (mesmo padrão das outras telas) =====
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
