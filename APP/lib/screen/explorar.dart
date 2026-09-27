import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_trail.dart';
import '../services/obtener_sendero.dart';
import '../services/senderos_favoritos.dart';
import '../services/senderos_locales.dart';
import '../widgets/sendero_card.dart';
import '../widgets/filtros.dart';

class ExploreContent extends StatefulWidget {
  const ExploreContent({
    super.key,
    this.searchTerm = '',
    this.onSearchChanged,
  });

  final String searchTerm;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  final ObtenerSenderoService _trailService = ObtenerSenderoService();
  final SenderosFavoritosService _favoritesService = SenderosFavoritosService();
  final SenderosLocalesService _savedRoutesService = SenderosLocalesService();
  List<ExploreTrail> _trails = [];
  final Set<int> _favoriteIds = {};
  final Set<int> _savingFavoriteIds = {};
  bool _isLoading = true;
  String? _loadError;

  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  bool _showOnlyMyTrails = false;

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
      Set<int> favoriteIds = {};
      String? favoritesError;
      try {
        favoriteIds = await _favoritesService.loadFavoriteIds();
      } on Exception catch (error) {
        favoritesError = error.toString();
        debugPrint('Error al cargar favoritos: $error');
      }
      if (!mounted) return;
      setState(() {
        _trails = trails;
        _favoriteIds
          ..clear()
          ..addAll(favoriteIds);
        _isLoading = false;
      });
      if (favoritesError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron sincronizar favoritos')),
        );
      }
    } on ObtenerSenderoException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
      debugPrint('Error al listar senderos: ${error.cause ?? error}');
    }
  }

  Future<void> _toggleFavorite(ExploreTrail trail) async {
    final senderoId = trail.id;
    if (senderoId == null) return;
    final wasFavorite = _favoriteIds.contains(senderoId);
    setState(() => _savingFavoriteIds.add(senderoId));

    try {
      if (wasFavorite) {
        await _favoritesService.removeFavorite(senderoId);
        try {
          await _savedRoutesService.removeFavoriteCache(trail);
        } on Exception catch (error) {
          debugPrint(
            'No se pudo actualizar la copia local del favorito: $error',
          );
        }
      } else {
        await _favoritesService.addFavorite(senderoId);
        try {
          await _savedRoutesService.saveFavorite(trail);
        } on Exception catch (error) {
          debugPrint(
            'No se pudo descargar la copia local del favorito: $error',
          );
        }
      }
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteIds.remove(senderoId);
        } else {
          _favoriteIds.add(senderoId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite
                ? '"${trail.name}" quitado de favoritos'
                : '"${trail.name}" guardado en favoritos',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el sendero: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingFavoriteIds.remove(senderoId));
    }
  }

  List<ExploreTrail> get _visibleTrails {
    final query = widget.searchTerm.toLowerCase();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

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
      final matchesOwner =
          !_showOnlyMyTrails ||
          (currentUserId != null && trail.userId == currentUserId);

      return matchesSearch &&
          matchesDifficulty &&
          matchesLength &&
          matchesOwner;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrails = _visibleTrails;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FilterBar(
                showSearchField: false,
                onSearch: widget.onSearchChanged,
                onDifficultyChanged: (value) =>
                    setState(() => _difficultyFilter = value),
                onLengthChanged: (value) =>
                    setState(() => _lengthFilter = value),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              SliverFillRemaining(
                child: _ErrorState(
                  message: _loadError!,
                  onRetry: _loadTrails,
                ),
              )
            else if (visibleTrails.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No se encontraron senderos')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                sliver: SliverList.separated(
                  itemCount: visibleTrails.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final trail = visibleTrails[index];
                    final senderoId = trail.id;
                    return SenderoCard(
                      trail: trail,
                      isFavorite:
                          senderoId != null && _favoriteIds.contains(senderoId),
                      isSavingFavorite:
                          senderoId != null && _savingFavoriteIds.contains(senderoId),
                      onFavorite: senderoId == null
                          ? null
                          : () => _toggleFavorite(trail),
                    );
                  },
                ),
              ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () =>
                setState(() => _showOnlyMyTrails = !_showOnlyMyTrails),
            icon: Icon(_showOnlyMyTrails ? Icons.person_off : Icons.person),
            label: Text(_showOnlyMyTrails ? 'Todos' : 'Mis senderos'),
            backgroundColor: _showOnlyMyTrails
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFBDF2C6),
            foregroundColor: _showOnlyMyTrails
                ? Colors.white
                : const Color(0xFF1B3A2F),
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
