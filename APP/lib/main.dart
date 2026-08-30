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
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xff8cf56e),
        scaffoldBackgroundColor: const Color(0xff09100c),
      ),
      home: AuthGate(home: const HomePage()),
    );
  }
}
