// Aquí comienza la aplicación y se configura su estructura general.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screen/inicio.dart';
import 'screen/previsualizar_gpx.dart';
import 'services/gpx_open_service.dart';
import 'services/tema_app.dart';
import 'services/ubicacion_app.dart';
import 'app_styles.dart';
import 'widgets/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://bwigvvonhdlbwlcnnoea.supabase.co',
    publishableKey: 'sb_publishable_LVcxjnDwgqPpbjMuEu3Inw_fXSgxp8I',
  );
  await TemaApp.load();
  await UbicacionApp.load();
  runApp(const MyApp());
}
// Configura el tema, la navegación y la pantalla inicial de la aplicación.

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}
// Mantiene la navegación global y gestiona la apertura de archivos GPX.

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final GpxOpenService _gpxOpenService;
  // Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _gpxOpenService = GpxOpenService()
      ..start(onPreview: _showGpxPreview, onError: _showGpxError);
  }
  // Al salir de esta pantalla, se cancelan las tareas activas y se liberan sus recursos.

  @override
  void dispose() {
    _gpxOpenService.dispose();
    super.dispose();
  }
  // Pregunta si se quiere abrir el archivo GPX y, si acepta, muestra su vista previa.

  Future<void> _showGpxPreview(IncomingGpxPreview preview) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final shouldOpen = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abrir GPX con la app?'),
        content: Text(
          '¿Quieres abrir "${preview.route.name}" para previsualizar la ruta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (shouldOpen != true || !navigator.mounted) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            PrevisualizarGpxScreen(file: preview.file, route: preview.route),
      ),
    );
  }
  // Informa que no se pudo abrir el archivo GPX.

  void _showGpxError(Object error) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('No se pudo abrir el archivo GPX: $error')),
    );
  }
  // Construye la aplicación con el tema elegido y la pantalla de inicio.

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppStyles.backgroundGradient(
                    Theme.of(context).brightness,
                  ),
                ),
              ),
            ),
            SafeArea(top: false, child: child ?? const SizedBox.shrink()),
          ],
        ),
        title: 'Mapa en tiempo real',
        debugShowCheckedModeBanner: false,
        theme: AppStyles.theme(Brightness.light),
        darkTheme: AppStyles.theme(Brightness.dark),
        themeMode: themeMode,
        home: AuthGate(home: const HomePage()),
      ),
    );
  }
}
