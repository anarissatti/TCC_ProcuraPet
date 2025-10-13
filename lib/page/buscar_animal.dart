// lib/page/buscar_animal.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';

class BuscarAnimalPage extends StatefulWidget {
  @override
  _BuscarAnimalPageState createState() => _BuscarAnimalPageState();
}

class _BuscarAnimalPageState extends State<BuscarAnimalPage> {
  File? _selectedImage;
  Position? _currentPosition;
  final _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _foundAnimals = [];
  bool _isLoading = false;
  String? _selectedRace;

  // Função para buscar a lista de raças da API.
  // Agora, ela aceita o parâmetro 'filter' que a DropdownSearch passa.
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

        // Adiciona um filtro manual (opcional) se a API não suportar
        if (filter != null && filter.isNotEmpty) {
          return allBreeds
              .where(
                (breed) => breed.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList();
        }
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

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    setState(() {
      if (pickedFile != null) {
        _selectedImage = File(pickedFile.path);
      } else {
        _selectedImage = null;
        print('Nenhuma imagem selecionada.');
      }
    });
  }

  Future<List<String>> _processImageWithMLKit(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    final List<String> tags = [];

    for (final label in labels) {
      if (label.confidence > 0.70) {
        tags.add(label.label);
      }
    }
    imageLabeler.close();
    return tags;
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviço de localização desabilitado.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissão de localização negada.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissão de localização negada para sempre.');
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _searchAnimals() async {
    if (_selectedImage == null && _selectedRace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma imagem ou raça para buscar.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _foundAnimals = [];
    });

    try {
      final List<String> tags = _selectedImage != null
          ? await _processImageWithMLKit(_selectedImage!)
          : [];

      _currentPosition = await _getCurrentLocation();
      print("Tags da imagem: $tags");
      print(
        "Localização do usuário: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}",
      );

      Query query = _firestore.collection('animals');

      if (_selectedRace != null && _selectedRace != 'Vira-Lata / SRD') {
        query = query.where('raca', isEqualTo: _selectedRace);
      }

      if (tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }

      final querySnapshot = await query.get();

      setState(() {
        _foundAnimals = querySnapshot.docs;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro na busca: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encontre Animais Semelhantes')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Página de Busca de Animais',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _selectedImage == null
                  ? const Text(
                      'Nenhuma imagem selecionada.',
                      textAlign: TextAlign.center,
                    )
                  : Image.file(_selectedImage!, height: 200),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Selecionar Imagem'),
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
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _searchAnimals,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Buscar Animais Semelhantes'),
              ),
              const SizedBox(height: 20),
              Text(
                'Resultados da Busca:',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              _foundAnimals.isEmpty && !_isLoading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        'Nenhum animal encontrado.',
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
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.pets),
                            title: Text(animal['nome'] ?? 'Sem Nome'),
                            subtitle: Text('Raça: ${animal['raca'] ?? 'N/A'}'),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
