// lib/page/buscar_animal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';

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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: const Text('Buscar Animal'),
        centerTitle: true,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _selectedImage == null
                        ? Column(
                            children: [
                              const Icon(
                                Icons.image_outlined,
                                size: 60,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Selecione uma imagem de um animal\npara buscar por semelhança',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _selectedImage!,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo),
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      label: const Text('Selecionar Imagem'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Filtrar por Cor',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.color_lens, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              value: _selectedColor,
              items: _animalColors
                  .map(
                    (color) =>
                        DropdownMenuItem(value: color, child: Text(color)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedColor = value),
            ),
            const SizedBox(height: 15),

            DropdownSearch<String>(
              asyncItems: _fetchDogBreeds,
              popupProps: const PopupProps.menu(showSearchBox: true),
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Filtrar por Raça',
                  prefixIcon: const Icon(Icons.pets, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                ),
              ),
              onChanged: (String? value) =>
                  setState(() => _selectedRace = value),
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _searchAnimals,
              icon: const Icon(Icons.search),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Buscar Animais'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 25),

            Text(
              'Resultados (${_foundAnimals.length})',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 10),

            _foundAnimals.isEmpty && !_isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Nenhum animal encontrado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _foundAnimals.length,
                    itemBuilder: (context, index) {
                      final animal =
                          _foundAnimals[index].data() as Map<String, dynamic>;

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: animal['foto_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    animal['foto_url'],
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.pets,
                                  size: 50,
                                  color: Colors.blueAccent,
                                ),
                          title: Text(animal['nome'] ?? 'Sem nome'),
                          subtitle: Text(
                            'Raça: ${animal['raca'] ?? 'N/A'}\nCor: ${animal['cor'] ?? 'N/A'}',
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
