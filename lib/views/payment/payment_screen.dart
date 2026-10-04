// lib/views/payment/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:turisur_app/common/globs.dart';
import 'package:turisur_app/controllers/payment_controller.dart';

// Pantalla para procesamiento de pagos con pasarela Webpay mediante WebView embebido
class PaymentScreen extends StatefulWidget {
  final String userId;
  final String scheduleId;
  final int seats;
  final int unitPrice;

  const PaymentScreen({
    super.key,
    required this.userId,
    required this.scheduleId,
    this.seats = 1,
    required this.unitPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _webViewController;
  late final PaymentController _paymentController;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _paymentController = PaymentController();
    _webViewController = WebViewController();
    _initializePayment();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  // Crea la orden de compra e inyecta el formulario POST hacia Webpay
  Future<void> _initializePayment() async {
    try {
      final paymentData = await _paymentController.initializePayment(
        userId: widget.userId,
        scheduleId: widget.scheduleId,
        seats: widget.seats,
        unitPrice: widget.unitPrice,
      );

      final String url = paymentData['url']?.toString() ?? '';
      final String token = paymentData['token']?.toString() ?? '';

      if (url.isEmpty || token.isEmpty) {
        throw Exception('Datos de conexion con la pasarela invalidos.');
      }

      final html = '''
        <!doctype html>
        <html lang="es">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <style>
              body {
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                background-color: #ffffff;
                color: #333333;
              }
            </style>
          </head>
          <body onload="document.forms[0].submit()">
            <p>Conectando con Webpay Plus...</p>
            <form action="$url" method="POST">
              <input type="hidden" name="token_ws" value="$token" />
            </form>
          </body>
        </html>
      ''';

      _webViewController
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              final uri = Uri.parse(request.url);

              if (uri.scheme == Globs.appScheme) {
                debugPrint('[PaymentWebView] Retorno interceptado: $uri');
                _paymentController.handleDeepLinkResult(uri);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onWebResourceError: (error) {
              debugPrint(
                  '[PaymentWebView] Error de recurso: ${error.description}');
            },
          ),
        )
        ..loadHtmlString(html);

      if (mounted) {
        setState(() {
          _isWebViewReady = true;
        });
      }

      _paymentController.startDeepLinkListening();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error al conectar con la pasarela: $e'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _paymentController,
      builder: (context, _) {
        // Vista de confirmacion de compra exitosa
        if (_paymentController.isFinished) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pago Exitoso'),
              automaticallyImplyLeading: false,
              centerTitle: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 90, color: Colors.green),
                    const SizedBox(height: 24),
                    const Text(
                      'Compra realizada con exito!',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tus pasajes han sido emitidos y ya estan disponibles en tu seccion de pasajes.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text('Volver al Inicio',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Vista de error o pago cancelado
        if (_paymentController.error != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pago no completado'),
              centerTitle: true,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Colors.redAccent),
                    const SizedBox(height: 20),
                    Text(
                      _paymentController.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // WebView en proceso de pago
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pago Webpay'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Stack(
            children: [
              if (_isWebViewReady)
                WebViewWidget(controller: _webViewController),
              if (_paymentController.isLoading || !_isWebViewReady)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }
}