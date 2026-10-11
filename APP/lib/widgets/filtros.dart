import 'package:flutter/material.dart';

import 'barra_busqueda.dart';

/*
 * Barra reutilizable para buscar senderos y filtrarlos por dificultad,
 * distancia o deporte.
 * Notifica a la pantalla que la contiene cuando el usuario cambia la búsqueda
 * o selecciona un filtro.
 */
class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    this.onSearch,
    this.onDifficultyChanged,
    this.onLengthChanged,
    this.onSportChanged,
    this.showSearchField = true,
    this.showFilters = true,
  });

  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onDifficultyChanged;
  final ValueChanged<String>? onLengthChanged;
  final ValueChanged<String>? onSportChanged;
  final bool showSearchField;
  final bool showFilters;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  // Selecciones actuales; el texto inicial significa que todavía no se filtró.
  String _difficulty = 'Dificultad';
  String _length = 'Distancia';
  String _sport = 'Deporte';
  // Permite mostrar los filtros al tocar el campo de búsqueda.
  bool _filtersExpanded = false;

  // Opciones que se muestran al abrir el filtro de dificultad.
  static const _difficultyOptions = [
    'Dificultad',
    'Fácil',
    'Moderada',
    'Difícil',
  ];

  // Opciones que se muestran al abrir el filtro de distancia.
  static const _lengthOptions = [
    'Distancia',
    'Menos de 3 km',
    '3 a 8 km',
    'Más de 8 km',
  ];

  // Opciones disponibles en el filtro de deporte.
  static const _sportOptions = [
    'Deporte',
    'Senderismo',
    'Ciclismo',
    'Trekking',
    'Otro',
  ];

  // Abre un panel inferior con las opciones disponibles para el filtro elegido.
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
            // El título cambia según el tipo de filtro seleccionado.
            ListTile(
              title: Text(
                options == _difficultyOptions
                    ? 'Dificultad del sendero'
                    : options == _lengthOptions
                    ? 'Distancia del sendero'
                    : 'Deporte del sendero',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            // Cada fila representa una opción que el usuario puede seleccionar.
            for (final option in options)
              ListTile(
                selected: option == filter,
                title: Text(option),
                // Marca visualmente la opción que ya está activa.
                trailing: option == filter
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selectedColor: Theme.of(context).colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                onTap: () {
                  // Guarda en el widget la nueva selección.
                  setState(() {
                    if (options == _difficultyOptions) _difficulty = option;
                    if (options == _lengthOptions) _length = option;
                    if (options == _sportOptions) _sport = option;
                  });
                  // Avisa a la pantalla contenedora para que filtre sus resultados.
                  if (options == _difficultyOptions) {
                    widget.onDifficultyChanged?.call(option);
                  } else if (options == _lengthOptions) {
                    widget.onLengthChanged?.call(option);
                  } else if (options == _sportOptions) {
                    widget.onSportChanged?.call(option);
                  }
                  // Cierra el panel después de aplicar la selección.
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
    // Los filtros aparecen si se habilitaron desde fuera o si se expandieron al buscar.
    final filtersVisible = widget.showFilters || _filtersExpanded;
    final colorScheme = Theme.of(context).colorScheme;

    // Organiza el campo de búsqueda y los filtros horizontales.
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(90)),
        ),
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
            // El campo es opcional; al tocarlo se despliegan también los filtros.
            if (widget.showSearchField) ...[
              BarraBusqueda(
                onChanged: widget.onSearch,
                onTap: () => setState(() => _filtersExpanded = true),
                hintText: 'Encontrar senderos',
              ),
              if (filtersVisible) const SizedBox(height: 12),
            ],
            // Los botones abren los paneles para elegir los criterios de filtro.
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
                    const SizedBox(width: 10),
                    _FilterButton(
                      label: _sport,
                      isSelected: _sport != _sportOptions.first,
                      onPressed: () => _chooseFilter(_sport, _sportOptions),
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

// Botón visual de un filtro; resalta su aspecto cuando tiene una opción aplicada.
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
    // Muestra la opción actual y abre su selector cuando el usuario lo toca.
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
            : Colors.transparent,
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
