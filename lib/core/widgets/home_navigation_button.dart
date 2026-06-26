import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeNavigationButton extends StatelessWidget {
  final bool goHome;
  final String fallbackRoute;

  const HomeNavigationButton({
    super.key,
    this.goHome = false,
    this.fallbackRoute = '/home/one-piece',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: goHome ? 'Voltar ao Home' : 'Voltar',
      onPressed: () {
        if (goHome) {
          context.go('/home');
          return;
        }
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go(fallbackRoute);
      },
      icon: Icon(goHome ? Icons.home_outlined : Icons.arrow_back),
    );
  }
}
