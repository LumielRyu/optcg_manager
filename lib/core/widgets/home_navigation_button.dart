import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeNavigationButton extends StatelessWidget {
  const HomeNavigationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar ao Home',
      onPressed: () => context.go('/home'),
      icon: const Icon(Icons.home_outlined),
    );
  }
}
