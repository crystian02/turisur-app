// lib/views/map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:turisur_app/controllers/map_controller.dart';

// Pantalla con vista satelital/vectorial para monitoreo de buses en tiempo real
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  GoogleMapController? _googleMapController;
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MapController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initialize(context);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.initialize(context);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  // Centra la camara en un bus aleatorio y activa el seguimiento automatico
  Future<void> _goToRandomBus() async {
    if (_controller.markers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No hay buses activos en este momento'),
        ),
      );
      return;
    }

    final markers = _controller.markers.values.toList()..shuffle();
    final m = markers.first;

    _controller.setFollowingTarget(true);
    _controller.setUserStartedCameraMove(false);

    await _animateToLatLng(m.position, bearing: m.rotation);
  }

  // Transicion animada hacia coordenadas especificas
  Future<void> _animateToLatLng(
    LatLng target, {
    double bearing = 0.0,
  }) async {
    if (_googleMapController == null) return;

    await _googleMapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 16.5,
          bearing: bearing,
          tilt: 30,
        ),
      ),
    );
  }

  Future<void> _zoomIn() async {
    if (_googleMapController == null) return;
    await _googleMapController!.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    if (_googleMapController == null) return;
    await _googleMapController!.animateCamera(CameraUpdate.zoomOut());
  }

  // Ajusta la camara para mostrar todos los buses visibles de forma simultanea
  Future<void> _zoomOutToFullMap() async {
    if (_googleMapController == null || _controller.markers.isEmpty) return;

    final markers = _controller.markers.values;
    double minLat = markers.first.position.latitude;
    double maxLat = minLat;
    double minLng = markers.first.position.longitude;
    double maxLng = minLng;

    for (final m in markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    // Margen de seguridad si solo hay un marcador o todos tienen coordenadas identicas
    if (minLat == maxLat && minLng == maxLng) {
      await _animateToLatLng(LatLng(minLat, minLng));
      return;
    }

    await _googleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // Despliega el listado inferior con todos los buses detectados y su telemetria
  void _showBusList() {
    if (_controller.markers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No hay buses activos para listar'),
        ),
      );
      return;
    }

    final buses = _controller.markers.values.toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Buses en Ruta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: buses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = buses[i];
                    final title = m.infoWindow.title ?? m.markerId.value;
                    final snippet = m.infoWindow.snippet ?? '';

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Icon(Icons.directions_bus, color: Colors.green),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        snippet.isNotEmpty ? snippet : 'Posicion en tiempo real',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.pop(context);
                        _controller.setFollowingTarget(true);
                        _animateToLatLng(m.position, bearing: m.rotation);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
  }

  void _onCameraMove(CameraPosition _) {
    // Si el usuario mueve el mapa manualmente, se suspende el seguimiento forzado
    if (_controller.followingTarget && !_controller.userStartedCameraMove) {
      _controller.setFollowingTarget(false);
      _controller.setUserStartedCameraMove(true);
    }
  }

  void _onCameraIdle() {
    if (_controller.userStartedCameraMove) {
      _controller.setUserStartedCameraMove(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Consumer<MapController>(
          builder: (_, controller, __) {
            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-39.8142, -73.2459), // Valdivia / Los Rios
                    zoom: 11,
                  ),
                  onMapCreated: _onMapCreated,
                  markers: Set<Marker>.of(controller.markers.values),
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  myLocationButtonEnabled: false,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),

                // Controles de navegacion lateral flotante
                Positioned(
                  top: 90,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoomInBtn',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoomOutBtn',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'fitMapBtn',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        onPressed: _zoomOutToFullMap,
                        child: const Icon(Icons.zoom_out_map),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'followBusBtn',
                        backgroundColor: controller.followingTarget
                            ? Colors.green
                            : Colors.white,
                        foregroundColor: controller.followingTarget
                            ? Colors.white
                            : Colors.black87,
                        onPressed: _goToRandomBus,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),

                // Tarjeta de estado de flota superior
                Positioned(
                  top: 24,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _showBusList,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(240),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Buses en ruta: ${controller.markers.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}