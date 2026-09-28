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
    final ImageProvider<Object> resolvedImage =
        (normalizedUrl != null && normalizedUrl.isNotEmpty)
        ? NetworkImage(normalizedUrl)
        : const AssetImage('assets/usuario.png');

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      backgroundImage: resolvedImage,
    );
  }
}
