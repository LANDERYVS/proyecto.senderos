import 'package:flutter/material.dart';
import 'inicio.dart';
import 'login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
