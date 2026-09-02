import 'package:flutter/material.dart';
import 'dart:io';
import 'filtros.dart';
import 'package:path_provider/path_provider.dart';

class ExploreContent extends StatefulWidget {
  const ExploreContent({super.key});

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  List<FileSystemEntity> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final directory = await getApplicationDocumentsDirectory();
    final routes =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.gpx'))
            .toList()
          ..sort(
            (first, second) =>
                second.statSync().modified.compareTo(first.statSync().modified),
          );

    if (mounted) {
      setState(() => _routes = routes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de filtros
        const FilterBar(),
        Expanded(
          child: _routes.isEmpty
              ? const Center(child: Text('No hay trayectos guardados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route = _routes[index];
                    final name = route.path.split(Platform.pathSeparator).last;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder, color: Colors.amber),
                        title: Text(name),
                        subtitle: const Text('Archivo GPX'),
                        onTap: () {},
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
