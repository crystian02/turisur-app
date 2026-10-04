// lib/controllers/ticket_scanner_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/services/service_call.dart';

// Maneja el estado y la validacion de pasajes mediante codigos QR
class TicketScannerController with ChangeNotifier {
  bool _isProcessing = false;
  String? _error;

  bool get isProcessing => _isProcessing;
  String? get error => _error;

  // Envia el codigo QR y los datos del bus al backend para su canje
  Future<bool> validateTicket(
    String qrCode, {
    String busImei = 'APP_VALIDATOR',
    double lat = 0.0,
    double lng = 0.0,
  }) async {
    if (_isProcessing) return false;

    _setProcessing(true);
    _error = null;

    try {
      final completer = Completer<bool>();

      await ServiceCall.post(
        {
          'qr': qrCode.trim(),
          'imei': busImei.trim(),
          'lat': lat,
          'lng': lng,
        },
        SVKey.svValidateTicket,
        (json) {
          if (json['ok'] == true) {
            _setProcessing(false);
            completer.complete(true);
          } else {
            final reason = json['reason']?.toString() ?? 'UNKNOWN_ERROR';
            _setError(_mapReasonToMessage(reason));
            completer.complete(false);
          }
        },
        (err) {
          debugPrint('[QR Scanner] Error de red: $err');
          _setError('Error de comunicacion con el servidor. Verifique su conexion.');
          completer.complete(false);
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('[QR Scanner] Excepcion al validar pasaje: $e');
      _setError('Error inesperado al validar el pasaje.');
      _setProcessing(false);
      return false;
    }
  }

  // Traduce las respuestas tecnicas del backend a mensajes para el usuario
  String _mapReasonToMessage(String reason) {
    switch (reason) {
      case 'QR_INVALID':
        return 'El codigo QR no es valido o no existe.';
      case 'ALREADY_USED':
        return 'Este pasaje ya fue utilizado anteriormente.';
      case 'PAYMENT_NOT_APPROVED':
        return 'El pago de este pasaje aun no ha sido aprobado.';
      case 'BUS_NOT_REGISTERED':
        return 'El bus emisor no esta registrado en el sistema.';
      case 'BAD_DATA':
        return 'Datos de escaneo incompletos.';
      case 'SERVER_ERROR':
        return 'Error en el servidor. Intente nuevamente en unos instantes.';
      case 'CONCURRENCY_ERROR':
        return 'El pasaje ya esta en proceso de validacion.';
      default:
        return 'No se pudo validar el pasaje ($reason).';
    }
  }

  // Helpers de gestion de estado
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isProcessing = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}