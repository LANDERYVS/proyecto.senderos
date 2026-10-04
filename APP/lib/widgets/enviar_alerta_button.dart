import 'package:flutter/material.dart';

import '../services/compartir_ubicacion.dart';

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
  bool _isSending = false;

  Future<void> _showAlertDialog() async {
    final draft = await showDialog<_AlertDraft>(
      context: context,
      builder: (context) => const _AlertDialog(),
    );
    if (draft == null || !mounted) return;

    setState(() => _isSending = true);
    try {
      final sentCount = await widget.sharingService.sendAlert(
        type: draft.type,
        message: draft.message,
        senderoId: widget.senderoId,
      );
      if (!mounted) return;
      final resultMessage = sentCount == 0
          ? 'No hay espectadores activos para este trayecto.'
          : 'Alerta enviada a '
                '$sentCount ${sentCount == 1 ? 'espectador' : 'espectadores'}.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultMessage)));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la alerta: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

class _AlertDraft {
  const _AlertDraft({required this.type, required this.message});

  final String type;
  final String message;
}

class _AlertDialog extends StatefulWidget {
  const _AlertDialog();

  @override
  State<_AlertDialog> createState() => _AlertDialogState();
}

class _AlertDialogState extends State<_AlertDialog> {
  final _messageController = TextEditingController();
  String _type = 'Aviso';
  String? _validationMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _validationMessage = 'Escribe el mensaje de la alerta.');
      return;
    }
    Navigator.pop(
      context,
      _AlertDraft(type: _type, message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              _validationMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send),
          label: const Text('Enviar'),
        ),
      ],
    );
  }
}
