import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  String? _loadedUserId;

  ThemeModeNotifier(this._ref)
      : super(
          _ref.read(userPreferencesRepositoryProvider).getSavedThemeMode() == 'dark'
              ? ThemeMode.dark
              : ThemeMode.light,
        );

  Future<void> loadForCurrentUser({bool force = false}) async {
    final user = _ref.read(currentUserProvider);

    if (user == null) {
      _reset(useLocalPreference: true);
      return;
    }

    if (!force && _loadedUserId == user.id) return;

    final prefs = await _ref.read(userPreferencesRepositoryProvider).load();

    _loadedUserId = user.id;
    state = prefs.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;

    await _ref.read(userPreferencesRepositoryProvider).saveThemeMode(
          next == ThemeMode.dark ? 'dark' : 'light',
        );
  }

  void reset() {
    _reset(useLocalPreference: false);
  }

  void _reset({required bool useLocalPreference}) {
    _loadedUserId = null;
    if (useLocalPreference) {
      state = _ref.read(userPreferencesRepositoryProvider).getSavedThemeMode() == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      return;
    }

    state = ThemeMode.light;
  }
}
