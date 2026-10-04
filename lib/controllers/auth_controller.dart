// lib/controllers/auth_controller.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Acceso rápido al usuario autenticado actual con email verificado
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated =>
      _supabase.auth.currentUser != null &&
      _supabase.auth.currentUser!.email != null &&
      _supabase.auth.currentUser!.email!.trim().isNotEmpty;

  // Inicio de sesión con correo y contraseña
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _setLoading(false);
      
      // Validación estricta: usuario existente y con correo válido
      return response.user != null &&
          response.user!.email != null &&
          response.user!.email!.trim().isNotEmpty;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error de conexión o inesperado: $e');
      return false;
    }
  }

  // Registro de usuario (la tabla profiles se llena mediante trigger en Supabase)
  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'name': name.trim(),
        },
      );

      if (response.user == null) {
        _setError('No se pudo crear el usuario.');
        return false;
      }

      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error inesperado: $e');
      return false;
    }
  }

  // Envío de código OTP para recuperación de contraseña
  Future<bool> sendPasswordResetCode(String email) async {
    _setLoading(true);
    _error = null;

    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al enviar código: $e');
      return false;
    }
  }

  // Validación del código OTP ingresado por el usuario
  Future<bool> verifyResetCode(String email, String code) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      );

      _setLoading(false);
      return result.user != null;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Código inválido o expirado');
      return false;
    }
  }

  // Actualización de la contraseña del usuario autenticado
  Future<bool> resetPassword(String newPassword) async {
    _setLoading(true);
    _error = null;

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );

      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Error al cambiar contraseña: $e');
      return false;
    }
  }

  // Cierre de sesión en el cliente de Supabase
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  // Métodos auxiliares de gestión de estado
  void _setLoading(bool state) {
    _isLoading = state;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void forceStopLoading() {
    _isLoading = false;
    notifyListeners();
  }
}