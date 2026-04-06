import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';

enum CollectionViewMode { grid, list }

final collectionViewModeProvider =
    StateNotifierProvider<CollectionViewModeNotifier, CollectionViewMode>((ref) {
  return CollectionViewModeNotifier(ref);
});

class CollectionViewModeNotifier extends StateNotifier<CollectionViewMode> {
  final Ref _ref;
  String? _loadedUserId;

  CollectionViewModeNotifier(this._ref)
      : super(
          _ref.read(userPreferencesRepositoryProvider).getSavedCollectionViewMode() ==
                  'list'
              ? CollectionViewMode.list
              : CollectionViewMode.grid,
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
    state = prefs.collectionViewMode == 'list'
        ? CollectionViewMode.list
        : CollectionViewMode.grid;
  }

  Future<void> setMode(CollectionViewMode mode) async {
    state = mode;

    await _ref.read(userPreferencesRepositoryProvider).saveCollectionViewMode(
          mode == CollectionViewMode.list ? 'list' : 'grid',
        );
  }

  void reset() {
    _reset(useLocalPreference: false);
  }

  void _reset({required bool useLocalPreference}) {
    _loadedUserId = null;
    if (useLocalPreference) {
      state = _ref.read(userPreferencesRepositoryProvider).getSavedCollectionViewMode() ==
              'list'
          ? CollectionViewMode.list
          : CollectionViewMode.grid;
      return;
    }

    state = CollectionViewMode.grid;
  }
}
