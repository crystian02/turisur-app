// lib/controllers/schedule_controller.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleController with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _schedules = [];
  List<String> _origins = [];
  List<String> _destinations = [];

  bool _isLoadingSchedules = false;
  bool _isLoadingLocations = false;
  String? _error;

  List<Map<String, dynamic>> get schedules => _schedules;
  List<String> get origins => _origins;
  List<String> get destinations => _destinations;
  bool get isLoadingSchedules => _isLoadingSchedules;
  bool get isLoadingLocations => _isLoadingLocations;
  String? get error => _error;

  // Normaliza el texto a formato titulo ("san jose" -> "San Jose")
  String _capitalize(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  // Obtiene los origenes y destinos unicos registrados en los itinerarios
  Future<void> fetchUniqueLocations() async {
    _setLoadingLocations(true);
    _error = null;

    try {
      final rows = await _supabase
          .from('schedules')
          .select('origen,destino');

      final originSet = <String>{};
      final destinationSet = <String>{};

      for (final row in rows) {
        final origin = row['origen']?.toString();
        final destination = row['destino']?.toString();

        if (origin != null && origin.trim().isNotEmpty) {
          originSet.add(_capitalize(origin));
        }
        if (destination != null && destination.trim().isNotEmpty) {
          destinationSet.add(_capitalize(destination));
        }
      }

      // Orden alfabetico para la seleccion en la interfaz
      _origins = originSet.toList()..sort();
      _destinations = destinationSet.toList()..sort();

      _setLoadingLocations(false);
    } catch (e) {
      _setError('Error al cargar ubicaciones: $e');
      _setLoadingLocations(false);
    }
  }

  // Consulta los horarios disponibles filtrando por origen y destino
  Future<void> fetchSchedules({String? origin, String? destination}) async {
    _setLoadingSchedules(true);
    _error = null;

    try {
      var query = _supabase.from('schedules').select('*');

      // ilike permite coincidencias sin importar mayusculas o minusculas
      if (origin != null && origin.trim().isNotEmpty) {
        query = query.ilike('origen', origin.trim());
      }

      if (destination != null && destination.trim().isNotEmpty) {
        query = query.ilike('destino', destination.trim());
      }

      final result = await query.order('hora_salida', ascending: true);
      _schedules = List<Map<String, dynamic>>.from(result);
      _setLoadingSchedules(false);
    } catch (e) {
      _setError('Error al cargar horarios: $e');
      _setLoadingSchedules(false);
    }
  }

  // Metodos de gestion de estado
  void _setLoadingSchedules(bool loading) {
    _isLoadingSchedules = loading;
    notifyListeners();
  }

  void _setLoadingLocations(bool loading) {
    _isLoadingLocations = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoadingSchedules = false;
    _isLoadingLocations = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}