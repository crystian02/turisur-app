// lib/models/location_model.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:turisur_app/models/bus_data.dart';

// Representacion basica de una coordenada geografica
class LocationData {
  final double latitude;
  final double longitude;
  final double? bearing;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.bearing,
    required this.timestamp,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(
              (json['long'] ?? json['lng'] ?? json['lon'])?.toString() ?? '') ??
          0.0,
      bearing: double.tryParse(
          (json['degree'] ?? json['heading'])?.toString() ?? ''),
      timestamp:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  LatLng toLatLng() => LatLng(latitude, longitude);
}

// Representacion orientada a la capa visual del mapa
class BusMarker {
  final String id;
  final LatLng position;
  final double bearing;
  final String title;
  final bool isMyBus;
  final DateTime lastUpdate;

  BusMarker({
    required this.id,
    required this.position,
    required this.bearing,
    required this.title,
    required this.isMyBus,
    required this.lastUpdate,
  });

  // Crea la instancia visual a partir del modelo de datos base
  factory BusMarker.fromBusData(BusData bus) {
    return BusMarker(
      id: bus.id,
      position: LatLng(bus.lat, bus.lon),
      bearing: bus.bearing,
      title: bus.alias ?? 'Bus Turisur',
      isMyBus: bus.isMe,
      lastUpdate: bus.lastUpdate,
    );
  }
}