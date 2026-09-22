import 'package:flutter/material.dart';

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
  final IconData? icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(24),
              ),
            ),
      ),
    );
  }
}
