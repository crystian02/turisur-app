// lib/services/service_call.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../common/globs.dart';

// Definiciones de callbacks para metodos tradicionales
typedef ResSuccess = void Function(Map<String, dynamic>);
typedef ResFailure = void Function(dynamic);

// Cliente HTTP central para peticiones a la API REST del backend
class ServiceCall {
  // Peticion POST con manejo mediante callbacks
  static Future<void> post(
    Map<String, dynamic> parameter,
    String path,
    ResSuccess? withSuccess,
    ResFailure? failure,
  ) async {
    final completer = Completer<void>();
    try {
      final headers = {'Content-Type': 'application/json'};
      final encodedBody = jsonEncode(parameter);

      if (kDebugMode) {
        debugPrint('[ServiceCall] POST $path');
        debugPrint('[ServiceCall] BODY $encodedBody');
      }

      final response = await http.post(
        Uri.parse(path),
        body: encodedBody,
        headers: headers,
      );

      if (kDebugMode) {
        debugPrint('[ServiceCall] RESP $path: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonObj = (json.decode(response.body) as Map<String, dynamic>?) ?? {};

        // Compatible con respuestas { status: '1' } o respuestas con clave { ok: true/false }
        if (jsonObj[KKey.status] == '1' || jsonObj.containsKey('ok')) {
          withSuccess?.call(jsonObj);
          completer.complete();
        } else {
          final errorMessage = jsonObj[KKey.message] ?? 'Error en la operacion';
          failure?.call(errorMessage);
          completer.completeError(errorMessage);
        }
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: Servidor no disponible';
        failure?.call(errorMessage);
        completer.completeError(errorMessage);
      }
    } catch (e) {
      debugPrint('[ServiceCall] Excepcion en POST: $e');
      failure?.call('Error de red: No se pudo conectar con el servidor.');
      completer.completeError(e);
    }
    return completer.future;
  }

  // Peticion GET con manejo mediante callbacks
  static Future<void> get(
    String path,
    ResSuccess? withSuccess,
    ResFailure? failure,
  ) async {
    final completer = Completer<void>();
    try {
      if (kDebugMode) {
        debugPrint('[ServiceCall] GET $path');
      }

      final response = await http.get(Uri.parse(path));

      if (kDebugMode) {
        debugPrint('[ServiceCall] RESP $path: ${response.statusCode} - ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonObj = (json.decode(response.body) as Map<String, dynamic>?) ?? {};

        if (jsonObj[KKey.status] == '1' || jsonObj.containsKey('ok')) {
          withSuccess?.call(jsonObj);
          completer.complete();
        } else {
          final errorMessage = jsonObj[KKey.message] ?? 'Error de respuesta';
          failure?.call(errorMessage);
          completer.completeError(errorMessage);
        }
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: Error del servidor';
        failure?.call(errorMessage);
        completer.completeError(errorMessage);
      }
    } catch (e) {
      failure?.call('Error de conexion: $e');
      completer.completeError(e);
    }
    return completer.future;
  }

  // Peticion POST directa con Future para controladores modernos (async/await)
  static Future<Map<String, dynamic>> rawPost(
    String url,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      debugPrint('[ServiceCall] rawPost $url -> ${res.statusCode} ${res.body}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('La respuesta del servidor no tiene un formato JSON valido.');
    }

    final serverMessage = decoded is Map ? (decoded['message'] ?? decoded['error']) : null;
    throw Exception(serverMessage ?? 'Error ${res.statusCode} al procesar la solicitud.');
  }

  // Peticion GET directa con Future para controladores modernos (async/await)
  static Future<Map<String, dynamic>> rawGet(String url) async {
    final res = await http.get(Uri.parse(url));

    if (kDebugMode) {
      debugPrint('[ServiceCall] rawGet $url -> ${res.statusCode} ${res.body}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('La respuesta del servidor no tiene un formato JSON valido.');
    }

    final serverMessage = decoded is Map ? (decoded['message'] ?? decoded['error']) : null;
    throw Exception(serverMessage ?? 'Error ${res.statusCode} al consultar el servicio.');
  }
}