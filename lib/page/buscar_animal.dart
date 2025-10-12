import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

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
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selecione uma imagem primeiro.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _foundAnimals = []; // Limpa resultados anteriores
    });

    try {
      final List<String> tags = await _processImageWithMLKit(_selectedImage!);
      if (tags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nenhuma tag relevante encontrada na imagem.'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _currentPosition = await _getCurrentLocation();
      print("Tags da imagem: $tags");
      print(
        "Localização do usuário: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}",
      );

      Query query = _firestore
          .collection('animals')
          .where('tags', arrayContainsAny: tags);

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
              // Título
              const Text(
                'Página de Busca de Animais',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Espaço para a imagem selecionada
              _selectedImage == null
                  ? const Text(
                      'Nenhuma imagem selecionada.',
                      textAlign: TextAlign.center,
                    )
                  : Image.file(_selectedImage!, height: 200),
              const SizedBox(height: 20),
              // Botão para selecionar imagem
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Selecionar Imagem'),
              ),
              const SizedBox(height: 10),
              // Botão para buscar
              ElevatedButton(
                onPressed: _searchAnimals,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Buscar Animais Semelhantes'),
              ),
              const SizedBox(height: 20),
              // Título dos resultados
              Text(
                'Resultados da Busca:',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              // Exibição dos resultados
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
