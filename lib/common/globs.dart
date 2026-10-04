// lib/common/globs.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Globs {
  static const appName = "Turisur - Seguimiento de Buses";

  static SharedPreferences? _preferences;
  static String deviceUUID = "";

  static SharedPreferences get shared {
    if (_preferences == null) {
      throw Exception(
        "SharedPreferences no inicializado. Llama a Globs.loadSharedPrefs() en main.dart.",
      );
    }
    return _preferences!;
  }

  static Future<void> loadSharedPrefs() async {
    if (_preferences == null) {
      _preferences = await SharedPreferences.getInstance();

      deviceUUID = _preferences?.getString("device_uuid") ?? '';
      if (deviceUUID.isEmpty) {
        deviceUUID = const Uuid().v4();
        await _preferences?.setString("device_uuid", deviceUUID);
        debugPrint("Globs: deviceUUID generado: $deviceUUID");
      } else {
        debugPrint("Globs: deviceUUID cargado: $deviceUUID");
      }
    }
  }

  // Configuracion servidor
  static const String serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: 'https://turisur-backend.onrender.com',
  );

  static String get rootUrl => serverHost;
  static String get apiUrl => "$serverHost/api";

  // Deep Links
  static const String appScheme = 'turisur';

  // Helpers SharedPreferences
  static Future<void> udSetString(String key, String value) async {
    await shared.setString(key, value);
  }

  static String udValueString(String key) {
    return shared.getString(key) ?? "";
  }

  static Future<void> udSetBool(String key, bool value) async {
    await shared.setBool(key, value);
  }

  static bool udValueBool(String key) {
    return shared.getBool(key) ?? false;
  }

  static Future<bool> udRemove(String key) async {
    return await shared.remove(key);
  }

  // Helpers UI
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// Endpoints & Socket Keys
class SVKey {
  // Geolocalizacion
  static String get svAllCarLocationsAPI => "${Globs.apiUrl}/all_car_locations";

  // Socket.IO
  static const String svCarUpdateLocation = "car_update_location";
  static const String svCarJoin = "car_join";
  static const String svCarVisibilityChanged = "car_visibility_changed";
  static const String svUpdateSocket = "update_socket";
  static const String svUpdateSocketAlt = "UpdateSocket";

  // Pagos
  static String get svOrders => "${Globs.apiUrl}/orders";
  static String get svPayments => "${Globs.apiUrl}/payments";
  static String get svPaymentsConfirm => "${Globs.apiUrl}/payments/confirm";
  static String get svTicketsByOrder => "${Globs.apiUrl}/orders";

  // Tickets
  static String get svValidateTicket => "${Globs.apiUrl}/validate_ticket";
}

// Claves JSON estandar
class KKey {
  static const String payload = "payload";
  static const String status = "status";
  static const String message = "message";
}