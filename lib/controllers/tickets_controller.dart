// lib/controllers/tickets_controller.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Gestiona la lista de pasajes emitidos para el usuario autenticado
class TicketsController with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Consulta los pasajes vigentes e historicos con datos de horario y recorrido
  Future<void> fetchTickets() async {
    _setLoading(true);
    _error = null;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _setError('Debes iniciar sesion para ver tus pasajes.');
      return;
    }

    try {
      final response = await _supabase
          .from('tickets')
          .select('''
            id,
            qr_code,
            status,
            seat_number,
            issued_at,
            schedules (
              id,
              origen,
              destino,
              dia,
              hora_salida,
              precio
            )
          ''')
          .eq('user_id', user.id)
          .order('issued_at', ascending: false);

      _tickets = List<Map<String, dynamic>>.from(response);
      _setLoading(false);
    } on PostgrestException catch (e) {
      debugPrint('[TicketsController] PostgrestException: ${e.message} - ${e.details}');
      _setError(e.message);
    } catch (e) {
      debugPrint('[TicketsController] Excepcion general: $e');
      _setError('Error al consultar pasajes: $e');
    }
  }

  // Helpers de gestion de estado
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}