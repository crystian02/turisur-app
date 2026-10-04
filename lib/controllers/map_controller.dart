// controllers/map_controller.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/services/service_call.dart';
import 'package:turisur_app/services/socket_manager.dart';

class MapController with ChangeNotifier {
  // Tiempos limite de conexion (en segundos)
  static const int kOfflineSeconds = 30; // Ampliado para mayor tolerancia en ruta
  static const int kExpireSeconds = 90;  // Margen amplio para evitar parpadeos
  static const double kBusMarkerDp = 30.0;

  // Prefijo usado por la app del chofer para identificar su propia unidad
  static const String kDriverIdPrefix = 'driver-';

  final SocketManager _socketManager = SocketManager.shared;

  final Map<MarkerId, Marker> _markers = {};
  final Map<String, int> _lastSeenMs = {};
  final Map<String, Map> _lastBusData = {};

  BitmapDescriptor? _iconBus;
  BitmapDescriptor? _iconBusOffline;
  BitmapDescriptor? _iconMyBus;

  bool _followingTarget = true;
  bool _userStartedCameraMove = false;

  StreamSubscription? _socketStatusSub;
  Timer? _busUpdateTimer;
  Timer? _statusTicker;

  bool _fetchInFlight = false;
  bool _iconsLoaded = false;
  bool _disposed = false;
  bool _initialized = false;

  // Getters para consultar el estado desde la vista
  Map<MarkerId, Marker> get markers => Map.unmodifiable(_markers);
  bool get followingTarget => _followingTarget;
  bool get userStartedCameraMove => _userStartedCameraMove;

  // ID del bus asociado al usuario autenticado (si es chofer y esta transmitiendo).
  // Devuelve null si no hay sesion valida.
  String? get myBusId {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return '$kDriverIdPrefix${user.id}';
  }

  // MarkerId del bus propio, util para centrar la camara.
  MarkerId? get myBusMarkerId {
    final id = myBusId;
    if (id == null) return null;
    return _markers.containsKey(MarkerId(id)) ? MarkerId(id) : null;
  }

  // Devuelve la posicion actual del bus propio, o null si no se esta compartiendo.
  LatLng? get myBusPosition {
    final id = myBusId;
    if (id == null) return null;
    return _markers[MarkerId(id)]?.position;
  }

  // Inicializacion del controlador (se ejecuta una sola vez)
  Future<void> initialize(BuildContext context) async {
    if (_disposed || _initialized) return;
    _initialized = true;

    await _loadIcons(context);

    _socketManager.initAndConnectSocket();
    _setupSocket();

    _startPolling();
    _startStatusTicker();
    _fetchCarLocations();
  }

  // Carga y escalado de iconos para los marcadores segun la densidad de pantalla
  Future<void> _loadIcons(BuildContext context) async {
    if (_iconsLoaded || _disposed) return;
    _iconsLoaded = true;

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetWidth = (kBusMarkerDp * dpr).round();

    _iconBus = await _loadIcon('assets/car.png', targetWidth);
    _iconBusOffline = await _loadIcon('assets/car_offline.png', targetWidth);

    // Icono opcional para el bus del propio chofer (verde/destacado).
    // Si no existe el asset, se usa el icono normal como fallback.
    try {
      _iconMyBus = await _loadIcon('assets/car_driver.png', targetWidth);
    } catch (_) {
      _iconMyBus = null;
    }

    _safeNotify();
  }

  Future<BitmapDescriptor> _loadIcon(String path, int width) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      final frame = await codec.getNextFrame();
      final bytes = (await frame.image
              .toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      // Uso del metodo nuevo para evitar el deprecado BitmapDescriptor.fromBytes
      return BitmapDescriptor.bytes(bytes);
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
    }
  }

  // Escucha de eventos de conexion y recepcion de posiciones via WebSockets
  void _setupSocket() {
    _socketStatusSub?.cancel();

    _socketStatusSub = _socketManager.onSocketStatusChange.listen((status) {
      if (status == SocketStatus.connected) {
        _fetchCarLocations();
      }
    });

    _socketManager.socket?.off(SVKey.svCarUpdateLocation);
    _socketManager.socket?.on(
      SVKey.svCarUpdateLocation,
      (data) => _processIncoming(data),
    );
  }

  // Consulta periodica HTTP como respaldo si el socket se desconecta
  void _startPolling() {
    _busUpdateTimer?.cancel();
    _busUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchCarLocations(),
    );
  }

  // Evaluacion continua de desconexion y expiracion de marcadores cada segundo
  void _startStatusTicker() {
    _statusTicker?.cancel();
    _statusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshMarkerStates();
    });
  }

  // Procesa datos entrantes del socket
  void _processIncoming(dynamic data) {
    if (_disposed) return;

    if (data is Map) {
      // Soporta tanto formato envuelto ({status: '1', payload: ...}) como directo
      if (data.containsKey(KKey.payload)) {
        final payload = data[KKey.payload];
        if (payload is Map) {
          _updateMarker(payload);
        } else if (payload is List) {
          for (final b in payload) {
            if (b is Map) _updateMarker(b);
          }
        }
      } else if (data.containsKey('lat') ||
          data.containsKey('driver_id') ||
          data.containsKey('uuid')) {
        _updateMarker(data);
      }
    }
  }

  // Extrae el identificador de la unidad desde el payload del backend.
  // Da prioridad a driver_id, luego uuid y por ultimo imei.
  String _extractId(Map bus) {
    return (bus['driver_id'] ?? bus['uuid'] ?? bus['imei'] ?? '').toString();
  }

  // Guarda en memoria la ultima ubicacion recibida de un bus
  void _updateMarker(Map bus) {
    final String id = _extractId(bus);
    if (id.isEmpty) return;

    final double lat = double.tryParse(bus['lat']?.toString() ?? '') ?? 0;
    // Soporta 'long', 'lng' o 'lon'
    final double lon = double.tryParse(
            (bus['long'] ?? bus['lng'] ?? bus['lon'])?.toString() ?? '') ??
        0;

    if (lat == 0.0 || lon == 0.0) return;

    // Extraccion robusta de marca temporal (soporta milisegundos, segundos o cadenas ISO)
    int lastMs = 0;
    final rawTime =
        bus['updated_at_ms'] ?? bus['updated_at'] ?? bus['created_at'];

    if (rawTime != null) {
      if (rawTime is int) {
        lastMs = rawTime > 10000000000 ? rawTime : rawTime * 1000;
      } else if (rawTime is String) {
        lastMs = int.tryParse(rawTime) ?? 0;
        if (lastMs == 0) {
          lastMs = DateTime.tryParse(rawTime)?.millisecondsSinceEpoch ?? 0;
        } else if (lastMs > 0 && lastMs < 10000000000) {
          lastMs = lastMs * 1000;
        }
      }
    }

    // Si el timestamp no se pudo leer, se asigna el momento actual para garantizar visibilidad inmediata
    if (lastMs == 0) {
      lastMs = DateTime.now().millisecondsSinceEpoch;
    }

    _lastSeenMs[id] = lastMs;
    _lastBusData[id] = bus;

    // Forzar actualizacion visual inmediata al recibir datos nuevos
    _refreshMarkerStates();
  }

  // Actualiza el aspecto de los marcadores (online, offline o eliminados por inactividad)
  void _refreshMarkerStates() {
    if (_disposed) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final myId = myBusId;
    bool changed = false;

    for (final id in List<String>.from(_lastSeenMs.keys)) {
      final lastMs = _lastSeenMs[id]!;
      final diffSeconds = (nowMs - lastMs) ~/ 1000;

      // Si supera el tiempo de expiracion, se quita del mapa
      if (diffSeconds > kExpireSeconds) {
        _markers.remove(MarkerId(id));
        _lastSeenMs.remove(id);
        _lastBusData.remove(id);
        changed = true;
        continue;
      }

      final bus = _lastBusData[id];
      if (bus == null) continue;

      final double lat = double.tryParse(bus['lat']?.toString() ?? '') ?? 0;
      final double lon = double.tryParse(
              (bus['long'] ?? bus['lng'] ?? bus['lon'])?.toString() ?? '') ??
          0;
      if (lat == 0.0 || lon == 0.0) continue;

      final bool online = diffSeconds <= kOfflineSeconds;
      final bool isMyBus = myId != null && id == myId;

      // Seleccion del icono segun estado y si es el propio bus
      BitmapDescriptor icon;
      if (isMyBus) {
        icon = _iconMyBus ??
            (online
                ? (_iconBus ?? BitmapDescriptor.defaultMarker)
                : (_iconBusOffline ?? BitmapDescriptor.defaultMarker));
      } else {
        icon = online
            ? (_iconBus ?? BitmapDescriptor.defaultMarker)
            : (_iconBusOffline ?? BitmapDescriptor.defaultMarker);
      }

      final String alias =
          (bus['alias'] ?? bus['plate'] ?? 'Bus Turisur').toString();
      final String title = isMyBus ? '$alias (Tu)' : alias;

      _markers[MarkerId(id)] = Marker(
        markerId: MarkerId(id),
        position: LatLng(lat, lon),
        rotation: double.tryParse(
                (bus['degree'] ?? bus['heading'] ?? '0').toString()) ??
            0,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: icon,
        // Uso de zIndexInt para evitar el deprecado zIndex
        zIndexInt: isMyBus ? 10 : 0,
        infoWindow: InfoWindow(
          title: title,
          snippet: 'Velocidad: ${(bus['speed'] ?? 0).toString()} km/h\n'
              'Ultima act.: ${DateTime.fromMillisecondsSinceEpoch(lastMs).toLocal().toString().substring(11, 19)}',
        ),
      );

      changed = true;
    }

    if (changed) _safeNotify();
  }

  // Peticion HTTP para obtener la lista inicial de buses
  Future<void> _fetchCarLocations() async {
    if (_fetchInFlight || _disposed) return;
    _fetchInFlight = true;

    ServiceCall.get(
      SVKey.svAllCarLocationsAPI,
      (res) {
        final List list = res[KKey.payload] ?? res['data'] ?? [];
        for (final b in list) {
          if (b is Map) _updateMarker(b);
        }
      },
      (_) {},
    ).whenComplete(() => _fetchInFlight = false);
  }

  // Control del seguimiento de camara en la interfaz
  void setFollowingTarget(bool v) {
    _followingTarget = v;
    _safeNotify();
  }

  void setUserStartedCameraMove(bool v) {
    _userStartedCameraMove = v;
    _safeNotify();
  }

  // Notifica a los listeners solo si el controlador sigue vivo
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // Limpieza de recursos al cerrar la pantalla
  @override
  void dispose() {
    _disposed = true;
    _socketStatusSub?.cancel();
    _busUpdateTimer?.cancel();
    _statusTicker?.cancel();
    _socketManager.socket?.off(SVKey.svCarUpdateLocation);
    super.dispose();
  }
}