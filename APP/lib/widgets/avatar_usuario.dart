import 'package:flutter/material.dart';

import '../models/modelo_sendero.dart';

/*
 * Avatar circular reutilizable para mostrar la foto de perfil.
 * Recibe una URL opcional, la prepara para que pueda cargarse desde R2 y usa
 * assets/usuario.png como alternativa si no hay foto o falla la descarga.
 */
class DefaultUserAvatar extends StatelessWidget {
  const DefaultUserAvatar({
    super.key,
    this.radius = 48,
    this.backgroundColor,
    this.imageUrl,
  });

  // Radio del avatar; el tamaño de la imagen se calcula a partir de este valor.
  final double radius;

  // Fondo opcional que se ve detrás de la imagen.
  final Color? backgroundColor;

  // Dirección de la foto de perfil. Puede ser una URL o una ruta de R2.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Convierte rutas de R2 en una dirección pública y quita espacios sobrantes.
    final normalizedUrl = ExploreTrail.publicR2Url(imageUrl?.trim());

    // Prioriza la foto de perfil; si no existe o no carga, muestra el avatar local.
    final image = normalizedUrl != null && normalizedUrl.isNotEmpty
        ? Image.network(
            normalizedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            // Reemplaza la imagen de red si ocurre un error al descargarla.
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

    // Recorta la imagen en forma circular y aplica el tamaño y fondo configurados.
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.transparent,
      child: ClipOval(child: image),
    );
  }
}
