import 'package:flutter/material.dart';

const navigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Explorar',
  ),
  NavigationDestination(
    icon: Icon(Icons.map_outlined),
    selectedIcon: Icon(Icons.map),
    label: 'Mapas',
  ),
  NavigationDestination(
    icon: Icon(Icons.videocam_outlined),
    selectedIcon: Icon(Icons.videocam),
    label: 'Grabar',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Comunidad',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Perfil',
  ),
];

Widget buildNavigationBar({
  required int selectedIndex,
  required ValueChanged<int> onDestinationSelected,
}) {
  return SafeArea(
    top: false,
    child: NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: navigationDestinations,
    ),
  );
}
