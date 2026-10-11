import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/modelo_sendero.dart';
import '../screen/detalle_sendero.dart';
import 'avatar_usuario.dart';
import 'no_transition_page_route.dart';

// Tarjeta de un sendero con su imagen, información principal y acción de compartir.
class SenderoCard extends StatelessWidget {
  const SenderoCard({
    super.key,
    required this.trail,
    this.topAction,
    this.onTap,
  });

  final ExploreTrail trail;
  final Widget? topAction;
  final VoidCallback? onTap;

  Future<void> _shareTrail(BuildContext context) async {
    final shareText = [
      'Mira este sendero: ${trail.name}',
      if (trail.description.isNotEmpty) trail.description,
      'Actividad: ${trail.sport}',
      'Dificultad: ${trail.difficulty}',
      'Distancia: ${trail.distanceKm.toStringAsFixed(1)} km',
      if (trail.gpxUrl != null) 'Recorrido GPX: ${trail.gpxUrl}',
    ].join('\n');

    try {
      await SharePlus.instance.share(ShareParams(text: shareText));
    } on Exception catch (error) {
      debugPrint('No se pudo compartir el sendero: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el sendero')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Permite reemplazar la navegación predeterminada al detalle del sendero.
        onTap:
            onTap ??
            () {
              Navigator.push(
                context,
                NoTransitionPageRoute(
                  builder: (_) => DetalleSenderoScreen(trail: trail),
                ),
              );
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Superpone los datos del sendero y la acción superior sobre la fotografía.
            SizedBox(
              height: 172,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Prioriza la foto local; si no existe o falla, usa la remota o la imagen de respaldo.
                  trail.localPhotoPath != null
                      ? Image.file(
                          File(trail.localPhotoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stackTrace) => Image.asset(
                            'assets/arbol.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : trail.photoUrl == null
                      ? Image.asset('assets/arbol.jpg', fit: BoxFit.cover)
                      : Image.network(
                          trail.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stackTrace) => Image.asset(
                            'assets/arbol.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 60,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Identifica el tipo de actividad y la dificultad del recorrido.
                        _TrailInfoBadge(
                          icon: Icons.directions_walk_outlined,
                          label: trail.sport,
                          colorScheme: colorScheme,
                        ),
                        _TrailInfoBadge(
                          icon: Icons.terrain,
                          label: trail.difficulty,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (topAction != null) ...[
                          topAction!,
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          tooltip: 'Compartir sendero',
                          onPressed: () => _shareTrail(context),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            foregroundColor: colorScheme.onSurface,
                            minimumSize: const Size(44, 44),
                          ),
                          icon: const Icon(Icons.share_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Limita el título a una línea para mantener uniforme la tarjeta.
                  Text(
                    trail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (trail.description.isNotEmpty) ...[
                    // La descripción es opcional y se recorta a dos líneas.
                    Text(
                      trail.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      // Muestra quién publicó el sendero y su distancia total.
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: DefaultUserAvatar(
                          radius: 11,
                          imageUrl: trail.authorPhotoUrl,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trail.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.route_outlined,
                        size: 17,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trail.distanceKm.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Etiqueta compacta con icono para mostrar atributos como actividad o dificultad.
class _TrailInfoBadge extends StatelessWidget {
  const _TrailInfoBadge({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
