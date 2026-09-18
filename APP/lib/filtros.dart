import 'package:flutter/material.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    this.onSearch,
    this.onDifficultyChanged,
    this.onLengthChanged,
    this.onElevationChanged,
  });

  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onDifficultyChanged;
  final ValueChanged<String>? onLengthChanged;
  final ValueChanged<String>? onElevationChanged;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  // Variables que guardan el estado actual de cada filtro
  String _difficulty = 'Dificultad';
  String _length = 'Longitud';
  String _duration = 'Duración';

  // Listas de opciones para cada filtro
  static const _difficultyOptions = [
    'Dificultad',
    'Fácil',
    'Moderada',
    'Difícil',
  ];

  static const _durationOptions = [
    'Duración',
    'Menos de 1 hora',
    '1 a 3 horas',
    'Más de 3 horas',
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
                    if (options == _durationOptions) _duration = option;
                  });
                  if (options == _difficultyOptions) {
                    widget.onDifficultyChanged?.call(option);
                  } else if (options == _lengthOptions) {
                    widget.onLengthChanged?.call(option);
                  } else if (options == _durationOptions) {
                    widget.onElevationChanged?.call(option);
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
            // Campo de búsqueda
            TextField(
              onChanged: widget.onSearch,
              decoration: InputDecoration(
                hintText: 'Encontrar senderos',
                prefixIcon: const Icon(Icons.search, size: 30),
                filled: true,
                fillColor: const Color(0xfff2f2f2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 26),
            // Barra de filtros horizontal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Botón de dificultad
                  _FilterButton(
                    label: _difficulty,
                    onPressed: () =>
                        _chooseFilter(_difficulty, _difficultyOptions),
                  ),
                  const SizedBox(width: 10),
                  // Botón de longitud
                  _FilterButton(
                    label: _length,
                    onPressed: () => _chooseFilter(_length, _lengthOptions),
                  ),
                  const SizedBox(width: 10),
                  // Botón de duración
                  _FilterButton(
                    label: _duration,
                    onPressed: () => _chooseFilter(_duration, _durationOptions),
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
