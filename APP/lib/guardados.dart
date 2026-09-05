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
        // Barra de filtros
        FilterBar(onSearch: (value) => setState(() => _searchTerm = value)),
        Expanded(
          child: _filteredRoutes.isEmpty
              ? const Center(child: Text('No hay trayectos guardados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredRoutes.length,
                  itemBuilder: (context, index) {
                    final route = _filteredRoutes[index];
                    final firstPhoto = route.photos.isNotEmpty
                        ? File(
                            '${route.file.parent.path}/${route.photos.first}',
                          )
                        : null;
                    return Card(
                      child: ListTile(
                        leading: firstPhoto != null && firstPhoto.existsSync()
                            ? Image.file(
                                firstPhoto,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              )
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
                          onPressed: () => _shareRoute(route),
                        ),
                        onTap: () => _shareRoute(route),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<SavedRoute> get _filteredRoutes {
    final query = _searchTerm.toLowerCase();
    return _routes.where((route) {
      return route.name.toLowerCase().contains(query) ||
          route.description.toLowerCase().contains(query);
    }).toList();
  }
}
