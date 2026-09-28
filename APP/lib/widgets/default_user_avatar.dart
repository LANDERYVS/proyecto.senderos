import 'package:flutter/material.dart';

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
    final ImageProvider<Object> resolvedImage =
        (imageUrl != null && imageUrl!.trim().isNotEmpty)
        ? NetworkImage(imageUrl!)
        : const AssetImage('assets/Logo.png');

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      backgroundImage: resolvedImage,
    );
  }
}
