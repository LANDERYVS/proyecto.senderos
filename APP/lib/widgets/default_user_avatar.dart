import 'package:flutter/material.dart';

class DefaultUserAvatar extends StatelessWidget {
  const DefaultUserAvatar({super.key, this.radius = 48, this.backgroundColor});

  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      backgroundImage: const AssetImage('assets/usuario.png'),
    );
  }
}
