import 'package:flutter/material.dart';

import 'explorar.dart';
import 'grabar.dart';
import 'navegacion.dart';
import 'perfil.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 3:
        return const Center(child: Text('Comunidad'));
      default:
        return const ExploreContent();
    }
  }

  void _selectDestination(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GrabarPage()),
      );
      return;
    }
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(navigationDestinations[_selectedIndex].label),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: _buildBody(),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }
}
