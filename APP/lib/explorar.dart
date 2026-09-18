import 'package:flutter/material.dart';

import 'filtros.dart';
import 'models/explore_trail.dart';
import 'services/obtener_sendero.dart';
import 'widgets/sendero_card.dart';

class ExploreContent extends StatefulWidget {
  const ExploreContent({super.key});

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  final ObtenerSenderoService _trailService = ObtenerSenderoService();
  List<ExploreTrail> _trails = [];
  bool _isLoading = true;
  String? _loadError;

  String _searchTerm = '';
  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  String _elevationFilter = 'Desnivel positivo';

  @override
  void initState() {
    super.initState();
    _loadTrails();
  }

  Future<void> _loadTrails() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final trails = await _trailService.obtenerSenderos();
      if (!mounted) return;
      setState(() {
        _trails = trails;
        _isLoading = false;
      });
    } on ObtenerSenderoException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
      debugPrint('Error al listar senderos: ${error.cause ?? error}');
    }
  }

  List<ExploreTrail> get _visibleTrails {
    final query = _searchTerm.toLowerCase();
    return _trails.where((trail) {
      final matchesSearch =
          trail.name.toLowerCase().contains(query) ||
          trail.description.toLowerCase().contains(query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          trail.difficulty == _difficultyFilter;
      final matchesLength = switch (_lengthFilter) {
        'Menos de 3 km' => trail.distanceKm < 3,
        '3 a 8 km' => trail.distanceKm >= 3 && trail.distanceKm <= 8,
        'Más de 8 km' => trail.distanceKm > 8,
        _ => true,
      };
      final matchesElevation =
          _elevationFilter == 'Desnivel positivo' ||
          trail.elevation == _elevationFilter;
      return matchesSearch &&
          matchesDifficulty &&
          matchesLength &&
          matchesElevation;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrails = _visibleTrails;
    return Column(
      children: [
        FilterBar(
          onSearch: (value) => setState(() => _searchTerm = value),
          onDifficultyChanged: (value) =>
              setState(() => _difficultyFilter = value),
          onLengthChanged: (value) => setState(() => _lengthFilter = value),
          onElevationChanged: (value) =>
              setState(() => _elevationFilter = value),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _loadTrails)
              : visibleTrails.isEmpty
              ? const Center(child: Text('No se encontraron senderos'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: visibleTrails.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) =>
                      SenderoCard(trail: visibleTrails[index]),
                ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
