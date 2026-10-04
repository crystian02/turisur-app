// lib/services/gps_task_handler.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turisur_app/common/globs.dart';

class GpsTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _sub;
  DateTime? _lastSentAt;
  Position? _lastPosition;

  static const _minSendInterval = Duration(seconds: 5);
  static const _minDistanceMeters = 10;

  static const _kLastLat = 'last_lat';
  static const _kLastLon = 'last_lon';
  static const _kLastSpeed = 'last_speed';
  static const _kLastHeading = 'last_heading';
  static const _kLastUpdated = 'last_updated';
  static const _kStartedAtMs = 'driver_started_at_ms';
  static const _kAutoStopMin = 'driver_auto_stop_minutes';
  static const _kUnitId = 'driver_unit_id';

  String? _unitIdCache;

  // Lee el unitId desde SharedPreferences con reload() para asegurar que
  // el isolate del servicio ve el valor escrito por el isolate principal.
  Future<String?> _getUnitId() async {
    if (_unitIdCache != null && _unitIdCache!.isNotEmpty) return _unitIdCache;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final v = prefs.getString(_kUnitId);
    if (v != null && v.isNotEmpty) {
      _unitIdCache = v;
    }
    return _unitIdCache;
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[GpsTaskHandler] Iniciado (starter=$starter)');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStartedAtMs, DateTime.now().millisecondsSinceEpoch);

    // Lee el unitId cuanto antes y lo deja en cache
    final unitId = await _getUnitId();
    debugPrint('[GpsTaskHandler] unitId al arrancar = $unitId');

    await _loadLastPosition();
    await _startGps();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final autoStopMin = prefs.getInt(_kAutoStopMin);
    final startedMs = prefs.getInt(_kStartedAtMs);

    if (autoStopMin != null && autoStopMin > 0 && startedMs != null) {
      final elapsedMin =
          (DateTime.now().millisecondsSinceEpoch - startedMs) ~/ 60000;
      if (elapsedMin >= autoStopMin) {
        debugPrint('[GpsTaskHandler] Auto-stop alcanzado ($elapsedMin min)');
        await FlutterForegroundTask.stopService();
        return;
      }
    }

    if (_sub == null) await _startGps();
    final p = _lastPosition;
    if (p != null) await _sendPosition(p, force: true);
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[GpsTaskHandler] Detenido');
    await _sub?.cancel();
    _sub = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStartedAtMs);
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _saveLastPosition(Position p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLastLat, p.latitude);
      await prefs.setDouble(_kLastLon, p.longitude);
      await prefs.setDouble(_kLastSpeed, p.speed);
      await prefs.setDouble(_kLastHeading, p.heading);
      await prefs.setInt(_kLastUpdated, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[GpsTaskHandler] Error guardando posicion: $e');
    }
  }

  Future<void> _loadLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLastLat);
      final lon = prefs.getDouble(_kLastLon);
      if (lat == null || lon == null) return;
      _lastPosition = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: prefs.getDouble(_kLastHeading) ?? 0,
        speed: prefs.getDouble(_kLastSpeed) ?? 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      debugPrint('[GpsTaskHandler] Ultima posicion cargada: $lat,$lon');
    } catch (e) {
      debugPrint('[GpsTaskHandler] Error cargando posicion: $e');
    }
  }

  Future<void> _startGps() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[GpsTaskHandler] Permiso de ubicacion denegado');
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      debugPrint('[GpsTaskHandler] Error GPS: $e');
    });
  }

  void _onPosition(Position p) {
    final previous = _lastPosition;
    _lastPosition = p;
    _saveLastPosition(p);

    final last = _lastSentAt;
    final now = DateTime.now();

    final movedEnough = previous != null &&
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              p.latitude,
              p.longitude,
            ) >=
            _minDistanceMeters;

    final shouldSend =
        last == null || now.difference(last) >= _minSendInterval || movedEnough;
    if (shouldSend) _sendPosition(p);
  }

  Future<void> _sendPosition(Position p, {bool force = false}) async {
    final unitId = await _getUnitId();
    if (unitId == null || unitId.isEmpty) {
      debugPrint('[GpsTaskHandler] unitId no disponible');
      return;
    }

    if (!force &&
        _lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) < _minSendInterval) {
      return;
    }

    final body = jsonEncode({
      'imei': unitId,
      'lat': p.latitude,
      'lon': p.longitude,
      'speed': (p.speed * 3.6).clamp(0, 255),
      'heading': p.heading,
    });

    try {
      final res = await http
          .post(
            Uri.parse('${Globs.rootUrl}/api/iot/bus-position'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        _lastSentAt = DateTime.now();
        debugPrint('[GpsTaskHandler] Posicion enviada a $unitId');
      }
    } catch (e) {
      debugPrint('[GpsTaskHandler] Error al enviar: $e');
    }
  }
}