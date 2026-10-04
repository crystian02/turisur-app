// lib/services/socket_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:turisur_app/common/globs.dart';

// Estados posibles de la conexion del socket
enum SocketStatus { connecting, connected, disconnected, error }

// Administrador de conexion en tiempo real mediante WebSockets (Socket.IO)
class SocketManager {
  static final SocketManager shared = SocketManager._internal();
  factory SocketManager() => shared;

  SocketManager._internal();

  io.Socket? socket;

  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  SocketStatus _currentStatus = SocketStatus.disconnected;

  Stream<SocketStatus> get onSocketStatusChange => _statusController.stream;
  bool get isConnected => socket?.connected ?? false;

  // Carga preferencias y evalua si debe conectar
  Future<void> initAndConnectSocket({bool shouldConnect = true}) async {
    await Globs.loadSharedPrefs();

    if (!shouldConnect) {
      disconnectSocket();
      return;
    }

    _connectSocket();
  }

  // Establece el enlace WebSocket con el backend
  void _connectSocket() {
    if (_currentStatus == SocketStatus.connecting) return;
    if (socket != null && socket!.connected) return;

    final uuid = Globs.deviceUUID;
    if (uuid.isEmpty) {
      debugPrint('[SocketManager] UUID no encontrado, conexion abortada');
      return;
    }

    _updateStatus(SocketStatus.connecting);

    socket?.dispose();

    socket = io.io(
      Globs.rootUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'uuid': uuid,
          'driver_id': uuid,
        },
        'reconnection': true,
        'reconnectionAttempts': double.infinity,
        'reconnectionDelay': 2000,
        'reconnectionDelayMax': 5000,
      },
    );

    _setupListeners();
    socket!.connect();
  }

  // Eventos de conexion y ciclo de vida del socket
  void _setupListeners() {
    socket?.onConnect((_) {
      debugPrint('[SocketManager] Conectado exitosamente');
      _updateStatus(SocketStatus.connected);
    });

    socket?.onDisconnect((_) {
      debugPrint('[SocketManager] Desconectado');
      _updateStatus(SocketStatus.disconnected);
    });

    socket?.onConnectError((err) {
      debugPrint('[SocketManager] Error de conexion: $err');
      _updateStatus(SocketStatus.error);
    });
  }

  // Notifica cambios de estado a los escuchas
  void _updateStatus(SocketStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  // Cierra activamente la conexion
  void disconnectSocket() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    _updateStatus(SocketStatus.disconnected);
  }

  // Libera controladores al desmontar recursos
  void dispose() {
    disconnectSocket();
    _statusController.close();
  }
}