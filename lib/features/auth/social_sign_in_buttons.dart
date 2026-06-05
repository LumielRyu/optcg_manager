import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';

class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  OAuthProvider? _busyProvider;
  String? _error;

  Future<void> _signIn(OAuthProvider provider) async {
    setState(() {
      _busyProvider = provider;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithOAuth(provider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyProvider = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.toLowerCase().contains('provider is not enabled')) {
      return 'Este provedor ainda nao foi habilitado no Supabase.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou continue com',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: Icons.g_mobiledata_rounded,
          label: 'Google',
          isBusy: _busyProvider == OAuthProvider.google,
          isDisabled: _busyProvider != null,
          onPressed: () => _signIn(OAuthProvider.google),
        ),
        const SizedBox(height: 8),
        _SocialButton(
          icon: Icons.facebook_rounded,
          label: 'Facebook',
          isBusy: _busyProvider == OAuthProvider.facebook,
          isDisabled: _busyProvider != null,
          onPressed: () => _signIn(OAuthProvider.facebook),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBusy;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isBusy,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isDisabled ? null : onPressed,
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}
