import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/collection_view_mode_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (_) {
        final user = ref.watch(currentUserProvider);

        if (user == null) {
          Future.microtask(() {
            ref.read(themeModeProvider.notifier).reset();
            ref.read(collectionViewModeProvider.notifier).reset();
          });
          return const LoginScreen();
        }

        Future.microtask(() async {
          await ref.read(themeModeProvider.notifier).loadForCurrentUser();
          await ref
              .read(collectionViewModeProvider.notifier)
              .loadForCurrentUser();
        });

        return const HomeScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const Scaffold(
        body: Center(
          child: Text('Erro ao verificar sessão.'),
        ),
      ),
    );
  }
}