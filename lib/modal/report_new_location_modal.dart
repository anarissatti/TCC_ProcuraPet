import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

class ReportNewLocationModal extends StatefulWidget {
  final String animalId;
  const ReportNewLocationModal({required this.animalId, super.key});

  @override
  State<ReportNewLocationModal> createState() => _ReportNewLocationModalState();
}

class _ReportNewLocationModalState extends State<ReportNewLocationModal> {
  GoogleMapController? mapController;
  LatLng? _selectedPosition;
  geo.Placemark? _selectedAddress;
  bool _isProcessing = false;
  final _referenceController = TextEditingController();

  // Ponto de fallback (Brasília)
  static const LatLng _fallbackPosition = LatLng(-15.7801, -47.9292);

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  /// Converte LatLng para endereço legível (Geocoding Reverso)
  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isProcessing = true);

    try {
      final List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        // CORREÇÃO: Removendo o localeIdentifier para evitar erro de plataforma/ambiente.
        // O Geocoding usará o locale padrão do dispositivo.
        // localeIdentifier: 'pt_BR',
      );

      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          _selectedAddress = placemarks.first;
          _isProcessing = false;
        });
      } else if (mounted) {
        setState(() {
          _selectedAddress = null;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço não encontrado para esta coordenada.'),
          ),
        );
      }
    } catch (e) {
      print('Erro no Geocoding: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao obter endereço: $e')));
      }
    }
  }

  /// Lida com o clique no mapa: salva a posição e inicia o Geocoding
  void _onMapTap(LatLng position) {
    if (_isProcessing) return; // Impede cliques múltiplos

    setState(() {
      _selectedPosition = position;
      _selectedAddress = null; // Limpa o endereço anterior
    });

    // Anima a câmera para o ponto clicado
    mapController?.animateCamera(CameraUpdate.newLatLng(position));

    // Inicia a busca pelo endereço
    _getAddressFromLatLng(position);
  }

  /// Salva a nova localização e atualiza a "ultima_localizacao" do animal
  Future<void> _saveNewReport() async {
    if (_selectedPosition == null ||
        _selectedAddress == null ||
        _isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o ponto no mapa e aguarde o endereço.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonimo';
      final userName = user?.displayName ?? 'Usuário Anônimo';

      final reportData = {
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        // Usamos street/thoroughfare para ser mais genérico, já que o idioma pode variar
        'rua':
            _selectedAddress!.street ?? _selectedAddress!.thoroughfare ?? 'N/A',
        'bairro': _selectedAddress!.subLocality ?? 'N/A',
        'cidade': _selectedAddress!.locality ?? 'N/A',
        'estado': _selectedAddress!.administrativeArea ?? 'N/A',
        'referencia': _referenceController.text.trim(),
        'dataRegistro': FieldValue.serverTimestamp(),
        'usuarioQueReportouId': userId,
        'usuarioQueReportou': userName,
      };

      final animalRef = FirebaseFirestore.instance
          .collection('animals')
          .doc(widget.animalId);

      // 1. Salva na subcoleção: animais/{idAnimal}/localizacoes
      await animalRef.collection('localizacoes').add(reportData);

      // 2. Atualiza o documento principal (ultima_localizacao)
      // Como este é um novo reporte, ele é o mais recente.
      await animalRef.update({
        'latitudeUltimaVisao': reportData['latitude'],
        'longitudeUltimaVisao': reportData['longitude'],
        'ruaUltimaVisao': reportData['rua'],
        'bairroUltimaVisao': reportData['bairro'],
        'cidadeUltimaVisao': reportData['cidade'],
        'estadoUltimaVisao': reportData['estado'],
        'ultima_localizacao_timestamp': reportData['dataRegistro'],
        // Campos para a tela principal (facilitando o carregamento inicial)
        'ultima_localizacao': {
          'latitude': reportData['latitude'],
          'longitude': reportData['longitude'],
          'rua': reportData['rua'],
          'bairro': reportData['bairro'],
          'cidade': reportData['cidade'],
          'estado': reportData['estado'],
          'timestamp': reportData['dataRegistro'],
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Localização reportada com sucesso!')),
        );
        Navigator.pop(context); // Fecha o modal
      }
    } catch (e, st) {
      print('Erro ao salvar reporte: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao salvar o reporte. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcula a altura da tela para o Modal (85% da altura total)
    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Informe Onde Você Viu o Animal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

          // MAPA INTERATIVO
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: const CameraPosition(
                target: _fallbackPosition,
                zoom: 5,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: {
                if (_selectedPosition != null)
                  Marker(
                    markerId: const MarkerId('report_point'),
                    position: _selectedPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: const InfoWindow(title: 'Local de Reporte'),
                  ),
              },
              onTap: _onMapTap,
            ),
          ),

          // FORMULÁRIO DE ENDEREÇO
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Toque no mapa para selecionar o local.'),
                  const SizedBox(height: 10),

                  // Detalhes do Endereço
                  if (_isProcessing)
                    const LinearProgressIndicator()
                  else if (_selectedAddress != null)
                    _buildAddressDetails()
                  else
                    const Text(
                      'Aguardando a seleção do ponto no mapa...',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),

                  const SizedBox(height: 15),

                  // Ponto de Referência Opcional
                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Ponto de referência (Opcional)',
                      hintText: 'Ex: Próximo à padaria, no final da rua',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Botão de Salvar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isProcessing
                            ? 'Processando...'
                            : 'Confirmar e Salvar Localização',
                      ),
                      onPressed: _isProcessing ? null : _saveNewReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para exibir os detalhes do endereço
  Widget _buildAddressDetails() {
    final address = _selectedAddress!;
    final street = address.thoroughfare ?? address.street ?? 'Rua Desconhecida';
    final district = address.subLocality ?? 'Bairro Desconhecido';
    final city = address.locality ?? 'Cidade Desconhecida';
    final state = address.administrativeArea ?? 'Estado Desconhecido';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Endereço Confirmado:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('Rua: $street'),
        Text('Bairro: $district'),
        Text('Cidade/Estado: $city/$state'),
        const SizedBox(height: 5),
        Text(
          'Lat/Lng: ${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
