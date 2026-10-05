import 'package:flutter/material.dart';

import 'search_field.dart';

class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    this.onSearch,
    this.onDifficultyChanged,
    this.onLengthChanged,
    this.showSearchField = true,
    this.showFilters = true,
  });

  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onDifficultyChanged;
  final ValueChanged<String>? onLengthChanged;
  final bool showSearchField;
  final bool showFilters;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  // Variables que guardan el estado actual de cada filtro
  String _difficulty = 'Dificultad';
  String _length = 'Longitud';
  bool _filtersExpanded = false;

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
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                options == _difficultyOptions
                    ? 'Dificultad del sendero'
                    : 'Distancia del sendero',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            // Recorre cada opción y crea un ListTile
            for (final option in options)
              ListTile(
                selected: option == filter,
                title: Text(option),
                // Muestra un checkmark si es la opción seleccionada
                trailing: option == filter
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selectedColor: Theme.of(context).colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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
    final filtersVisible = widget.showFilters || _filtersExpanded;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          widget.showSearchField || filtersVisible ? 12 : 0,
          16,
          filtersVisible ? 12 : 0,
        ),
        child: Column(
          children: [
            if (widget.showSearchField) ...[
              SearchField(
                onChanged: widget.onSearch,
                onTap: () => setState(() => _filtersExpanded = true),
                hintText: 'Encontrar senderos',
              ),
              if (filtersVisible) const SizedBox(height: 12),
            ],
            if (filtersVisible)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterButton(
                      label: _difficulty,
                      isSelected: _difficulty != _difficultyOptions.first,
                      onPressed: () =>
                          _chooseFilter(_difficulty, _difficultyOptions),
                    ),
                    const SizedBox(width: 10),
                    _FilterButton(
                      label: _length,
                      isSelected: _length != _lengthOptions.first,
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
  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_down, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        backgroundColor: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surface,
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
