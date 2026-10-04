// lib/views/tickets/ticket_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/controllers/ticket_scanner_controller.dart';

// Pantalla para validacion de pasajes mediante lectura de codigos QR
class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen>
    with SingleTickerProviderStateMixin {
  // Controlador de camara enfocado exclusivamente en codigos QR
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );

  // Animacion de la linea de escaneo
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Valida el ticket en el backend y controla el ciclo de vida del lector
  Future<void> _handleScannedCode(
    String code,
    TicketScannerController controller,
  ) async {
    final imei = Globs.deviceUUID.isNotEmpty ? Globs.deviceUUID : 'APP_VALIDATOR';
    final isValid = await controller.validateTicket(code, busImei: imei);

    if (isValid && mounted) {
      Globs.showSuccessSnackBar(context, 'Pasaje validado con exito');
      Navigator.pop(context, true);
    } else if (mounted) {
      Globs.showErrorSnackBar(
        context,
        controller.error ?? 'No se pudo validar el pasaje',
      );

      // Breve pausa antes de reanudar el lector para evitar lecturas consecutivas erroneas
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !controller.isProcessing) {
          _scannerController.start();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TicketScannerController(),
      child: Consumer<TicketScannerController>(
        builder: (context, controller, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Escanear Pasaje'),
              actions: [
                IconButton(
                  tooltip: 'Linterna',
                  icon: const Icon(Icons.flash_on),
                  onPressed: () => _scannerController.toggleTorch(),
                ),
                IconButton(
                  tooltip: 'Cambiar camara',
                  icon: const Icon(Icons.cameraswitch_outlined),
                  onPressed: () => _scannerController.switchCamera(),
                ),
              ],
            ),
            body: Stack(
              children: [
                // Visor de camara
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (controller.isProcessing) return;

                    final codes = capture.barcodes;
                    if (codes.isEmpty) return;

                    final rawValue = codes.first.rawValue;
                    if (rawValue != null && rawValue.trim().isNotEmpty) {
                      _scannerController.stop();
                      _handleScannedCode(rawValue.trim(), controller);
                    }
                  },
                ),

                // Mascara oscura exterior
                _buildScannerOverlay(),

                // Recuadro y laser animado
                _buildAnimatedLaserLine(),

                // Bloqueo visual durante la consulta al servidor
                if (controller.isProcessing)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Validando pasaje...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Mascara con ventana central transparente
  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withAlpha(153),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recuadro delimitador y linea laser animada
  Widget _buildAnimatedLaserLine() {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Positioned(
                  top: 250 * _animationController.value,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withAlpha(128),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}