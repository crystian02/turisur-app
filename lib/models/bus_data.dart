// lib/models/bus_data.dart

// Modelo para la informacion  y estado de cada bus
class BusData {
  final String id;
  final String driverId;
  final double lat;
  final double lon;
  final double bearing;
  final double speed;
  final String? alias;
  final String? email;
  final bool visible;
  final DateTime lastUpdate;
  final bool isMe;

  BusData({
    required this.id,
    required this.driverId,
    required this.lat,
    required this.lon,
    required this.bearing,
    this.speed = 0.0,
    this.alias,
    this.email,
    required this.visible,
    required this.lastUpdate,
    required this.isMe,
  });

  // Constructor de fabrica para instanciar a partir de payloads de sockets o HTTP
  factory BusData.fromJson(Map<String, dynamic> json, {String? myId}) {
    final String busId = (json['uuid'] ?? json['driver_id'] ?? json['id'] ?? '').toString();
    final double latitude = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final double longitude = double.tryParse((json['long'] ?? json['lon'] ?? json['lng'])?.toString() ?? '') ?? 0.0;
    final double heading = double.tryParse((json['degree'] ?? json['heading'] ?? json['bearing'])?.toString() ?? '') ?? 0.0;
    final double busSpeed = double.tryParse(json['speed']?.toString() ?? '') ?? 0.0;

    DateTime timestamp = DateTime.now();
    if (json['updated_at_ms'] != null) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(json['updated_at_ms'] as int);
    } else if (json['updated_at'] != null) {
      timestamp = DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    }

    return BusData(
      id: busId,
      driverId: (json['driver_id'] ?? busId).toString(),
      lat: latitude,
      lon: longitude,
      bearing: heading,
      speed: busSpeed,
      alias: json['alias']?.toString() ?? 'Bus Turisur',
      email: json['email']?.toString(),
      visible: json['visible'] == true || json['visible'] == 'true' || json['visible'] == 1,
      lastUpdate: timestamp,
      isMe: myId != null && busId == myId,
    );
  }

  // Serializacion a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'lat': lat,
      'long': lon,
      'degree': bearing,
      'speed': speed,
      'alias': alias,
      'email': email,
      'visible': visible,
      'updated_at': lastUpdate.toIso8601String(),
    };
  }
}