import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar cada opción de configuración
class ConfigCard extends StatelessWidget {
  const ConfigCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Theme.of(context).colorScheme.error : null,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
