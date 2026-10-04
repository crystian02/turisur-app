// lib/views/schedule/horarios_screen.dart
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/controllers/schedule_controller.dart';
import '../payment/payment_screen.dart';

// Pantalla para consulta de horarios e itinerarios de viajes y compra de pasajes
class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  String? _selectedOrigin;
  String? _selectedDestination;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = context.read<ScheduleController>();
        controller.fetchUniqueLocations();
        controller.fetchSchedules();
      }
    });
  }

  // Prepara los datos del itinerario y redirige al flujo de compra con Webpay
  void _goToPayment(Map<String, dynamic> schedule) {
    final supaUser = Supabase.instance.client.auth.currentUser;

    final String userId;
    if (supaUser != null && supaUser.id.isNotEmpty) {
      userId = supaUser.id;
    } else {
      userId = Globs.udValueString('user_id');
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Debes iniciar sesion para comprar.'),
        ),
      );
      return;
    }

    final scheduleId = schedule['id']?.toString() ?? '';
    if (scheduleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Horario no valido para compra.'),
        ),
      );
      return;
    }

    final int unitPrice = (schedule['precio'] is num)
        ? (schedule['precio'] as num).round()
        : int.tryParse('${schedule['precio']}') ?? 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          userId: userId,
          scheduleId: scheduleId,
          seats: 1,
          unitPrice: unitPrice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                color: Colors.black.withAlpha(153),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildFilters(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 24,
                    ),
                    child: _buildResults(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Panel de seleccion de origen, destino y boton de filtrado
  Widget _buildFilters() {
    return Consumer<ScheduleController>(
      builder: (context, controller, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(230),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: controller.isLoadingLocations
              ? const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿De donde sales?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedOrigin,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Selecciona el origen'),
                      items: controller.origins
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedOrigin = value),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '¿A donde vas?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedDestination,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      hint: const Text('Selecciona el destino'),
                      items: controller.destinations
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedDestination = value),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedOrigin == null || _selectedDestination == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Selecciona origen y destino para buscar'),
                              ),
                            );
                            return;
                          }
                          controller.fetchSchedules(
                            origin: _selectedOrigin,
                            destination: _selectedDestination,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.search, size: 20),
                        label: const Text(
                          'Buscar Horarios',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Tarjetas informativas con los itinerarios encontrados
  Widget _buildResults() {
    return Consumer<ScheduleController>(
      builder: (context, controller, child) {
        if (controller.isLoadingSchedules) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (controller.schedules.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(210),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'No hay horarios disponibles para esta ruta',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: controller.schedules.length,
          itemBuilder: (context, index) {
            final schedule = controller.schedules[index];
            final price = (schedule['precio'] ?? 0).toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fila de ruta con icono de bus
                            Row(
                              children: [
                                const Icon(
                                  Icons.directions_bus_filled_outlined,
                                  size: 18,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SizedBox(
                                    height: 22,
                                    child: Marquee(
                                      text: '${schedule['origen']} → ${schedule['destino']}   ',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                      scrollAxis: Axis.horizontal,
                                      blankSpace: 40.0,
                                      velocity: 25.0,
                                      pauseAfterRound: const Duration(seconds: 2),
                                      startPadding: 4.0,
                                      accelerationDuration: const Duration(seconds: 1),
                                      accelerationCurve: Curves.linear,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Fila de hora de salida
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Salida: ${schedule['hora_salida'] ?? '--:--'}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // Fila de precio
                            Row(
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Precio: \$$price',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            // Fila de días de operación
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Día: ${schedule['dia'] ?? 'Todos los días'}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _goToPayment(schedule),
                        icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                        label: const Text(
                          'Comprar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}