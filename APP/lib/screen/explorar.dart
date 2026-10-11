// Aquí se implementa una pantalla de la app.


import 'package:flutter/material.dart';

import '../models/modelo_sendero.dart';
import '../services/obtener_sendero.dart';
import '../widgets/content_state_view.dart';
import '../widgets/sendero_card.dart';
import '../widgets/filtros.dart';
// La clase ExploreContent reúne los datos y las acciones de esta parte de la app.

class ExploreContent extends StatefulWidget {
  const ExploreContent({
    super.key,
    this.searchTerm = '',
    this.onSearchChanged,
    this.showFilters = true,
  });

  final String searchTerm;
  final ValueChanged<String>? onSearchChanged;
  final bool showFilters;

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}
// La clase _ExploreContentState reúne los datos y las acciones de esta parte de la app.

class _ExploreContentState extends State<ExploreContent> {
  final ObtenerSenderoService _trailService = ObtenerSenderoService();
  List<ExploreTrail> _trails = [];
  bool _isLoading = true;
  String? _loadError;

  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  String _sportFilter = 'Deporte';
// Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _loadTrails();
  }
// Carga los datos necesarios para mostrar la información más reciente.

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
    final query = widget.searchTerm.toLowerCase();

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
      final matchesSport =
          _sportFilter == 'Deporte' || trail.sport == _sportFilter;

      return matchesSearch &&
          matchesDifficulty &&
          matchesLength &&
          matchesSport;
    }).toList();
  }
// Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    final visibleTrails = _visibleTrails;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadTrails,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: FilterBar(
                  showSearchField: false,
                  showFilters: widget.showFilters,
                  onSearch: widget.onSearchChanged,
                  onDifficultyChanged: (value) =>
                      setState(() => _difficultyFilter = value),
                  onLengthChanged: (value) =>
                      setState(() => _lengthFilter = value),
                  onSportChanged: (value) =>
                      setState(() => _sportFilter = value),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: ContentStateView(isLoading: true),
                )
              else if (_loadError != null)
                SliverFillRemaining(
                  child: ContentStateView(
                    message: _loadError!,
                    onRetry: _loadTrails,
                  ),
                )
              else if (visibleTrails.isEmpty)
                const SliverFillRemaining(
                  child: ContentStateView(
                    message: 'No se encontraron senderos',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  sliver: SliverList.separated(
                    itemCount: visibleTrails.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final trail = visibleTrails[index];
                      return SenderoCard(trail: trail);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
