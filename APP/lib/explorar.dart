import 'package:flutter/material.dart';
import 'filtros.dart';

class ExploreContent extends StatelessWidget {
  const ExploreContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Barra de filtros
        Expanded(child: FilterBar()),
        // Aquí irá la lista de trayectos
      ],
    );
  }
}
