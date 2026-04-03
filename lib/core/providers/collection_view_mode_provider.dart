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

  CollectionViewModeNotifier(this._ref) : super(CollectionViewMode.grid);

  Future<void> loadForCurrentUser() async {
    final user = _ref.read(currentUserProvider);

    if (user == null) {
      reset();
      return;
    }

    if (_loadedUserId == user.id) return;

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
    _loadedUserId = null;
    state = CollectionViewMode.grid;
  }
}