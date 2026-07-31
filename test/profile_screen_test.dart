import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile is available next to logout in both authenticated hubs', () {
    final selector = File(
      'lib/features/tcg/tcg_selector_screen.dart',
    ).readAsStringSync();
    final onePieceHome = File(
      'lib/features/home/home_screen.dart',
    ).readAsStringSync();

    for (final source in [selector, onePieceHome]) {
      expect(source.indexOf("tooltip: 'Perfil'"), greaterThanOrEqualTo(0));
      expect(
        source.indexOf("tooltip: 'Perfil'"),
        lessThan(source.indexOf("tooltip: 'Sair'")),
      );
      expect(source, contains("context.push('/profile')"));
    }
  });

  test('profile exposes editable account and security controls', () {
    final source = File(
      'lib/features/profile/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Nick / nome público'));
    expect(source, contains('Telefone / WhatsApp'));
    expect(source, contains('E-mail da conta'));
    expect(source, contains('Escolher foto'));
    expect(source, contains('Alterar senha'));
    expect(source, contains('Recuperar por e-mail'));
    expect(source, contains('Recuperação por telefone ainda não está ativa'));
  });

  test('avatar storage is restricted to the authenticated user folder', () {
    final migration = File(
      'sql/profile_avatar_storage.sql',
    ).readAsStringSync();

    expect(migration, contains("bucket_id = 'profile-avatars'"));
    expect(
      migration,
      contains("(storage.foldername(name))[1] = auth.uid()::text"),
    );
    expect(migration, contains('file_size_limit'));
    expect(migration, contains("'image/jpeg', 'image/png', 'image/webp'"));
  });
}
