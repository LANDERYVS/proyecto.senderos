import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/saved_route.dart';

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

Future<EditedSavedRouteDetails?> showEditSavedRouteDialog(
  BuildContext context, {
  required SavedRoute route,
}) => showDialog<EditedSavedRouteDetails>(
  context: context,
  builder: (_) => _EditSavedRouteDialog(route: route),
);

class _EditSavedRouteDialog extends StatefulWidget {
  const _EditSavedRouteDialog({required this.route});

  final SavedRoute route;

  @override
  State<_EditSavedRouteDialog> createState() => _EditSavedRouteDialogState();
}

class _EditSavedRouteDialogState extends State<_EditSavedRouteDialog> {
  static const _difficulties = ['Fácil', 'Intermedio', 'Difícil'];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final GlobalKey<FormState> _formKey;
  late String _difficulty;
  XFile? _selectedPhoto;

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
    _nameController = TextEditingController(text: widget.route.name);
    _descriptionController = TextEditingController(
      text: widget.route.description,
    );
    _formKey = GlobalKey<FormState>();
    _difficulty = _difficulties.contains(widget.route.difficulty)
        ? widget.route.difficulty
        : _difficulties.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo != null && mounted) {
      setState(() => _selectedPhoto = photo);
    }
  }

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
    return AlertDialog(
      title: const Text('Editar sendero'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  if (value != null) setState(() => _difficulty = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
