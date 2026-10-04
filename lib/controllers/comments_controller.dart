// controllers/comments_controller.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsController with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isSubmitting = false;
  bool _isLoadingHistory = false;
  String? _error;

  List<Map<String, dynamic>> _myComments = [];

  bool get isSubmitting => _isSubmitting;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;
  List<Map<String, dynamic>> get myComments => _myComments;

  // Enviar un nuevo comentario a la base de datos
  Future<bool> submitComment({
    required String comment,
    required String type,
  }) async {
    _setSubmitting(true);
    _error = null;

    final userEmail = _supabase.auth.currentUser?.email;
    if (userEmail == null) {
      _setError('No se encontro un usuario autenticado.');
      return false;
    }

    try {
      await _supabase.from('comments').insert({
        'correo_electronico': userEmail.trim(),
        'tipo': type,
        'comentario': comment.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      _setSubmitting(false);

      // Actualizar la lista local tras guardar
      await fetchComments();
      return true;
    } catch (e) {
      _setError('Error al enviar el comentario: $e');
      return false;
    }
  }

  // Obtener los comentarios asociados al correo del usuario actual
  Future<void> fetchComments() async {
    final userEmail = _supabase.auth.currentUser?.email;
    if (userEmail == null) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final List<dynamic> response = await _supabase
          .from('comments')
          .select()
          .eq('correo_electronico', userEmail.trim())
          .order('created_at', ascending: false);

      _myComments = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[Comentarios] Error al consultar historial: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // Helpers de gestion de estado
  void _setSubmitting(bool submitting) {
    _isSubmitting = submitting;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isSubmitting = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}