import 'package:flutter/material.dart';

import 'search_field.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    this.onSearch,
    this.onDifficultyChanged,
    this.onLengthChanged,
    this.showSearchField = true,
  });

  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onDifficultyChanged;
  final ValueChanged<String>? onLengthChanged;
  final bool showSearchField;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  // Variables que guardan el estado actual de cada filtro
  String _difficulty = 'Dificultad';
  String _length = 'Longitud';

  // Listas de opciones para cada filtro
  static const _difficultyOptions = [
    'Dificultad',
    'Fácil',
    'Moderada',
    'Difícil',
  ];

  static const _lengthOptions = [
    'Longitud',
    'Menos de 3 km',
    '3 a 8 km',
    'Más de 8 km',
  ];

  /// Muestra un BottomSheet con las opciones del filtro seleccionado
  /// [filter] = valor actual del filtro
  /// [options] = lista de opciones a mostrar
  void _chooseFilter(String filter, List<String> options) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Recorre cada opción y crea un ListTile
            for (final option in options)
              ListTile(
                title: Text(option),
                // Muestra un checkmark si es la opción seleccionada
                trailing: option == filter ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    // Actualiza el valor del filtro correspondiente
                    if (options == _difficultyOptions) _difficulty = option;
                    if (options == _lengthOptions) _length = option;
                  });
                  if (options == _difficultyOptions) {
                    widget.onDifficultyChanged?.call(option);
                  } else if (options == _lengthOptions) {
                    widget.onLengthChanged?.call(option);
                  }
                  // Cierra el BottomSheet
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
        child: Column(
          children: [
            if (widget.showSearchField) ...[
              SearchField(
                onChanged: widget.onSearch,
                hintText: 'Encontrar senderos',
              ),
              const SizedBox(height: 26),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterButton(
                    label: _difficulty,
                    onPressed: () =>
                        _chooseFilter(_difficulty, _difficultyOptions),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    label: _length,
                    onPressed: () => _chooseFilter(_length, _lengthOptions),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_down, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
