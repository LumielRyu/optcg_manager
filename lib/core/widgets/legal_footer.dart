import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../privacy/cookie_consent.dart';

class LegalFooter extends ConsumerWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => context.go('/privacy'),
                child: const Text('Privacidade'),
              ),
              TextButton(
                onPressed: () => context.go('/cookies'),
                child: const Text('Cookies'),
              ),
              TextButton(
                onPressed: () => context.go('/terms'),
                child: const Text('Termos de uso'),
              ),
              TextButton(
                onPressed: () => context.go('/contact'),
                child: const Text('Contato'),
              ),
              TextButton(
                onPressed: () => showCookiePreferencesDialog(context, ref),
                child: const Text('Gerenciar privacidade'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} TCG BH • Plataforma independente para a comunidade de card games.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
