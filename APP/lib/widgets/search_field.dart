import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
    this.hintText = 'Buscar',
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hintText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 50),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 26),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: colors.outline, width: 1),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
        ),
      ),
    );
  }
}
