import 'package:flutter/material.dart';

const navigationDestinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Explorar',
  ),
  NavigationDestination(
    icon: Icon(Icons.route_outlined),
    selectedIcon: Icon(Icons.route),
    label: 'Guardados',
  ),
  NavigationDestination(
    icon: Icon(Icons.videocam_outlined),
    selectedIcon: Icon(Icons.videocam),
    label: 'Grabar',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Amigos',
  ),
  NavigationDestination(
    icon: Icon(Icons.search_outlined),
    selectedIcon: Icon(Icons.search),
    label: 'Espectador',
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
