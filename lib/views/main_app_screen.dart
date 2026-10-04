// lib/views/main_app_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/controllers/auth_controller.dart';
import 'package:turisur_app/controllers/schedule_controller.dart';
import 'package:turisur_app/controllers/tickets_controller.dart';
import 'package:turisur_app/services/socket_manager.dart';
import 'package:turisur_app/views/map_screen.dart';
import 'package:turisur_app/views/profile_screen.dart';
import 'package:turisur_app/views/schedule/horarios_screen.dart';
import 'package:turisur_app/views/tickets/tickets_screen.dart';

// Pantalla contenedora principal de la aplicación con barra de navegación inferior
class MainAppScreen extends StatefulWidget {
  final int index;

  const MainAppScreen({super.key, this.index = 0});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.index;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  // Cierre de sesión coordinado: socket, limpieza local y Supabase
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // 1. Desconectar canal de WebSockets
    try {
      SocketManager.shared.disconnectSocket();
    } catch (_) {}

    // 2. Limpieza de datos en preferencias compartidas
    await Globs.udRemove('user_id');
    await Globs.udRemove('email');

    // 3. Restablecer el estado del controlador de autenticación
    if (mounted) {
      final auth = Provider.of<AuthController>(context, listen: false);
      auth.clearError();
      auth.forceStopLoading();
    }

    // 4. Cerrar la sesión activa en Supabase Auth
    // AuthGate (en lib/main.dart) reacciona automáticamente al evento signedOut y muestra AuthScreen
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[MainAppScreen] Error al cerrar sesión en Supabase: $e');
    }
  }

  // Barra de navegación inferior flotante con bordes redondeados
  Widget _buildCustomBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(38),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        child: Container(
          height: 90,
          color: Colors.white.withAlpha(245),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                imagePath: 'assets/icon/iconHorarios.png',
                index: 0,
              ),
              _buildNavItem(
                imagePath: 'assets/icon/iconMap.png',
                index: 1,
              ),
              _buildNavItem(
                imagePath: 'assets/icon/iconTicket.png',
                index: 2,
              ),
              _buildNavItem(
                imagePath: 'assets/icon/iconPerfil.png',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Elemento interactivo individual de la barra con feedback de escala
  Widget _buildNavItem({
    required String imagePath,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 90,
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: Image.asset(
                imagePath,
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported_outlined, color: Colors.grey);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Image.asset('assets/logoRMV.png', height: 40, fit: BoxFit.contain),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F1F1),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _signOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      // IndexedStack preserva el estado de cada vista al alternar entre pestañas
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChangeNotifierProvider(
            create: (_) => ScheduleController(),
            child: const HorariosScreen(),
          ),
          const MapScreen(key: ValueKey('map_screen')),
          ChangeNotifierProvider(
            create: (_) => TicketsController(),
            child: const TicketsScreen(),
          ),
          ProfileScreen(onSignOut: _signOut),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );
  }
}
