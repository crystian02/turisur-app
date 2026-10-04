// lib/services/comments_service.dart
// Clase de utilidad para validar la entrada de datos del formulario de comentarios.
class CommentsService {
  // Valida el formato y la presencia del correo electrónico para el feedback.
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, ingresa tu correo.';
    }
    // Expresión regular para validar formato.
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }

  // Valida que el campo de comentario no esté vacío y tenga una longitud mínima.
  static String? validateComment(String? value) {
    if (value == null || value.isEmpty) {
      return 'El comentario no puede estar vacío.';
    }
    if (value.length < 5) {
      return 'El comentario debe tener al menos 5 caracteres.';
    }
    return null;
  }

  // Lista de tipos de feedback disponibles para el selector (dropdown).
  static List<String> get commentTypes => [
    'sugerencia',
    'reclamo',
    'objeto perdido',
    'error en la aplicacion'
  ];
}