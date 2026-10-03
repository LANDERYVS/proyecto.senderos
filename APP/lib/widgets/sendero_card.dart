import 'dart:io';

import 'package:flutter/material.dart';

import '../models/explore_trail.dart';
import '../screen/detalle_sendero.dart';
import 'default_user_avatar.dart';

class SenderoCard extends StatelessWidget {
  const SenderoCard({
    super.key,
    required this.trail,
    required this.isFavorite,
    required this.isSavingFavorite,
    required this.onFavorite,
    this.topAction,
    this.onTap,
  });

  final ExploreTrail trail;
  final bool isFavorite;
  final bool isSavingFavorite;
  final VoidCallback? onFavorite;
  final Widget? topAction;
  final VoidCallback? onTap;

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
        onTap:
            onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleSenderoScreen(trail: trail),
                ),
              );
            },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 172,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
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
                    child:
                        topAction ??
                        IconButton(
                          tooltip: isFavorite
                              ? 'Quitar de favoritos'
                              : 'Guardar en favoritos',
                          onPressed: onFavorite == null || isSavingFavorite
                              ? null
                              : onFavorite,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surface,
                            foregroundColor: isFavorite
                                ? colorScheme.error
                                : colorScheme.onSurface,
                            minimumSize: const Size(44, 44),
                          ),
                          icon: isSavingFavorite
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
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
