import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class AddAnimalLocationPage extends StatefulWidget {
  final String animalId; // ID do documento no Firestore
  const AddAnimalLocationPage({required this.animalId, Key? key})
    : super(key: key);

  @override
  State<AddAnimalLocationPage> createState() => _AddAnimalLocationPageState();
}

class _AddAnimalLocationPageState extends State<AddAnimalLocationPage> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// 📍 Obtém a localização atual do usuário
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica se o serviço de localização está ativado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative o serviço de localização!')),
      );
      setState(() => _loading = false);
      return;
    }

    // Solicita permissão de localização
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada.')),
        );
        setState(() => _loading = false);
        return;
      }
    }

    // Se a permissão for permanente negada
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissão permanente negada. Vá nas configurações.'),
        ),
      );
      setState(() => _loading = false);
      return;
    }

    // Pega a localização atual
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
    });
  }

  /// 💾 Salva a localização selecionada no Firestore
  Future<void> _saveLocation() async {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toque no mapa para selecionar uma localização.'),
        ),
      );
      return;
    }

    try {
      final date = DateTime.now();
      final formattedDate = DateFormat(
        "dd 'de' MMMM 'de' yyyy 'às' HH:mm:ss 'UTC-3'",
        'pt_BR',
      ).format(date);

      await FirebaseFirestore.instance
          .collection('animals')
          .doc(widget.animalId)
          .update({
            'ultima_localizacao': {
              'data_hora': formattedDate,
              'latitude': _selectedPosition!.latitude,
              'longitude': _selectedPosition!.longitude,
            },
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização registrada com sucesso!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marcar última localização'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    onMapCreated: (controller) => mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition ?? const LatLng(0, 0),
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: {
                      if (_selectedPosition != null)
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: _selectedPosition!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'Local onde o animal foi visto',
                          ),
                        ),
                    },
                    onTap: (pos) {
                      setState(() {
                        _selectedPosition = pos;
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toque no mapa para marcar o local onde o animal foi visto pela última vez.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      if (_selectedPosition != null)
                        Text(
                          'Local selecionado: '
                          '${_selectedPosition!.latitude.toStringAsFixed(5)}, '
                          '${_selectedPosition!.longitude.toStringAsFixed(5)}',
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveLocation,
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar localização'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
