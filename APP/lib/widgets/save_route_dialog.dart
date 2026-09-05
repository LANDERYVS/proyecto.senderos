import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detalles_sendero.dart';

Future<RouteDetails?> showSaveRouteDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final imagePicker = ImagePicker();
  final photos = <XFile>[];
  var difficulty = 'Fácil';

  final details = await showDialog<RouteDetails>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Guardar trayecto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Añade detalles del trayecto',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: difficulty,
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
              const SizedBox(height: 16),
              Text('Fotos', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final photo in photos)
                    Stack(
                      children: [
                        Image.file(
                          File(photo.path),
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => photos.remove(photo)),
                            child: const CircleAvatar(
                              radius: 11,
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  IconButton.filledTonal(
                    tooltip: 'Elegir de la galería',
                    onPressed: () async {
                      final selected = await imagePicker.pickMultiImage();
                      if (selected.isNotEmpty) {
                        setDialogState(() => photos.addAll(selected));
                      }
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Tomar una foto',
                    onPressed: () async {
                      final photo = await imagePicker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (photo != null) {
                        setDialogState(() => photos.add(photo));
                      }
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  descriptionController.dispose();
  return details;
}
