import 'package:flutter/material.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({super.key});

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  // Variables que guardan el estado actual de cada filtro
  String _difficulty = 'Dificultad';
  String _length = 'Longitud';
  String _elevation = 'Desnivel positivo';

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
  static const _elevationOptions = [
    'Desnivel positivo',
    'Bajo',
    'Medio',
    'Alto',
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
                    if (options == _elevationOptions) _elevation = option;
                  });
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
                  // Botón de filtros general (ícono de tunning)
                  _FilterButton(icon: Icons.tune, label: '', onPressed: () {}),
                  const SizedBox(width: 10),
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
                  // Botón de desnivel
                  _FilterButton(
                    label: _elevation,
                    onPressed: () =>
                        _chooseFilter(_elevation, _elevationOptions),
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
  const _FilterButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.keyboard_arrow_down, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(icon == null ? 0 : 80, 56),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
