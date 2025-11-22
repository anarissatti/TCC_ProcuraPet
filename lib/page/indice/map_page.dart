import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tcc_procurapet/page/indice/dados_animal.dart';
import 'dados_animal.dart';

class LostAnimalsMapPage extends StatefulWidget {
  const LostAnimalsMapPage({super.key});

  @override
  State<LostAnimalsMapPage> createState() => _LostAnimalsMapPageState();
}

class _LostAnimalsMapPageState extends State<LostAnimalsMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Posição inicial (Brasil)
  LatLng _initialCameraPosition =
      const LatLng(-15.7801, -47.9292); // Brasília

  @override
  void initState() {
    super.initState();
    _listenAnimals();
  }

  /// Escuta em tempo real todos os animais com última localização
  void _listenAnimals() {
    FirebaseFirestore.instance
        .collection('animals')
        .snapshots()
        .listen((snapshot) {
      final newMarkers = <Marker>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final String rawStatus =
            (data['status'] ?? '').toString().toUpperCase();

        // Só queremos DESAPARECIDO e ENCONTRADO
        if (rawStatus != 'DESAPARECIDO' && rawStatus != 'ENCONTRADO') {
          continue;
        }

        // Tenta pegar ultima_localizacao (novo formato)
        final Map<String, dynamic>? ultimaLocalizacao =
            data['ultima_localizacao'] as Map<String, dynamic>?;

        double? lat;
        double? lng;

        if (ultimaLocalizacao != null &&
            ultimaLocalizacao['latitude'] != null &&
            ultimaLocalizacao['longitude'] != null) {
          lat = (ultimaLocalizacao['latitude'] as num).toDouble();
          lng = (ultimaLocalizacao['longitude'] as num).toDouble();
        } else if (data['latitudeUltimaVisao'] != null &&
            data['longitudeUltimaVisao'] != null) {
          // Fallback pro formato antigo
          lat = (data['latitudeUltimaVisao'] as num).toDouble();
          lng = (data['longitudeUltimaVisao'] as num).toDouble();
        }

        if (lat == null || lng == null) {
          // Sem coordenadas, pula
          continue;
        }

        final position = LatLng(lat, lng);
        final String nome = data['nome'] ?? 'Animal sem nome';
        final String raca = data['raca'] ?? 'Raça não informada';
        final String cidade =
            ultimaLocalizacao?['cidade'] ?? data['cidadeUltimaVisao'] ?? '';
        final String estado =
            ultimaLocalizacao?['estado'] ?? data['estadoUltimaVisao'] ?? '';

        final bool isDesaparecido = rawStatus == 'DESAPARECIDO';
        final double markerHue = isDesaparecido
            ? BitmapDescriptor.hueRed    // 🔴 Desaparecido
            : BitmapDescriptor.hueBlue;  // 🔵 Encontrado

        final String statusFormatado =
            isDesaparecido ? 'Desaparecido' : 'Encontrado';

        // Prepara os dados pra mandar pra tela de detalhes
        final String docId = doc.id;
        final Map<String, dynamic> animalData =
            Map<String, dynamic>.from(data);

        // Garante que ultima_localizacao exista na tela de detalhes
        if (ultimaLocalizacao != null) {
          animalData['ultima_localizacao'] = ultimaLocalizacao;
        } else {
          animalData['ultima_localizacao'] = {
            'latitude': lat,
            'longitude': lng,
            'cidade': cidade,
            'estado': estado,
          };
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(docId),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
            infoWindow: InfoWindow(
              title: nome,
              snippet: [
                if (raca.isNotEmpty) 'Raça: $raca',
                if (cidade.isNotEmpty || estado.isNotEmpty)
                  'Local: $cidade ${estado.isNotEmpty ? '/$estado' : ''}',
                'Status: $statusFormatado',
              ].where((s) => s.trim().isNotEmpty).join(' • '),
              onTap: () {
                // Ao tocar na InfoWindow, abre a tela de detalhes do animal
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AnimalDetailsPage(
                      animalId: docId,
                      animalData: animalData,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _markers = newMarkers;
        _isLoading = false;
      });

      // Se o mapa já estiver pronto e houver ao menos um marcador, centraliza no primeiro
      if (_mapController != null && newMarkers.isNotEmpty) {
        final firstPos = newMarkers.first.position;
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(firstPos, 11),
        );
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCameraPosition, 5.5),
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
            // ===== BOLHAS DECORATIVAS (mesmo estilo das outras telas) =====
            Positioned(top: -40, right: -30, child: _bubble(130, opacity: .20)),
            Positioned(top: 40, right: 24, child: _bubble(70, opacity: .25)),
            Positioned(top: 90, left: 20, child: _bubble(58, opacity: .18)),
            Positioned(top: 140, left: -24, child: _bubble(96, opacity: .22)),

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
                            // HEADER
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color: const Color(0xFF1B2B5B),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.map_rounded,
                                  size: 28,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Mapa de Animais',
                                    style: TextStyle(
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

                            // MAPA
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : Stack(
                                        children: [
                                          GoogleMap(
                                            onMapCreated: _onMapCreated,
                                            initialCameraPosition:
                                                CameraPosition(
                                              target: _initialCameraPosition,
                                              zoom: 5.5,
                                            ),
                                            myLocationEnabled: true,
                                            myLocationButtonEnabled: true,
                                            markers: _markers,
                                          ),

                                          // Legenda flutuante
                                          Positioned(
                                            top: 16,
                                            left: 16,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white70,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    blurRadius: 5,
                                                    color: Colors.black26,
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.circle,
                                                    size: 14,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Desaparecido',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Icon(
                                                    Icons.circle,
                                                    size: 14,
                                                    color: Colors.blue,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Encontrado',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
