// lib/views/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turisur_app/controllers/auth_controller.dart';
import 'package:turisur_app/services/auth_service.dart';
import 'package:turisur_app/views/auth/reset_password_screen.dart';

// Pantalla para que el usuario ingrese el código de verificación.
class VerifyCodeScreen extends StatefulWidget {
  // El correo es obligatorio para enviar el código al AuthController.
  final String email; 
  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // Lógica para validar y enviar el código de verificación al servidor.
  Future<void> _verify(AuthController authController) async {
    // Validación local: verifica que el código tenga 6 dígitos.
    final validationError = AuthService.validateCode(_codeController.text);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    // Llama al controlador para verificar el código en el backend.
    final success = await authController.verifyResetCode(
      widget.email, 
      _codeController.text
    );
    
    if (success && mounted) {
      // Éxito: Navega a la pantalla de ResetPassword, reemplazando esta ruta.
      // Esto evita que el usuario pueda volver a la pantalla de verificación con el botón 'Atrás'.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: widget.email),
        ),
      );
    } else if (mounted) {
      // Falla: Muestra el error (ej. "Código expirado" o "Código incorrecto").
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authController.error ?? 'Código inválido')),
      );
      authController.clearError(); // Limpia el error después de mostrarlo.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/logoRMV.png', height: 36)),
      body: Consumer<AuthController>(
        builder: (context, authController, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Verificar código',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Muestra el correo para recordar al usuario dónde buscar el código.
                Text('Enviamos un código a: ${widget.email}'), 
                const SizedBox(height: 20),
                // Campo de entrada para el código.
                TextField(
                  controller: _codeController,
                  maxLength: 6, // Límite de 6 dígitos.
                  textAlign: TextAlign.center, // Centrado para mejorar la lectura de códigos.
                  keyboardType: TextInputType.number, // Teclado numérico.
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    prefixIcon: Icon(Icons.security),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _verify(authController),
                ),
                const SizedBox(height: 16),
                // Botón de acción: deshabilitado durante el procesamiento.
                FilledButton(
                  onPressed: authController.isLoading ? null : () => _verify(authController),
                  child: authController.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verificar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}