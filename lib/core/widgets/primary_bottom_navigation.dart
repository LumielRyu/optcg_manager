import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrimaryBottomNavigation extends StatelessWidget {
  final String currentRoute;

  const PrimaryBottomNavigation({super.key, required this.currentRoute});

  static const _routes = <String>[
    '/home/one-piece',
    '/collection',
    '/sales',
    '/wanted',
    '/library',
    '/card-scan-test',
  ];

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 900;
  }

  int _selectedIndex() {
    final normalized = _routes.contains(currentRoute)
        ? currentRoute
        : '/home/one-piece';
    return _routes.indexOf(normalized);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile(context)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.navigationBarTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.colorScheme.brightness == Brightness.dark
                    ? 0.32
                    : 0.12,
              ),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: NavigationBar(
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
                label: 'One Piece',
              ),
              NavigationDestination(
                icon: Icon(Icons.collections_bookmark_outlined),
                selectedIcon: Icon(Icons.collections_bookmark),
                label: 'Colecao',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Vendas',
              ),
              NavigationDestination(
                icon: Icon(Icons.travel_explore_outlined),
                selectedIcon: Icon(Icons.travel_explore),
                label: 'Buscas',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: 'Biblioteca',
              ),
              NavigationDestination(
                icon: Icon(Icons.center_focus_strong_outlined),
                selectedIcon: Icon(Icons.center_focus_strong),
                label: 'Scanner',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
