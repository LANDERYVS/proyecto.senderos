import 'package:flutter/material.dart';

Future<bool> showConfirmExitRecordingDialog({
  required BuildContext context,
  required String message,
  String title = '¿Salir sin guardar?',
  String continueLabel = 'Seguir grabando',
  String exitLabel = 'Salir y descartar',
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ConfirmExitRecordingDialog(
          title: title,
          message: message,
          continueLabel: continueLabel,
          exitLabel: exitLabel,
          onContinue: () => Navigator.pop(dialogContext, false),
          onExit: () => Navigator.pop(dialogContext, true),
        ),
      ) ??
      false;
}

class ConfirmExitRecordingDialog extends StatelessWidget {
  const ConfirmExitRecordingDialog({
    super.key,
    required this.onContinue,
    required this.onExit,
    this.title = '¿Salir sin guardar?',
    this.message =
        'La grabación sigue en curso. Si sales, perderás el recorrido.',
    this.summary,
    this.continueLabel = 'Seguir grabando',
    this.exitLabel = 'Salir y descartar',
  });

  final VoidCallback onContinue;
  final VoidCallback onExit;
  final String title;
  final String message;
  final String? summary;
  final String continueLabel;
  final String exitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: colors.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (summary != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary!,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  exitLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  continueLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
