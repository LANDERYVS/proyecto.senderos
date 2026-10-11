import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/modelo_ruta.dart';

// Contiene los cambios hechos en el diálogo para devolverlos a la pantalla.
class EditedSavedRouteDetails {
  const EditedSavedRouteDetails({
    required this.name,
    required this.description,
    required this.difficulty,
    this.photo,
  });

  final String name;
  final String description;
  final String difficulty;
  final XFile? photo;
}

// Abre el formulario de edición y devuelve los cambios al guardarlo.
// Si se cancela, devuelve null.
Future<EditedSavedRouteDetails?> showEditSavedRouteDialog(
  BuildContext context, {
  required SavedRoute route,
}) => showDialog<EditedSavedRouteDetails>(
  context: context,
  builder: (_) => _EditSavedRouteDialog(route: route),
);

// Formulario emergente que permite modificar los datos de una ruta guardada.
class _EditSavedRouteDialog extends StatefulWidget {
  const _EditSavedRouteDialog({required this.route});

  final SavedRoute route;

  @override
  State<_EditSavedRouteDialog> createState() => _EditSavedRouteDialogState();
}

class _EditSavedRouteDialogState extends State<_EditSavedRouteDialog> {
  // Opciones válidas para la dificultad que puede seleccionar el usuario.
  static const _difficulties = ['Fácil', 'Moderada', 'Difícil'];

  // Controlan el texto de los campos y la validación del formulario.
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final GlobalKey<FormState> _formKey;

  // Valores que pueden cambiar mientras el diálogo está abierto.
  late String _difficulty;
  XFile? _selectedPhoto;

  // Busca la primera foto que ya estaba guardada junto a la ruta.
  File? get _existingPhoto {
    if (widget.route.photos.isEmpty) return null;
    return File(
      '${widget.route.file.parent.path}${Platform.pathSeparator}'
      '${widget.route.photos.first}',
    );
  }

  @override
  void initState() {
    super.initState();
    // Rellena el formulario con los datos actuales de la ruta.
    _nameController = TextEditingController(text: widget.route.name);
    _descriptionController = TextEditingController(
      text: widget.route.description,
    );
    _formKey = GlobalKey<FormState>();
    _difficulty = switch (widget.route.difficulty) {
      'Intermedio' || 'Moderado' => 'Moderada',
      final difficulty when _difficulties.contains(difficulty) => difficulty,
      _ => _difficulties.first,
    };
  }

  @override
  void dispose() {
    // Libera los controladores de texto cuando se cierra el diálogo.
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Abre la galería para elegir una foto nueva para la ruta.
  Future<void> _selectPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null && mounted) {
      setState(() => _selectedPhoto = photo);
    }
  }

  // Valida el nombre y devuelve los cambios a quien abrió el diálogo.
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      EditedSavedRouteDetails(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        difficulty: _difficulty,
        photo: _selectedPhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingPhoto = _existingPhoto;
    // Muestra la foto actual o la nueva, los campos editables y las acciones.
    return AlertDialog(
      title: const Text('Editar sendero'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prioriza la foto recién elegida; si no hay, muestra la foto guardada.
              Row(
                children: [
                  if (_selectedPhoto != null)
                    Image.file(
                      File(_selectedPhoto!.path),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  else if (existingPhoto != null && existingPhoto.existsSync())
                    Image.file(
                      existingPhoto,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    )
                  else
                    const SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(Icons.image_outlined, size: 32),
                    ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Cambiar foto',
                    onPressed: _selectPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                // El nombre es obligatorio para poder guardar la edición.
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre'
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Dificultad'),
                items: _difficulties
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  // Actualiza la dificultad elegida para reflejarla en el formulario.
                  if (value != null) setState(() => _difficulty = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Cierra el diálogo sin devolver cambios.
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        // Valida y devuelve los nuevos datos a la pantalla que abrió el formulario.
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
