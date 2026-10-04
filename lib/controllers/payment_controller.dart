// lib/controllers/payment_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/services/service_call.dart';

class PaymentController with ChangeNotifier {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _isLoading = false;
  bool _isFinished = false;
  String? _error;
  String? _tempOrderId;

  bool get isLoading => _isLoading;
  bool get isFinished => _isFinished;
  String? get error => _error;
  String? get orderId => _tempOrderId;

  // Crea la orden y obtiene la URL y el token de pago de Transbank
  Future<Map<String, dynamic>> initializePayment({
    required String userId,
    required String scheduleId,
    required int seats,
    required int unitPrice,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Crear la orden de compra en el backend
      final orderRes = await ServiceCall.rawPost(
        SVKey.svOrders,
        {
          'userId': userId,
          'scheduleId': scheduleId,
          'seats': seats,
          'unitPrice': unitPrice,
        },
      );

      final order = orderRes['order'];
      if (order == null || order['id'] == null) {
        throw Exception('No se pudo crear la orden en el servidor');
      }

      _tempOrderId = order['id']?.toString();

      // 2. Iniciar la transaccion Webpay en el backend
      final paymentRes = await ServiceCall.rawPost(
        SVKey.svPayments,
        {
          'orderId': _tempOrderId,
          'userId': userId,
        },
      );

      _isLoading = false;
      notifyListeners();

      return Map<String, dynamic>.from(paymentRes);
    } catch (e) {
      _setError('Error al iniciar el pago: $e');
      rethrow;
    }
  }

  // Inicia la escucha del Deep Link tras el retorno de Transbank
  void startDeepLinkListening() {
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri.scheme == Globs.appScheme) {
          handleDeepLinkResult(uri);
        }
      },
      onError: (err) => debugPrint('[DeepLink] Error en stream: $err'),
    );
  }

  // Procesa la respuesta enviada por el navegador de retorno
  Future<void> handleDeepLinkResult(Uri uri) async {
    final status = uri.queryParameters['status'];
    debugPrint('[DeepLink] Respuesta recibida: $uri');

    if (status == 'aborted' || status == 'cancelled') {
      _setError('Pago cancelado por el usuario');
      return;
    }

    if (status == 'rejected' || status == 'error') {
      _setError('Pago rechazado o fallido');
      return;
    }

    if (status == 'approved') {
      _isFinished = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Consulta los pasajes emitidos para la orden confirmada
  Future<List<dynamic>> fetchTicketsByOrder() async {
    if (_tempOrderId == null) return [];

    try {
      final res = await ServiceCall.rawGet(
        '${SVKey.svTicketsByOrder}/$_tempOrderId/tickets',
      );
      return (res['tickets'] as List?) ?? [];
    } catch (e) {
      debugPrint('[Tickets] Error al consultar pasajes: $e');
      return [];
    }
  }

  // Manejo de errores y estado
  void _setError(String msg) {
    _error = msg;
    _isLoading = false;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _isFinished = false;
    _error = null;
    _tempOrderId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}