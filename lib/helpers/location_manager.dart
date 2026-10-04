// lib/helpers/location_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// Canal global para notificar cambios de ubicacion mediante un Stream broadcast
class LocationManager {
  static final LocationManager shared = LocationManager._internal();

  factory LocationManager() => shared;

  LocationManager._internal();

  final _updateController = StreamController<void>.broadcast();

  Stream<void> get onUpdate => _updateController.stream;

  // Punto de entrada para inicializar el coordinador
  Future<void> initialize() async {
    debugPrint('[LocationManager] Coordinador de notificaciones activo');
  }

  // Emite un aviso a todos los escuchas suscritos en la app
  void notifyUpdate() {
    if (!_updateController.isClosed) {
      _updateController.add(null);
    }
  }

  // Cierra el stream para liberar recursos de memoria
  void dispose() {
    _updateController.close();
    debugPrint('[LocationManager] Cerrado y liberado');
  }
}