// lib/controllers/driver_location_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/main.dart';

class DriverLocationController with ChangeNotifier {
  bool _sharing = false;
  String? _error;
  DateTime? _startedAt;
  DateTime? _lastSharedAt;
  int? _autoStopMin;

  static const _kLastSharedKey = 'driver_last_shared_at';
  static const _kAutoStopKey = 'driver_auto_stop_minutes';
  static const _kUnitIdKey = 'driver_unit_id';

  bool get isSharing => _sharing;
  String? get error => _error;
  DateTime? get startedAt => _startedAt;
  DateTime? get lastSharedAt => _lastSharedAt;
  int? get autoStopMinutes => _autoStopMin;

  String get iotEndpoint => '${Globs.rootUrl}/api/iot/bus-position';

  String? get _unitId {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return null;
    return 'driver-${u.id}';
  }

  DriverLocationController() {
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();

    final ms = prefs.getInt(_kLastSharedKey);
    if (ms != null) {
      _lastSharedAt = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    final autoStop = prefs.getInt(_kAutoStopKey);
    if (autoStop != null && autoStop > 0) {
      _autoStopMin = autoStop;
    }

    notifyListeners();
  }

  Future<void> _saveLastSharedAt() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSharedAt = DateTime.now();
    await prefs.setInt(_kLastSharedKey, _lastSharedAt!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<bool> hasBackgroundPermission() async {
    final perm = await Geolocator.checkPermission();
    debugPrint('[DriverLocationController] geolocator permission = $perm');

    final alwaysStatus = await ph.Permission.locationAlways.status;
    debugPrint(
        '[DriverLocationController] permission_handler locationAlways = $alwaysStatus');

    if (perm == LocationPermission.always) return true;
    if (alwaysStatus == ph.PermissionStatus.granted) return true;
    return false;
  }

  Future<void> openSystemAppSettings() async {
    await ph.openAppSettings();
  }

  Future<int?> readAutoStopMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kAutoStopKey);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> scheduleAutoStop(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes <= 0) {
      await prefs.remove(_kAutoStopKey);
      _autoStopMin = null;
    } else {
      await prefs.setInt(_kAutoStopKey, minutes);
      _autoStopMin = minutes;
    }
    notifyListeners();
  }

  Future<bool> startSharing() async {
    if (_sharing) return true;
    _error = null;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _setError('No hay usuario autenticado.');
      return false;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profile?['role']?.toString().toLowerCase() ?? '';
      if (role != 'chofer') {
        _setError('Solo los choferes pueden compartir la ubicacion del bus.');
        return false;
      }
    } catch (e) {
      _setError('No se pudo verificar el rol: $e');
      return false;
    }

    if (_unitId == null) {
      _setError('No hay usuario autenticado.');
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _setError(
          'El GPS esta desactivado. Activalo para compartir tu ubicacion.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setError('Permiso de ubicacion denegado.');
      return false;
    }

    debugPrint(
        '[DriverLocationController] permission before start = $permission');
    final alwaysStatus = await ph.Permission.locationAlways.status;
    debugPrint(
        '[DriverLocationController] locationAlways status = $alwaysStatus');

    final hasAlways = permission == LocationPermission.always ||
        alwaysStatus == ph.PermissionStatus.granted;

    if (!hasAlways) {
      _setError(
        'Para compartir en segundo plano debes permitir la ubicacion '
        '"Todo el tiempo" en Ajustes -> Aplicaciones -> Turisur -> Permisos.',
      );
      return false;
    }

    final notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Si el servicio ya esta corriendo, adoptamos estado y no llamamos startService.
    // Esto evita ServiceRequestFailure cuando un servicio quedo vivo entre sesiones.
    final isRunning = await FlutterForegroundTask.isRunningService;
    debugPrint('[DriverLocationController] isRunningService = $isRunning');

    if (isRunning) {
      debugPrint(
          '[DriverLocationController] Servicio ya corriendo, adoptando estado');

      // Aseguramos que el unitId este en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUnitIdKey, 'driver-${user.id}');

      _sharing = true;
      _startedAt = DateTime.now();
      await _saveLastSharedAt();
      notifyListeners();
      return true;
    }

    // Persiste el unitId para que el isolate del servicio lo pueda leer.
    // El isolate del Foreground Service NO comparte memoria con el principal,
    // asi que la unica forma de pasarlo es via SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnitIdKey, 'driver-${user.id}');

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Turisur activo',
      notificationText: 'Compartiendo la ubicacion del bus en tiempo real',
      callback: startCallback,
    );

    debugPrint('[DriverLocationController] startService -> $result');

    if (result is ServiceRequestSuccess) {
      _sharing = true;
      _startedAt = DateTime.now();
      await _saveLastSharedAt();
      notifyListeners();
      return true;
    } else if (result is ServiceRequestFailure) {
      debugPrint('[DriverLocationController] FALLO: ${result.error}');
      _setError('startService fallo: ${result.error}');
      return false;
    } else {
      _setError('startService devolvio un resultado inesperado: $result');
      return false;
    }
  }

  Future<void> stopSharing() async {
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUnitIdKey);

    _sharing = false;
    _startedAt = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }
}