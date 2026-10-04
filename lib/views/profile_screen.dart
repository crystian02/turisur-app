// lib/views/profile_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turisur_app/controllers/comments_controller.dart';
import 'package:turisur_app/controllers/driver_location_controller.dart';
import 'package:turisur_app/views/comments/comments_screen.dart';
import 'package:turisur_app/views/tickets/ticket_scanner_screen.dart';

// Vista de perfil de usuario con permisos de rol y accesos rapidos
class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const ProfileScreen({super.key, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _user = Supabase.instance.client.auth.currentUser;
  String _userName = '';
  String _userRole = 'usuario';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Ejecuta la consulta de perfil despues de que el primer frame este listo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  // Carga los datos de perfil y rol desde Supabase
  Future<void> _loadUserProfile() async {
    // Si no hay sesion valida o carece de email, cierra sesion de fondo
    if (_user == null || _user.email == null || _user.email!.trim().isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
      }
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('name, role')
          .eq('id', _user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        setState(() {
          _userName = response['name']?.toString() ?? '';
          _userRole = (response['role']?.toString().toLowerCase() ?? 'usuario');
          _loading = false;
        });
      } else {
        setState(() {
          _userName = _user.userMetadata?['name']?.toString() ??
              _user.email?.split('@').first ??
              'Usuario';
          _userRole = 'usuario';
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProfileScreen] Error al cargar perfil: $e');
      }

      if (!mounted) return;
      setState(() {
        _userName = _user.userMetadata?['name']?.toString() ??
            _user.email?.split('@').first ??
            'Usuario';
        _userRole = 'usuario';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isChofer = _userRole == 'chofer';
    final roleColor = isChofer ? Colors.orange : Colors.deepPurple;
    final roleLabel = isChofer ? 'Chofer' : 'Pasajero';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta principal de identidad
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: roleColor,
                          child: Icon(
                            isChofer ? Icons.directions_bus : Icons.person,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _userName.isNotEmpty ? _userName : 'Usuario Turisur',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? 'Sin correo registrado',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Chip(
                          side: BorderSide.none,
                          label: Text(
                            roleLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: roleColor,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Seccion de datos de cuenta
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informacion de la cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Nombre'),
                        subtitle: Text(
                          _userName.isNotEmpty ? _userName : 'No especificado',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Correo electronico'),
                        subtitle: Text(_user?.email ?? 'No disponible'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Rol asignado'),
                        subtitle: Text(roleLabel),
                      ),
                      // Bloque del ID del usuario
                      if (_user != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.fingerprint),
                          title: const Text('ID de usuario'),
                          subtitle: Text(
                            _user.id.length > 12
                                ? '${_user.id.substring(0, 12)}...'
                                : _user.id,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Herramientas exclusivas para choferes
              if (isChofer) ...[
                // Compartir ubicacion del bus en tiempo real
                ChangeNotifierProvider(
                  create: (_) => DriverLocationController(),
                  child: const _ShareLocationCard(),
                ),
                const SizedBox(height: 12),

                // Escaner de pasajes
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TicketScannerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear Pasaje de Pasajero'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Modulo de contacto con proteccion de autenticacion
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final currentUser =
                        Supabase.instance.client.auth.currentUser;
                    if (currentUser == null ||
                        currentUser.email == null ||
                        currentUser.email!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'Debes iniciar sesion con una cuenta para enviar comentarios.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (_) => CommentsController(),
                          child: const CommentsScreen(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Enviar comentario o sugerencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cierre de sesion
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Cerrar Sesion',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ficha informativa de la aplicacion
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sobre Turisur',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plataforma de seguimiento en tiempo real y gestion de pasajes. '
                        'Las coordenadas de los buses son transmitidas via IoT por dispositivos T-SIM7600 '
                        'o directamente desde la app del chofer.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.gps_fixed,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Telemetria GPS activa',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.sync, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Actualizaciones en vivo por WebSockets',
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget interno: tarjeta para iniciar/detener el envio de ubicacion del bus.
// Ahora es StatefulWidget para refrescar permisos y mostrar info en vivo.
// ---------------------------------------------------------------------------
class _ShareLocationCard extends StatefulWidget {
  const _ShareLocationCard();

  @override
  State<_ShareLocationCard> createState() => _ShareLocationCardState();
}

class _ShareLocationCardState extends State<_ShareLocationCard> {
  bool _hasBgPermission = true;
  int? _autoStopMin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshState());
  }

  // Relee permiso de background y valor del auto-stop
  Future<void> _refreshState() async {
    final ctrl = context.read<DriverLocationController>();
    final ok = await ctrl.hasBackgroundPermission();
    final autoStop = await ctrl.readAutoStopMinutes();
    if (mounted) {
      setState(() {
        _hasBgPermission = ok;
        _autoStopMin = autoStop;
      });
    }
  }

  // Formatea "hace X minutos" para la ultima vez compartida
  String _formatRelative(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Hace unos segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  // Muestra un dialogo guiando al usuario a conceder el permiso en Ajustes
  Future<void> _showPermissionDialog() async {
    final ctrl = context.read<DriverLocationController>();
    final abrir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: const Text(
          'Para que la ubicacion se siga compartiendo cuando salgas de la app, '
          'debes permitir la ubicacion "Todo el tiempo".\n\n'
          'Toca "Abrir Ajustes" y luego:\n'
          '1. Permisos\n'
          '2. Ubicacion\n'
          '3. Permitir todo el tiempo',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );

    if (abrir == true) {
      await ctrl.openSystemAppSettings();
      // Espera a que el usuario vuelva y refresca el estado
      await Future.delayed(const Duration(seconds: 2));
      await _refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DriverLocationController>();
    final isSharing = ctrl.isSharing;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Icon(
                  isSharing ? Icons.gps_fixed : Icons.gps_off,
                  color: isSharing ? Colors.green : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Compartir ubicacion del bus',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Descripcion segun estado
            Text(
              isSharing
                  ? 'Transmitiendo en vivo. Los pasajeros pueden ver tu bus en el mapa.'
                  : 'Activa el GPS para que los pasajeros sigan tu recorrido en tiempo real.',
              style: TextStyle(
                  color: Colors.grey[700], fontSize: 13, height: 1.4),
            ),

            // Info: ultima vez compartido
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Ultima vez compartido: ${_formatRelative(ctrl.lastSharedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),

            // Info: hora de inicio si esta activo
            if (isSharing && ctrl.startedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Iniciado a las ${ctrl.startedAt!.toLocal().toString().substring(11, 19)}',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ],
              ),
            ],

            // Mensaje de error si algo falla
            if (ctrl.error != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ctrl.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            // Boton "Abrir Ajustes" cuando falta permiso de background
            if (!_hasBgPermission && !isSharing) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPermissionDialog,
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir Ajustes para conceder permiso'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange[800],
                    side: BorderSide(color: Colors.orange[800]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            // Selector de auto-stop
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  'Detener automaticamente:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int?>(
                    value: _autoStopMin,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    hint: const Text('Sin limite',
                        style: TextStyle(fontSize: 12)),
                    items: const [
                      DropdownMenuItem(
                          value: null,
                          child: Text('Sin limite',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 5,
                          child: Text('5 minutos',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 10,
                          child: Text('10 minutos',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 15,
                          child: Text('15 minutos',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 30,
                          child: Text('30 minutos',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 60,
                          child: Text('1 hora',
                              style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) async {
                      setState(() => _autoStopMin = v);
                      await ctrl.scheduleAutoStop(v ?? 0);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Boton principal iniciar/detener
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSharing
                    ? () async {
                        await ctrl.stopSharing();
                        await _refreshState();
                      }
                    : () async {
                        // Si no tiene permiso de background, mostramos dialogo guiado
                        if (!_hasBgPermission) {
                          await _showPermissionDialog();
                          return;
                        }

                        final ok = await ctrl.startSharing();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                ctrl.error ??
                                    'No se pudo iniciar la transmision',
                              ),
                            ),
                          );
                        }
                        await _refreshState();
                      },
                icon: Icon(isSharing ? Icons.stop_circle : Icons.play_circle),
                label: Text(
                  isSharing ? 'Detener transmision' : 'Iniciar transmision',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSharing ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}