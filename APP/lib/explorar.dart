import 'package:flutter/material.dart';

import 'filtros.dart';

class ExploreContent extends StatefulWidget {
  const ExploreContent({super.key});

  @override
  State<ExploreContent> createState() => _ExploreContentState();
}

class _ExploreContentState extends State<ExploreContent> {
  static const _trails = [
    _ExploreTrail(
      name: 'Bosque de la Primavera',
      description: 'Sendero entre pinos y miradores naturales',
      difficulty: 'Fácil',
      length: '8.4 km',
      elevation: 'Alto',
    ),
    _ExploreTrail(
      name: 'Cañón de Huentitán',
      description: 'Recorrido con vistas y desnivel moderado',
      difficulty: 'Moderada',
      length: '5.7 km',
      elevation: 'Medio',
    ),
    _ExploreTrail(
      name: 'Cerro del Tepopote',
      description: 'Ascenso exigente con vista panorámica',
      difficulty: 'Difícil',
      length: '10.2 km',
      elevation: 'Alto',
    ),
  ];

  String _searchTerm = '';
  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  String _elevationFilter = 'Desnivel positivo';

  @override
  Widget build(BuildContext context) {
    final visibleTrails = _trails.where((trail) {
      final query = _searchTerm.toLowerCase();
      final matchesSearch =
          trail.name.toLowerCase().contains(query) ||
          trail.description.toLowerCase().contains(query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          trail.difficulty == _difficultyFilter;
      final distance = double.parse(trail.length.split(' ').first);
      final matchesLength = switch (_lengthFilter) {
        'Menos de 3 km' => distance < 3,
        '3 a 8 km' => distance >= 3 && distance <= 8,
        'Más de 8 km' => distance > 8,
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
          child: visibleTrails.isEmpty
              ? const Center(child: Text('No se encontraron senderos'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: visibleTrails.length,
                  itemBuilder: (context, index) {
                    final trail = visibleTrails[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trail.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trail.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffeaf5df),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(
                                    'assets/arbol.jpg',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      trail.difficulty,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(trail.length),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExploreTrail {
  const _ExploreTrail({
    required this.name,
    required this.description,
    required this.difficulty,
    required this.length,
    required this.elevation,
  });

  final String name;
  final String description;
  final String difficulty;
  final String length;
  final String elevation;
}
