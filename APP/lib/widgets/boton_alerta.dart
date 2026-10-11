import 'package:flutter/material.dart';

import '../services/compartir_ubicacion.dart';

/*
 * Botón para enviar una alerta a las personas que están viendo la ubicación
 * compartida del usuario. Al tocarlo, permite elegir la gravedad y escribir
 * un mensaje antes de enviarlo.
 */
class EnviarAlertaButton extends StatefulWidget {
  const EnviarAlertaButton({
    super.key,
    required this.sharingService,
    required this.senderoId,
  });

  final CompartirUbicacionService sharingService;
  final int? senderoId;

  @override
  State<EnviarAlertaButton> createState() => _EnviarAlertaButtonState();
}

class _EnviarAlertaButtonState extends State<EnviarAlertaButton> {
  // Mientras se envía una alerta, bloquea nuevos intentos y muestra progreso.
  bool _isSending = false;

  // Abre el formulario y, si se confirma, envía la alerta a los espectadores activos.
  Future<void> _showAlertDialog() async {
    // Si se cancela el formulario, no se envía nada.
    final draft = await showDialog<_AlertDraft>(
      context: context,
      builder: (context) => const _AlertDialog(),
    );
    if (draft == null || !mounted) return;

    setState(() => _isSending = true);
    try {
      // El servicio se encarga de entregar el aviso asociado a este sendero.
      final sentCount = await widget.sharingService.sendAlert(
        type: draft.type,
        message: draft.message,
        senderoId: widget.senderoId,
      );
      if (!mounted) return;
      // Informa si no había espectadores o cuántos recibieron la alerta.
      final resultMessage = sentCount == 0
          ? 'No hay espectadores activos para este trayecto.'
          : 'Alerta enviada a '
                '$sentCount ${sentCount == 1 ? 'espectador' : 'espectadores'}.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultMessage)));
    } on Exception catch (error) {
      // Comunica el fallo sin dejar el indicador de envío activo.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la alerta: $error')),
      );
    } finally {
      // Restablece el botón al terminar, haya salido bien o no el envío.
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El botón muestra una advertencia y cambia a un indicador mientras envía.
    return FloatingActionButton.small(
      heroTag: 'send-trail-alert-${widget.senderoId ?? 'live'}',
      tooltip: 'Enviar alerta a mis espectadores',
      onPressed: _isSending ? null : _showAlertDialog,
      backgroundColor: Colors.white,
      foregroundColor: Colors.red.shade800,
      child: _isSending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.warning_amber_rounded),
    );
  }
}

// Guarda temporalmente la gravedad y el texto confirmados en el formulario.
class _AlertDraft {
  const _AlertDraft({required this.type, required this.message});

  final String type;
  final String message;
}

// Formulario emergente para redactar una alerta antes de enviarla.
class _AlertDialog extends StatefulWidget {
  const _AlertDialog();

  @override
  State<_AlertDialog> createState() => _AlertDialogState();
}

class _AlertDialogState extends State<_AlertDialog> {
  // Conserva el mensaje escrito y el estado de validación del formulario.
  final _messageController = TextEditingController();
  String _type = 'Aviso';
  String? _validationMessage;

  @override
  void dispose() {
    // Libera el controlador del campo de texto al cerrar el diálogo.
    _messageController.dispose();
    super.dispose();
  }

  // No permite enviar un mensaje vacío; si es válido, devuelve el borrador al botón.
  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _validationMessage = 'Escribe el mensaje de la alerta.');
      return;
    }
    Navigator.pop(context, _AlertDraft(type: _type, message: message));
  }

  @override
  Widget build(BuildContext context) {
    // Presenta la gravedad, el campo de mensaje y las acciones cancelar/enviar.
    return AlertDialog(
      title: const Text('Enviar alerta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Gravedad'),
            items: const [
              DropdownMenuItem(value: 'Aviso', child: Text('Aviso')),
              DropdownMenuItem(value: 'Moderada', child: Text('Moderada')),
              DropdownMenuItem(value: 'Peligro', child: Text('Peligro')),
            ],
            // Guarda la gravedad elegida para incluirla en la alerta.
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            autofocus: true,
            maxLength: 240,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              hintText: 'Ej. Me separé del grupo en el tramo final.',
              border: OutlineInputBorder(),
            ),
          ),
          if (_validationMessage != null)
            // Muestra el motivo por el que no se pudo continuar.
            Text(
              _validationMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        // Cierra el formulario sin enviar la alerta.
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        // Valida el mensaje y devuelve los datos para iniciar el envío.
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('Enviar'),
        ),
      ],
    );
  }
}
