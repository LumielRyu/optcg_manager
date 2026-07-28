import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeNavigationButton extends StatelessWidget {
  final String destinationRoute;
  final bool showHomeIcon;
  final String? tooltip;

  const HomeNavigationButton({
    super.key,
    required this.destinationRoute,
    this.showHomeIcon = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? (showHomeIcon ? 'Voltar ao Home' : 'Voltar'),
      onPressed: () => context.go(destinationRoute),
      icon: Icon(showHomeIcon ? Icons.home_outlined : Icons.arrow_back),
    );
  }
}
