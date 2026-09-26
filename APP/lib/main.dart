import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screen/inicio.dart';
import 'screen/previsualizar_gpx.dart';
import 'services/gpx_open_service.dart';
import 'widgets/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://bwigvvonhdlbwlcnnoea.supabase.co',
    publishableKey: 'sb_publishable_LVcxjnDwgqPpbjMuEu3Inw_fXSgxp8I',
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final GpxOpenService _gpxOpenService;

  @override
  void initState() {
    super.initState();
    _gpxOpenService = GpxOpenService()
      ..start(onPreview: _showGpxPreview, onError: _showGpxError);
  }

  @override
  void dispose() {
    _gpxOpenService.dispose();
    super.dispose();
  }

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

  void _showGpxError(Object error) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('No se pudo abrir el archivo GPX: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'Mapa en tiempo real',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4f8f3a),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
      ),
      home: AuthGate(home: const HomePage()),
    );
  }
}
