class Logro {
  const Logro({
    required this.id,
    required this.name,
    required this.description,
    required this.requirement,
    required this.target,
  });

  factory Logro.fromMap(
    Map<String, dynamic> map, {
    int? totalAchievements,
  }) {
    final requirement = map['requisito']?.toString().trim() ?? '';
    final isAllAchievements = requirement.toLowerCase() == 'todos_los_logros';
    return Logro(
      id: (map['id'] as num).toInt(),
      name: map['nombre']?.toString() ?? 'Logro',
      description: map['descripcion']?.toString() ?? '',
      requirement: requirement,
      target: isAllAchievements && totalAchievements != null
          ? (totalAchievements - 1).toDouble()
          : (map['valor_logro'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final String name;
  final String description;
  final String requirement;
  final double target;

  String? get metricKey => switch (requirement.toLowerCase()) {
    'senderos_publicados' || 'rutas_publicadas' => 'senderos_publicados',
    'distancia_km' || 'distancia_total_km' => 'distancia_km',
    'waypoints' || 'waypoints_guardados' => 'waypoints',
    'amigos' => 'amigos',
    'espectador' => 'espectador',
    'todos_los_logros' => 'todos_los_logros',
    _ => null,
  };
}
