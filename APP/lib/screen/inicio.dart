import 'package:flutter/material.dart';

import 'amigos.dart';
import 'guardados.dart';
import 'explorar.dart';
import 'grabar.dart';
import 'notificaciones.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/search_field.dart';
import 'perfil.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;
  int _communityVersion = 0;
  String _exploreSearchTerm = '';
  String _friendsSearchTerm = '';
  String _savedSearchTerm = '';

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 4);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return ExploreContent(
          searchTerm: _exploreSearchTerm,
          onSearchChanged: (value) => setState(() => _exploreSearchTerm = value),
        );
      case 1:
        return SavedContent(
          searchTerm: _savedSearchTerm,
          onSearchChanged: (value) => setState(() => _savedSearchTerm = value),
        );
      case 3:
        return AmigosContent(
          key: ValueKey('amigos-$_communityVersion'),
          searchTerm: _friendsSearchTerm,
          onSearchChanged: (value) => setState(() => _friendsSearchTerm = value),
        );
      default:
        return ExploreContent(
          searchTerm: _exploreSearchTerm,
          onSearchChanged: (value) => setState(() => _exploreSearchTerm = value),
        );
    }
  }

  Widget _buildExploreSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _exploreSearchTerm = value),
      hintText: 'Encontrar senderos',
    );
  }

  Widget _buildFriendsSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _friendsSearchTerm = value),
      hintText: 'Buscar por nombre o usuario',
    );
  }

  Widget _buildSavedSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _savedSearchTerm = value),
      hintText: 'Buscar guardados',
    );
  }

  void _selectDestination(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GrabarPage()),
      );
      return;
    }
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Widget _buildHeaderSearch() {
    if (_selectedIndex == 0) {
      return _buildExploreSearchField();
    }
    if (_selectedIndex == 1) {
      return _buildSavedSearchField();
    }
    if (_selectedIndex == 3) {
      return _buildFriendsSearchField();
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 78,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildHeaderSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Notificaciones',
                  icon: const Icon(Icons.notifications_none_outlined),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
                    );
                    if (!mounted) return;
                    setState(() => _communityVersion++);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
      ),
    );
  }
}
