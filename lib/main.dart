// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'common/globs.dart';
import 'controllers/auth_controller.dart';
import 'helpers/location_manager.dart';
import 'services/gps_task_handler.dart';
import 'services/socket_manager.dart';
import 'views/auth/auth_screen.dart';
import 'views/main_app_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[Main] Excepcion no capturada: $error\n$stack');
    }
    return true;
  };

  await dotenv.load(fileName: '.env');
  await Globs.loadSharedPrefs();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
        'Las credenciales SUPABASE_URL y SUPABASE_ANON_KEY son requeridas en .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Inicializa el canal de comunicacion con el Foreground Service.
  // Debe llamarse antes de cualquier startService/stopService.
  FlutterForegroundTask.initCommunicationPort();

  // Configuracion del servicio en primer plano para compartir GPS en background.
  // autoRunOnBoot y autoRunOnMyPackageReplaced en false para evitar que el
  // servicio arranque solo y bloquee el startService manual del chofer.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'turisur_gps',
      channelName: 'Turisur GPS',
      channelDescription: 'Comparte la ubicacion del bus en tiempo real',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // El handler recibe onRepeatEvent cada 20 segundos.
      // Sirve como keep-alive cuando el bus esta detenido.
      eventAction: ForegroundTaskEventAction.repeat(20000),
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const MyApp());
}

// Entry point del Foreground Service.
// Debe ser top-level y estar anotado con @pragma('vm:entry-point')
// para que el motor de Flutter lo encuentre desde el isolate del servicio.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTaskHandler());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: MaterialApp(
        title: Globs.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/main': (_) => const MainAppScreen(index: 0),
          '/auth': (_) => const AuthScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _isAuthenticated = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Escucha cambios de sesion reales de Supabase
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _evaluateUser(data.session?.user);
    });

    // Evaluacion inicial
    _evaluateUser(Supabase.instance.client.auth.currentUser);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAuthenticated) {
      SocketManager.shared.initAndConnectSocket(shouldConnect: true);
    }
  }

  Future<void> _evaluateUser(User? user) async {
    // Si no hay usuario o no tiene correo electronico real
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      SocketManager.shared.disconnectSocket();
      await Globs.udRemove('user_id');
      await Globs.udRemove('email');

      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _checking = false;
        });
      }
      return;
    }

    try {
      final supa = Supabase.instance.client;
      await supa
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      final email = user.email!.trim();

      await Globs.udSetString('user_id', user.id);
      await Globs.udSetString('email', email);

      await LocationManager.shared.initialize();
      await SocketManager.shared.initAndConnectSocket(shouldConnect: true);

      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _checking = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthGate] Error durante validacion: $e');
      }
      SocketManager.shared.disconnectSocket();

      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Iniciando servicios...'),
            ],
          ),
        ),
      );
    }

    // Renderiza la vista correspondiente segun el estado sin recargar la pila
    return _isAuthenticated ? const MainAppScreen(index: 0) : const AuthScreen();
  }
}