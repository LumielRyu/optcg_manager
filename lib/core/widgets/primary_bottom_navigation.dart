import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrimaryBottomNavigation extends StatelessWidget {
  final String currentRoute;

  const PrimaryBottomNavigation({
    super.key,
    required this.currentRoute,
  });

  static const _routes = <String>[
    '/home',
    '/collection',
    '/sales',
    '/library',
  ];

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 900;
  }

  int _selectedIndex() {
    final normalized = _routes.contains(currentRoute) ? currentRoute : '/home';
    return _routes.indexOf(normalized);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile(context)) {
      return const SizedBox.shrink();
    }

    return NavigationBar(
      selectedIndex: _selectedIndex(),
      onDestinationSelected: (index) {
        final target = _routes[index];
        if (target == currentRoute) return;
        context.go(target);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.collections_bookmark_outlined),
          selectedIcon: Icon(Icons.collections_bookmark),
          label: 'Coleção',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Vendas',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories),
          label: 'Biblioteca',
        ),
      ],
    );
  }
}
