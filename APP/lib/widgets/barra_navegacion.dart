import 'package:flutter/material.dart';

/*
 * Construye la barra inferior principal de la app.
 * Recibe qué pestaña está seleccionada y avisa a la pantalla cuando el usuario
 * elige otra. El icono de "Espectador" también indica si hay una ubicación
 * compartida activa.
 */
Widget buildNavigationBar({
  required int selectedIndex,
  required ValueChanged<int> onDestinationSelected,
  bool hasSharedLocation = false,
}) {
  // Define las cinco secciones y sus iconos normal/seleccionado.
  final destinations = <NavigationDestination>[
    const NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: 'Explorar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: 'Guardados',
    ),
    const NavigationDestination(
      icon: Icon(Icons.videocam_outlined),
      selectedIcon: Icon(Icons.videocam),
      label: 'Grabar',
    ),
    const NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Amigos',
    ),
    // El icono de esta pestaña refleja si hay alguien compartiendo ubicación.
    NavigationDestination(
      icon: Icon(
        hasSharedLocation
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
      selectedIcon: Icon(
        hasSharedLocation ? Icons.visibility : Icons.visibility_off,
      ),
      label: 'Espectador',
    ),
  ];

  // Evita que la barra quede debajo de la zona segura del teléfono.
  // NavigationBar mantiene marcada la pestaña actual y envía los cambios
  // mediante onDestinationSelected.
  return SafeArea(
    top: false,
    child: NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    ),
  );
}
