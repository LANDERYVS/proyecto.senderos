import 'package:flutter/material.dart';

class ConfirmExitRecordingDialog extends StatelessWidget {
  const ConfirmExitRecordingDialog({
    super.key,
    required this.onCancel,
    required this.onExit,
    this.message =
        'Hay un trayecto en grabación. Si sales, se perderá la ruta actual.',
  });

  final VoidCallback onCancel;
  final VoidCallback onExit;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Seguro que quieres salir?'),
      content: Text(message),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        FilledButton(onPressed: onExit, child: const Text('Salir')),
      ],
    );
  }
}
