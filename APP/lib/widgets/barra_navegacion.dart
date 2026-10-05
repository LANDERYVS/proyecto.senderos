import 'package:flutter/material.dart';

Widget buildNavigationBar({
  required int selectedIndex,
  required ValueChanged<int> onDestinationSelected,
  bool hasSharedLocation = false,
}) {
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

  return SafeArea(
    top: false,
    child: NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
    ),
  );
}
