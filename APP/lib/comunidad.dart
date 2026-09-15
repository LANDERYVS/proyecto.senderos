import 'package:flutter/material.dart';

class ComunidadContent extends StatefulWidget {
  const ComunidadContent({super.key});

  @override
  State<ComunidadContent> createState() => _ComunidadContentState();
}

class _ComunidadContentState extends State<ComunidadContent> {
  final _friends = const [
    _Friend(name: 'Valentina Ruiz', username: '@valenruiz', initials: 'VR', trails: 18),
    _Friend(name: 'Mateo Silva', username: '@mateosilva', initials: 'MS', trails: 12),
    _Friend(name: 'Sofía Benítez', username: '@sofiab', initials: 'SB', trails: 9),
    _Friend(name: 'Nicolás Acosta', username: '@nicoacosta', initials: 'NA', trails: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Encuentra tu grupo',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Conecta con personas que también disfrutan salir a explorar.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o usuario',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {},
              tooltip: 'Filtros',
              icon: const Icon(Icons.tune_outlined),
            ),
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(label: 'Sugerencias', selected: true),
              _FilterChip(label: 'Cerca de mí'),
              _FilterChip(label: 'Más senderos'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Personas para seguir',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            TextButton(onPressed: () {}, child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 4),
        for (final friend in _friends) _FriendTile(friend: friend),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, size: 30, color: colors.primary),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Comparte tus senderos con tu comunidad y descubre nuevas rutas.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Friend {
  const _Friend({required this.name, required this.username, required this.initials, required this.trails});

  final String name;
  final String username;
  final String initials;
  final int trails;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {},
        showCheckmark: false,
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final _Friend friend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text(friend.initials, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${friend.username} · ${friend.trails} senderos'),
          trailing: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Agregar'),
          ),
        ),
      ),
    );
  }
}
