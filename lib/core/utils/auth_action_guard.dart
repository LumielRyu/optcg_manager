import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool requireSignedIn(
  BuildContext context, {
  String message = 'Entre ou cadastre-se para usar esta funcionalidade.',
}) {
  if (Supabase.instance.client.auth.currentUser != null) {
    return true;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Entrar',
        onPressed: () => context.go('/login'),
      ),
    ),
  );
  context.go('/login');
  return false;
}
