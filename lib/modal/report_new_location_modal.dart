import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:firebase_auth/firebase_auth.dart';

class ReportNewLocationModal extends StatefulWidget {
  final String animalId;
  final double latitude;
  final double longitude;

  const ReportNewLocationModal({
    required this.animalId,
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<ReportNewLocationModal> createState() => _ReportNewLocationModalState();
}

class _ReportNewLocationModalState extends State<ReportNewLocationModal> {
  GoogleMapController? mapController;
  LatLng? _selectedPosition;
  geo.Placemark? _selectedAddress;
  bool _isProcessing = false;
  final _referenceController = TextEditingController();

  // Fallback só por segurança
  static const LatLng _fallbackPosition = LatLng(-15.7801, -47.9292);

  @override
  void initState() {
    super.initState();
    // Já começa com o ponto que veio da tela do mapa
    _selectedPosition = LatLng(widget.latitude, widget.longitude);
    _getAddressFromLatLng(_selectedPosition!);
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  /// Mensagem bonitinha centralizada
  Future<void> _showCenteredMessage({
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    Color iconColor = const Color(0xFF1A237E),
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Ok'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Geocoding reverso: LatLng -> endereço
  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _isProcessing = true);

    try {
      // 👇 Ajuste aqui: função correta é placemarkFromCoordinates (singular)
      final List<geo.Placemark> placemarks =
          await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        setState(() {
          _selectedAddress = placemarks.first;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _selectedAddress = null;
          _isProcessing = false;
        });
        await _showCenteredMessage(
          title: 'Endereço não encontrado',
          message: 'Não foi possível identificar o endereço deste ponto.',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } catch (e) {
      print('Erro no Geocoding: $e');
      if (!mounted) return;
      setState(() => _isProcessing = false);
      await _showCenteredMessage(
        title: 'Erro ao obter endereço',
        message: 'Ocorreu um erro ao buscar o endereço. Tente novamente.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  /// Salva a nova localização e atualiza a "ultima_localizacao" do animal
  Future<void> _saveNewReport() async {
    if (_selectedPosition == null || _selectedAddress == null) {
      await _showCenteredMessage(
        title: 'Selecione um ponto válido',
        message:
            'Não foi possível confirmar o endereço. Verifique o mapa e tente novamente.',
        icon: Icons.info_outline,
      );
      return;
    }

    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonimo';
      final userName = user?.displayName ?? 'Usuário Anônimo';

      final address = _selectedAddress!;
      final street = address.street ?? address.thoroughfare ?? 'N/A';
      final district = address.subLocality ?? 'N/A';
      final city = address.locality ?? 'N/A';
      final state = address.administrativeArea ?? 'N/A';

      final reportData = {
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        'rua': street,
        'bairro': district,
        'cidade': city,
        'estado': state,
        'referencia': _referenceController.text.trim(),
        'dataRegistro': FieldValue.serverTimestamp(),
        'usuarioQueReportouId': userId,
        'usuarioQueReportou': userName,
      };

      final animalRef =
          FirebaseFirestore.instance.collection('animals').doc(widget.animalId);

      // 1. Salva na subcoleção de localizações
      await animalRef.collection('localizacoes').add(reportData);

      // 2. Atualiza campos de última localização no doc principal
     await animalRef.update({
  'latitudeUltimaVisao': reportData['latitude'],
  'longitudeUltimaVisao': reportData['longitude'],
  'ruaUltimaVisao': reportData['rua'],
  'bairroUltimaVisao': reportData['bairro'],
  'cidadeUltimaVisao': reportData['cidade'],
  'estadoUltimaVisao': reportData['estado'],
  'ultima_localizacao_timestamp': reportData['dataRegistro'],
  'ultima_localizacao': {
    'latitude': reportData['latitude'],
    'longitude': reportData['longitude'],
    'rua': reportData['rua'],
    'bairro': reportData['bairro'],
    'cidade': reportData['cidade'],
    'estado': reportData['estado'],
    // 👇 aqui é o nome que o card espera
    'data_hora': reportData['dataRegistro'],
    // opcional: mantém o antigo se já existir dado assim no banco
    'timestamp': reportData['dataRegistro'],
  },
});


      if (!mounted) return;

      await _showCenteredMessage(
        title: 'Localização salva!',
        message:
            'Obrigado por informar onde você viu o animal. Isso ajuda muito nas chances de reencontro ❤️',
        icon: Icons.check_circle_outline,
        iconColor: Colors.green,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Fecha o modal
      }
    } catch (e, st) {
      print('Erro ao salvar reporte: $e\n$st');
      if (!mounted) return;
      await _showCenteredMessage(
        title: 'Erro ao salvar',
        message: 'Não foi possível salvar o reporte. Tente novamente.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double screenHeight = media.size.height;
    final bool isTablet = media.size.shortestSide >= 600;

    // Em celular usa 85%, em tablet usa 75% da altura da tela
    final double modalHeightFactor = isTablet ? 0.75 : 0.85;

    return SafeArea(
      top: false,
      child: Container(
        height: screenHeight * modalHeightFactor,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TÍTULO
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Informe Onde Você Viu o Animal',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // MAPA (apenas para visualizar o ponto escolhido)
            Expanded(
              child: GoogleMap(
                onMapCreated: (controller) {
                  mapController = controller;
                  if (_selectedPosition != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedPosition!, 16),
                    );
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: _selectedPosition ?? _fallbackPosition,
                  zoom: _selectedPosition != null ? 16 : 5,
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
              ),
            ),

            // FORMULÁRIO + BOTÃO
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confira o local no mapa acima e preencha as informações abaixo.',
                    ),
                    const SizedBox(height: 10),

                    if (_isProcessing)
                      const LinearProgressIndicator()
                    else if (_selectedAddress != null)
                      _buildAddressDetails()
                    else
                      const Text(
                        'Carregando endereço do ponto selecionado...',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),

                    const SizedBox(height: 15),

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
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Detalhes do endereço
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
        if (_selectedPosition != null) ...[
          const SizedBox(height: 5),
          Text(
            'Lat/Lng: ${_selectedPosition!.latitude.toStringAsFixed(6)}, '
            '${_selectedPosition!.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}
