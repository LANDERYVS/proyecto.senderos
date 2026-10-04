import 'package:flutter/material.dart';

import '../models/explore_trail.dart';

class DefaultUserAvatar extends StatelessWidget {
  const DefaultUserAvatar({
    super.key,
    this.radius = 48,
    this.backgroundColor,
    this.imageUrl,
  });

  final double radius;
  final Color? backgroundColor;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = ExploreTrail.publicR2Url(imageUrl?.trim());
    final image = normalizedUrl != null && normalizedUrl.isNotEmpty
        ? Image.network(
            normalizedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/usuario.png',
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            ),
          )
        : Image.asset(
            'assets/usuario.png',
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          );

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      child: ClipOval(child: image),
    );
  }
}
