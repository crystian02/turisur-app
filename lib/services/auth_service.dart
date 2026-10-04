// lib/services/auth_service.dart

// Validaciones estaticas para formularios de autenticacion y recuperacion
class AuthService {
  // Valida que el nombre de usuario no este vacio y tenga longitud minima
  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Ingresa tu nombre';
    if (name.length < 2) return 'El nombre es muy corto';
    return null;
  }

  // Valida el formato basico de una direccion de correo electronico
  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo';

    final exp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!exp.hasMatch(email)) return 'Correo invalido';

    return null;
  }

  // Valida los requisitos minimos de contrasena
  static String? validatePassword(String? value) {
    final pass = value ?? '';
    if (pass.isEmpty) return 'Ingresa tu contrasena';
    if (pass.length < 6) return 'Minimo 6 caracteres';
    return null;
  }

  // Comprueba la igualdad entre la contrasena y su confirmacion
  static String? validateConfirmPassword(String? pass, String? confirm) {
    if (confirm == null || confirm.isEmpty) return 'Repite la contrasena';
    if (pass != confirm) return 'Las contrasenas no coinciden';
    return null;
  }

  // Valida el codigo OTP de 6 digitos para la recuperacion de contrasena
  static String? validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'Ingresa el codigo';
    if (code.length != 6) return 'Debe tener 6 digitos';
    if (!RegExp(r'^[0-9]+$').hasMatch(code)) return 'Solo debe contener numeros';
    return null;
  }
}