import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Modal para reportar nova localização
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
  LatLng _initialCameraPosition =
      const LatLng(-15.7801, -47.9292); // Brasília
  bool _isLoading = true;

  // Fluxo de seleção de ponto para reporte
  bool _isSelectingLocation = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      _loadAnimalData();
    });
  }

  /// Mensagem bonitinha no centro da tela
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
                  child: const Text('Ok, entendi'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Carrega os dados principais do animal e as localizações
  Future<void> _loadAnimalData() async {
    try {
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
              lastLocation.containsKey('latitude') &&
              lastLocation.containsKey('longitude')) {
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

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        // 2. Carrega todas as localizações reportadas (Subcoleção)
        _loadAllReports();
      });
    } catch (e) {
      debugPrint('Erro ao carregar dados do animal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar dados do animal.')),
        );
        setState(() => _isLoading = false);
      }
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
                timestamp.toDate().isAtSameMomentAs(
                      lastSeenTimestamp.toDate(),
                    );

        final double markerHue = isLastSeen
            ? BitmapDescriptor.hueGreen // Última visão: Verde
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

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCameraPosition, 14),
    );
  }

  /// Quando o usuário clica no botão "Você viu este animal?"
  void _startSelectingLocation() {
    setState(() {
      _isSelectingLocation = true;
    });

    _showCenteredMessage(
      title: 'Selecione no mapa',
      message: 'Toque no mapa para marcar onde você viu o animal.',
      icon: Icons.touch_app_rounded,
    );
  }

  /// Quando o usuário toca no mapa
  void _onMapTap(LatLng position) {
    if (!_isSelectingLocation) {
      // Se não estiver em modo de seleção, não faz nada especial
      return;
    }

    setState(() {
      _isSelectingLocation = false;
    });

    // Abre o modal já com a posição escolhida
    _openReportModal(context, position);
  }

  /// Abre o modal para o usuário reportar uma nova localização com base no ponto clicado
  void _openReportModal(BuildContext context, LatLng position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportNewLocationModal(
        animalId: widget.animalId,
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxContentWidth =
                        constraints.maxWidth > 900
                            ? 900
                            : constraints.maxWidth;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // HEADER (mesmo estilo das outras telas)
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF1B2B5B),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.location_pin,
                                  size: 28,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Localização de ${widget.animalName}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1B2B5B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // MAPA + OVERLAY (responsivo)
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Stack(
                                        children: [
                                          GoogleMap(
                                            onMapCreated: _onMapCreated,
                                            initialCameraPosition:
                                                CameraPosition(
                                              target: _initialCameraPosition,
                                              zoom: 14,
                                            ),
                                            myLocationEnabled: true,
                                            myLocationButtonEnabled: true,
                                            markers: _markers,
                                            onTap: _onMapTap,
                                          ),

                                          // LEGENDA + BOTÃO (flutuando sobre o mapa)
                                          Positioned(
                                            bottom: 16,
                                            left: 16,
                                            right: 16,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white70,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        blurRadius: 5,
                                                        color: Colors.black26,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceAround,
                                                    children: [
                                                      MarkerLegend(
                                                        color: Colors.green,
                                                        label: 'Última Vista',
                                                      ),
                                                      MarkerLegend(
                                                        color: Colors.amber,
                                                        label: 'Visto',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons.pin_drop),
                                                  label: Text(
                                                    _isSelectingLocation
                                                        ? 'Toque no mapa para marcar...'
                                                        : 'Você viu este animal? Clique aqui para informar onde.',
                                                  ),
                                                  onPressed: _isSelectingLocation
                                                      ? null
                                                      : _startSelectingLocation,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        cs.primary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 14,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    textStyle:
                                                        const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bolhas decorativas
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
