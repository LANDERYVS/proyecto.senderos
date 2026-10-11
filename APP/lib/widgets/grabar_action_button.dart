import 'package:flutter/material.dart';

// Botón ancho para iniciar, pausar o finalizar una acción de grabación.
class GrabarActionButton extends StatelessWidget {
  const GrabarActionButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style,
  });

  final bool isRecording;
  final VoidCallback onPressed;
  final String label;
  // Si no se pasa un icono, usa el de reproducción.
  final IconData? icon;
  // Permite reemplazar el estilo predeterminado desde la pantalla que lo utiliza.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    // Ocupa el ancho disponible y cambia a rojo mientras hay una grabación activa.
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.play_arrow, size: 18),
        label: Text(label),
        style:
            style ??
            ElevatedButton.styleFrom(
              backgroundColor: isRecording ? Colors.red.shade700 : null,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
      ),
    );
  }
}
