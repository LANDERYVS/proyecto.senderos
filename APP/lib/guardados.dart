import 'package:flutter/material.dart';
import 'dart:io';

import 'filtros.dart';
import 'models/saved_route.dart';
import 'services/saved_routes_service.dart';

class SavedContent extends StatefulWidget {
  const SavedContent({super.key});

  @override
  State<SavedContent> createState() => _SavedContentState();
}

class _SavedContentState extends State<SavedContent> {
  final SavedRoutesService _savedRoutesService = SavedRoutesService();
  List<SavedRoute> _routes = [];
  String _searchTerm = '';
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await _savedRoutesService.loadRoutes();

    if (mounted) {
      setState(() => _routes = routes);
    }
  }

  Future<void> _shareRoute(SavedRoute route) async {
    try {
      await _savedRoutesService.shareRoute(route);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el trayecto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilterBar(onSearch: (value) => setState(() => _searchTerm = value)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _tabButton(label: 'Mis senderos', index: 0)),
              Expanded(
                child: _tabButton(label: 'Senderos favoritos', index: 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredRoutes.isEmpty
              ? const Center(child: Text('No hay trayectos guardados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _filteredRoutes[index];
                    return _SavedRouteCard(
                      route: route,
                      onShare: () => _shareRoute(route),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tabButton({required String label, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  List<SavedRoute> get _filteredRoutes {
    final query = _searchTerm.toLowerCase();
    final routesForTab = _selectedTab == 0
        ? _routes.where((route) => route.isCreatedByUser).toList()
        : _routes.where((route) => route.isFavorite).toList();

    return routesForTab.where((route) {
      return route.name.toLowerCase().contains(query) ||
          route.description.toLowerCase().contains(query);
    }).toList();
  }
}

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({required this.route, required this.onShare});

  final SavedRoute route;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = route.photos.isNotEmpty
        ? File('${route.file.parent.path}/${route.photos.first}')
        : null;

    return Card(
      child: ListTile(
        leading: firstPhoto != null && firstPhoto.existsSync()
            ? Image.file(firstPhoto, width: 52, height: 52, fit: BoxFit.cover)
            : const Icon(Icons.folder, color: Colors.amber),
        title: Text(route.name),
        subtitle: Text(
          '${route.description.isNotEmpty ? '${route.description}\n' : ''}'
          '${route.difficulty} | ${route.photos.length} fotos | Archivo GPX',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Compartir trayecto',
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
        ),
        onTap: onShare,
      ),
    );
  }
}
