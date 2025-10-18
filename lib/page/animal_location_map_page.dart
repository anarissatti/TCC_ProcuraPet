import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
// CORREÇÃO: Certifique-se de que o caminho do import está correto
import '../modal/report_new_location_modal.dart';

class AnimalLocationMapPage extends StatefulWidget {
  final String animalId;
  final String animalName;

  const AnimalLocationMapPage({
    required this.animalId,
    required this.animalName,
    super.key,
  });

  @override
  State<AnimalLocationMapPage> createState() => _AnimalLocationMapPageState();
}

class _AnimalLocationMapPageState extends State<AnimalLocationMapPage> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};

  // A posição inicial será a última localização do animal ou um fallback
  LatLng _initialCameraPosition = const LatLng(-15.7801, -47.9292); // Brasília
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      _loadAnimalData();
    });
  }

  /// Carrega os dados principais do animal e as localizações
  Future<void> _loadAnimalData() async {
    try {
      // 1. Ouve as alterações no documento principal do animal
      FirebaseFirestore.instance
          .collection('animals')
          .doc(widget.animalId)
          .snapshots()
          .listen((docSnapshot) {
            if (docSnapshot.exists) {
              final data = docSnapshot.data()!;
              final lastLocation =
                  data['ultima_localizacao'] as Map<String, dynamic>?;

              if (lastLocation != null &&
                  lastLocation.containsKey('latitude')) {
                // NOTE: A conversão para double é essencial para o LatLng
                final lat = (lastLocation['latitude'] as num).toDouble();
                final lng = (lastLocation['longitude'] as num).toDouble();
                _initialCameraPosition = LatLng(lat, lng);

                // Se for a primeira carga, centraliza a câmera
                if (_isLoading && mapController != null) {
                  mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_initialCameraPosition, 14),
                  );
                }
              }
            }
            // Se a posição da câmera não foi atualizada, garante que ela use o fallback
            setState(() {
              _isLoading = false;
            });

            // 2. Carrega todas as localizações reportadas (Subcoleção)
            _loadAllReports();
          });
    } catch (e) {
      print('Erro ao carregar dados do animal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar dados do animal.')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// Carrega todos os pontos de localização reportados (markers)
  void _loadAllReports() {
    FirebaseFirestore.instance
        .collection('animals')
        .doc(widget.animalId)
        .collection('localizacoes')
        .orderBy('dataRegistro', descending: true)
        .snapshots()
        .listen((snapshot) {
          final newMarkers = <Marker>{};
          Timestamp? lastSeenTimestamp;

          // 1. Encontra o ponto mais recente
          if (snapshot.docs.isNotEmpty) {
            lastSeenTimestamp =
                snapshot.docs.first['dataRegistro'] as Timestamp?;
          }

          // 2. Cria os marcadores
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lat = (data['latitude'] as num).toDouble();
            final lng = (data['longitude'] as num).toDouble();
            final position = LatLng(lat, lng);
            final timestamp = data['dataRegistro'] as Timestamp;

            final formattedDate = DateFormat(
              "dd/MM/yyyy HH:mm",
              'pt_BR',
            ).format(timestamp.toDate().toLocal());

            final userReported = data['usuarioQueReportou'] ?? 'Desconhecido';
            final reference =
                data['referencia'] ?? 'Nenhuma referência adicional.';
            final address =
                '${data['rua']}, ${data['bairro']} - ${data['cidade']}/${data['estado']}';

            // Define a cor do marcador (Verde para o mais recente, Amarelo para os outros)
            final bool isLastSeen =
                lastSeenTimestamp != null &&
                timestamp.toDate().isAtSameMomentAs(lastSeenTimestamp.toDate());

            final double markerHue = isLastSeen
                ? BitmapDescriptor
                      .hueGreen // Última visão: Verde
                : BitmapDescriptor.hueYellow; // Visto: Amarelo

            newMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                infoWindow: InfoWindow(
                  title: isLastSeen
                      ? 'Última Localização (Verde)'
                      : 'Animal Visto (Amarelo)',
                  snippet:
                      'Endereço: $address | Ref: $reference | Reportado em: $formattedDate por $userReported',
                ),
              ),
            );
          }

          setState(() {
            _markers = newMarkers;
          });
        });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Centraliza a câmera na posição inicial
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCameraPosition, 14),
    );
  }

  /// Abre o modal para o usuário reportar uma nova localização
  void _openReportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportNewLocationModal(
        // CORREÇÃO: O construtor é chamado corretamente
        animalId: widget.animalId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Localização de ${widget.animalName}'),
        backgroundColor: Colors.green,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _initialCameraPosition,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _markers,
                  // Permite o clique no mapa, mas não para selecionar a localização nesta página
                  onTap: (pos) {
                    print('Clique em: $pos. Use o botão para reportar.');
                  },
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(blurRadius: 5, color: Colors.black26),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            MarkerLegend(
                              color: Colors.green,
                              label: 'Última Vista',
                            ),
                            MarkerLegend(color: Colors.amber, label: 'Visto'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.pin_drop),
                        label: const Text(
                          'Você viu este animal? Clique aqui para informar onde.',
                        ),
                        onPressed: () => _openReportModal(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Widget auxiliar para a legenda do mapa
class MarkerLegend extends StatelessWidget {
  final Color color;
  final String label;

  const MarkerLegend({required this.color, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
