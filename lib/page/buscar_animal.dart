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

  // Variáveis de Filtro
  String? _selectedRace;
  String? _selectedColor;
  List<String> _imageTags = []; // Tags geradas pelo ML Kit da foto de busca

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

  // TAGS DE IDENTIFICAÇÃO BÁSICA (USADAS APENAS PARA VALIDAR SE HÁ UM ANIMAL NA FOTO)
  static const List<String> _animalIdentityTags = [
    'Animal',
    'Cachorro',
    'Cão',
    'Gato',
    'Vertebrado',
    'Mamífero',
    'Pet',
  ];

  // TAGS RELEVANTES PARA BUSCA (Mantidas do exemplo anterior)
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

  // --- Funções Auxiliares ---

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
      if (pickedFile != null) {
        _selectedImage = File(pickedFile.path);
        _imageTags = [];
      } else {
        _selectedImage = null;
      }
    });
  }

  /// Verifica se a imagem contém alguma das tags básicas de identificação animal.
  Future<bool> _isAnimalInImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());

    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      // Se qualquer tag de identificação for encontrada com alta confiança (0.80), é um animal.
      const double minConfidenceForIdentity = 0.80;

      for (final label in labels) {
        if (label.confidence >= minConfidenceForIdentity &&
            _animalIdentityTags.contains(label.label)) {
          imageLabeler.close();
          return true;
        }
      }
      imageLabeler.close();
      return false;
    } catch (e) {
      print('Erro na validação de animal: $e');
      imageLabeler.close();
      return false; // Falha na leitura, assume que não é animal.
    }
  }

  Future<List<String>> _processImageWithMLKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    final List<String> tags = [];
    const double minConfidence = 0.75;

    for (final label in labels) {
      final labelText = label.label;
      final isRelevant =
          _relevantSearchTags.contains(labelText) &&
          !_commonIgnoredTags.contains(labelText);

      if (label.confidence >= minConfidence && isRelevant) {
        tags.add(labelText);
      }
    }
    imageLabeler.close();
    return tags.toSet().toList(); // Retorna tags únicas e relevantes
  }

  // --- Função Principal de Busca em Camadas ---

  Future<void> _searchAnimals() async {
    setState(() {
      _isLoading = true;
      _foundAnimals = [];
      _imageTags = [];
    });

    final isRaceSelected =
        _selectedRace != null && _selectedRace != 'Vira-Lata / SRD';
    final isColorSelected = _selectedColor != null;
    final isImageSelected = _selectedImage != null;

    // 0. VALIDAÇÃO INICIAL
    if (!isRaceSelected && !isColorSelected && !isImageSelected) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha pelo menos um filtro (Raça, Cor ou Imagem).',
          ),
        ),
      );
      return;
    }

    // NOVA VALIDAÇÃO DE IMAGEM
    if (isImageSelected) {
      final isAnimal = await _isAnimalInImage(_selectedImage!);
      if (!isAnimal) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não localizado animal na foto. Pesquisa abortada.'),
          ),
        );
        return; // Interrompe a pesquisa
      }

      // Se for animal, processa as tags detalhadas para a busca
      _imageTags = await _processImageWithMLKit(_selectedImage!);
      print("Tags detalhadas geradas: $_imageTags");
    }

    // 1. PRIMEIRA BUSCA: CORTE TOTAL (Raça E Cor)
    if (isRaceSelected && isColorSelected) {
      await _runStrictSearch(
        race: _selectedRace,
        color: _selectedColor,
        failMessage:
            'Animal não encontrado com os filtros Raça e Cor selecionados. Buscando por prioridades...',
      );
      if (_foundAnimals.isNotEmpty) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. BUSCA EM CAMADAS (Prioridades)

    // 2.1. Prioridade 1: Apenas Raça (Se a Raça foi informada)
    if (isRaceSelected) {
      await _runStrictSearch(
        race: _selectedRace,
        failMessage:
            'Animal não encontrado apenas com a Raça: $_selectedRace. Buscando por Semelhança de Cor/Tags...',
      );
      if (_foundAnimals.isNotEmpty) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2.2. Prioridade 2: Apenas Cor (Se a Cor foi informada)
    if (isColorSelected) {
      await _runStrictSearch(
        color: _selectedColor,
        failMessage:
            'Animal não encontrado apenas com a Cor: $_selectedColor. Buscando por Semelhança de Tags...',
      );
      if (_foundAnimals.isNotEmpty) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2.3. Prioridade 3: Apenas Tags (Se a Imagem foi informada e passou na validação)
    if (isImageSelected && _imageTags.isNotEmpty) {
      await _runTagSearch(
        tags: _imageTags,
        failMessage: 'Nenhum animal encontrado com as Tags geradas.',
      );
      if (_foundAnimals.isNotEmpty) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // 3. RESULTADO FINAL: NENHUM ANIMAL ENCONTRADO
    if (_foundAnimals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum animal foi encontrado com os critérios de busca.',
          ),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // --- Funções de Execução da Busca (Modularizada) ---

  Future<void> _runStrictSearch({
    String? race,
    String? color,
    List<String>? tags,
    required String failMessage,
  }) async {
    try {
      Query query = _firestore.collection('animals');

      // Aplica o filtro de Raça no Firestore (Se for SRD, não filtra a raça)
      if (race != null && race != 'Vira-Lata / SRD') {
        query = query.where('raca', isEqualTo: race);
      }

      // Se tiver tags, tenta o arrayContainsAny (opcional, apenas para o filtro Tags)
      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }

      final querySnapshot = await query.get();
      List<DocumentSnapshot> results = querySnapshot.docs;

      // Filtro de Cor (sempre em memória para flexibilidade)
      if (color != null) {
        results = results.where((doc) {
          final animal = doc.data() as Map<String, dynamic>;
          return animal['cor'] == color;
        }).toList();
      }

      if (results.isNotEmpty) {
        // Encontrou o animal, armazena o resultado e retorna
        _foundAnimals = results;
      } else {
        // Se a busca estrita falhou, mostra a mensagem de falha
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failMessage)));
      }
    } catch (e, st) {
      print('ERRO NA BUSCA ESTRITA ($race, $color): $e');
      print('STACK TRACE: $st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao executar a busca estrita. Verifique o console.',
          ),
        ),
      );
    }
  }

  // Função dedicada para buscar apenas por tags
  Future<void> _runTagSearch({
    required List<String> tags,
    required String failMessage,
  }) async {
    if (tags.isEmpty) return;

    try {
      Query query = _firestore.collection('animals');
      query = query.where('tags', arrayContainsAny: tags);

      final querySnapshot = await query.get();

      if (querySnapshot.docs.isNotEmpty) {
        _foundAnimals = querySnapshot.docs;
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failMessage)));
      }
    } catch (e, st) {
      print('ERRO NA BUSCA POR TAGS: $e');
      print('STACK TRACE: $st');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao executar a busca por tags.')),
      );
    }
  }

  // --- Widget Build (Interface) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encontre Animais Semelhantes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Imagem e Botão
            _selectedImage == null
                ? const Text(
                    'Selecione uma imagem de um animal para buscar por semelhança.',
                    textAlign: TextAlign.center,
                  )
                : Image.file(_selectedImage!, height: 200),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Selecionar Imagem'),
            ),
            const SizedBox(height: 20),

            // Filtro: Cor
            DropdownButtonFormField<String>(
              value: _selectedColor,
              decoration: const InputDecoration(labelText: 'Filtrar por Cor'),
              hint: const Text('Opcional: selecione a cor principal'),
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

            // Filtro: Raça
            DropdownSearch<String>(
              asyncItems: _fetchDogBreeds,
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                showSelectedItems: true,
              ),
              selectedItem: _selectedRace,
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Filtrar por Raça',
                  hintText: 'Opcional: selecione a raça',
                ),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRace = newValue;
                });
              },
            ),
            const SizedBox(height: 20),

            // Botão de Busca
            ElevatedButton(
              onPressed: _searchAnimals,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Buscar Animais Semelhantes'),
            ),
            const SizedBox(height: 20),

            // Resultados
            Text(
              'Resultados da Busca (${_foundAnimals.length} encontrados):',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            _foundAnimals.isEmpty && !_isLoading
                ? const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Nenhum animal encontrado com os filtros aplicados.',
                      textAlign: TextAlign.center,
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
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: animal['foto_url'] != null
                              ? Image.network(
                                  animal['foto_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.pets),
                          title: Text(animal['nome'] ?? 'Sem Nome'),
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
