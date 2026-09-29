import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detalles_sendero.dart';

Future<RouteDetails?> showSaveRouteDialog(
  BuildContext context, {
  required String duration,
  required double distanceKm,
  required double elevationGainMeters,
}) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final imagePicker = ImagePicker();
  final photos = <XFile>[];
  var difficulty = 'Fácil';
  String? validationMessage;

  final details = await showDialog<RouteDetails>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Guardar trayecto',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _RouteSummaryMetric(
                        label: 'TIEMPO',
                        value: duration,
                      ),
                    ),
                    _summaryDivider(context),
                    Expanded(
                      child: _RouteSummaryMetric(
                        label: 'DISTANCIA',
                        value: '${distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                    _summaryDivider(context),
                    Expanded(
                      child: _RouteSummaryMetric(
                        label: 'SUBIDA',
                        value: '${elevationGainMeters.toStringAsFixed(0)} m',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej. Sendero del bosque',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Añade detalles del trayecto',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                decoration: const InputDecoration(labelText: 'Dificultad *'),
                items: const [
                  DropdownMenuItem(value: 'Fácil', child: Text('Fácil')),
                  DropdownMenuItem(
                    value: 'Intermedio',
                    child: Text('Intermedio'),
                  ),
                  DropdownMenuItem(value: 'Difícil', child: Text('Difícil')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => difficulty = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Fotos *',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Obligatoria',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final photo in photos) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(photo.path),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              tooltip: 'Quitar foto',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  setDialogState(() => photos.remove(photo)),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton.filledTonal(
                      tooltip: 'Elegir de la galería',
                      onPressed: () async {
                        final selected = await imagePicker.pickMultiImage();
                        if (selected.isNotEmpty) {
                          setDialogState(() {
                            photos.addAll(selected);
                            validationMessage = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Tomar una foto',
                      onPressed: () async {
                        final photo = await imagePicker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (photo != null) {
                          setDialogState(() {
                            photos.add(photo);
                            validationMessage = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Añade al menos una foto para guardar el trayecto.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Descartar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              if (photos.isEmpty) {
                setDialogState(
                  () => validationMessage =
                      'Debes agregar al menos una foto para guardar el sendero.',
                );
                return;
              }
              if (name.isEmpty) {
                setDialogState(
                  () =>
                      validationMessage = 'Escribe un nombre para el trayecto.',
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                RouteDetails(
                  name: name,
                  description: descriptionController.text.trim(),
                  difficulty: difficulty,
                  photos: List.of(photos),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  descriptionController.dispose();
  return details;
}

Widget _summaryDivider(BuildContext context) => Container(
  width: 1,
  height: 34,
  color: Theme.of(context).colorScheme.outlineVariant,
);

class _RouteSummaryMetric extends StatelessWidget {
  const _RouteSummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
