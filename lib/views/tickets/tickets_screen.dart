// lib/views/tickets/tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:turisur_app/controllers/tickets_controller.dart';

// Pantalla para listar y visualizar los pasajes adquiridos por el usuario
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TicketsController>().fetchTickets();
      }
    });
  }

  // Despliega el modal inferior con el codigo QR ampliado y detalles del viaje
  void _showTicketDetails(Map<String, dynamic> ticket) {
    final schedule = ticket['schedules'] as Map<String, dynamic>?;
    final origin = schedule?['origen'] ?? '—';
    final destination = schedule?['destino'] ?? '—';
    final day = schedule?['dia'] ?? '—';
    final time = schedule?['hora_salida'] ?? '—';
    final status = (ticket['status'] ?? '').toString().toUpperCase();
    final qrCode = (ticket['qr_code'] ?? '').toString();
    final isUsed = status == 'USED';
    final isVoided = status == 'VOIDED';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TicketDetailsSheet(
        title: '$origin → $destination',
        qrCode: qrCode,
        details: 'Dia: $day • Salida: $time\nEstado: $status',
        isUsed: isUsed,
        isVoided: isVoided,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Pasajes'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Consumer<TicketsController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      controller.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: controller.fetchTickets,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (controller.tickets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aun no tienes pasajes emitidos',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.fetchTickets(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: controller.tickets.length,
              itemBuilder: (context, index) {
                final ticket = controller.tickets[index];
                final schedule = ticket['schedules'] as Map<String, dynamic>?;

                return _buildTicketCard(ticket, schedule);
              },
            ),
          );
        },
      ),
    );
  }

  // Tarjeta individual para cada pasaje
  Widget _buildTicketCard(Map<String, dynamic> ticket, Map<String, dynamic>? schedule) {
    final origin = schedule?['origen'] ?? '—';
    final destination = schedule?['destino'] ?? '—';
    final day = schedule?['dia'] ?? '—';
    final time = schedule?['hora_salida'] ?? '—';
    final price = schedule?['precio'];
    final status = (ticket['status'] ?? '').toString().toUpperCase();
    final seat = ticket['seat_number']?.toString() ?? '—';
    final dateString = (ticket['created_at'] ?? ticket['issued_at'] ?? '').toString();
    final qrCode = (ticket['qr_code'] ?? '').toString();

    final isUsed = status == 'USED';
    final isVoided = status == 'VOIDED';
    final isInactive = isUsed || isVoided;

    final cardColor = isUsed
        ? Colors.grey[100]
        : (isVoided ? Colors.red[50] : Colors.white);
    final textColor = isInactive ? Colors.grey[600] : Colors.black87;
    final badgeColor = isUsed
        ? Colors.grey[700]!
        : (isVoided ? Colors.red[700]! : Colors.green[700]!);
    final badgeText = isUsed
        ? 'USADO'
        : (isVoided ? 'ANULADO' : 'VALIDO');

    return Card(
      elevation: isInactive ? 0 : 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isInactive
            ? BorderSide(color: Colors.grey[300]!, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTicketDetails(ticket),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Previsualizacion del codigo QR
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isInactive ? 0.35 : 1.0,
                    child: qrCode.isNotEmpty
                        ? QrImageView(
                            data: qrCode,
                            size: 64,
                            gapless: true,
                          )
                        : const Icon(Icons.qr_code_2, size: 50, color: Colors.grey),
                  ),
                  if (isUsed)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.grey[700],
                        size: 24,
                      ),
                    ),
                  if (isVoided)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cancel,
                        color: Colors.red[700],
                        size: 24,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Informacion del trayecto y horario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$origin → $destination',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                              decoration: isInactive
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dia: $day • Salida: $time',
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                    Text(
                      'Asiento: $seat',
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                    if (price != null)
                      Text(
                        'Precio: \$$price',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Emitido: ${_formatDate(dateString)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Formato local estandarizado para fechas (DD/MM/AAAA HH:MM)
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '—';
    try {
      final dateLocal = DateTime.parse(dateString).toLocal();
      final day = dateLocal.day.toString().padLeft(2, '0');
      final month = dateLocal.month.toString().padLeft(2, '0');
      final year = dateLocal.year;
      final hour = dateLocal.hour.toString().padLeft(2, '0');
      final minute = dateLocal.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return dateString;
    }
  }
}

// Modal inferior con el detalle extendido del pasaje y codigo QR de alta definicion
class _TicketDetailsSheet extends StatelessWidget {
  final String title;
  final String qrCode;
  final String details;
  final bool isUsed;
  final bool isVoided;

  const _TicketDetailsSheet({
    required this.title,
    required this.qrCode,
    required this.details,
    required this.isUsed,
    required this.isVoided,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = isUsed || isVoided;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isInactive ? Colors.grey : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (qrCode.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isInactive ? 0.25 : 1.0,
                    child: QrImageView(
                      data: qrCode,
                      size: 220,
                      gapless: true,
                    ),
                  ),
                  if (isUsed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PASAJE UTILIZADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isVoided)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'PASAJE ANULADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              )
            else
              const Icon(Icons.qr_code_2, size: 120, color: Colors.grey),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}