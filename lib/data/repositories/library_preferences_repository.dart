import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../local/hive_boxes.dart';

final libraryPreferencesRepositoryProvider =
    Provider<LibraryPreferencesRepository>((ref) {
  final box = Hive.box(HiveBoxes.libraryPrefs);
  return LibraryPreferencesRepository(box);
});

class LibraryPreferencesRepository {
  static const String _favoriteCodesKey = 'favorite_codes';
  static const String _compareCodesKey = 'compare_codes';

  final Box _box;

  LibraryPreferencesRepository(this._box);

  Set<String> loadFavoriteCodes() {
    return _readStringSet(_favoriteCodesKey);
  }

  Set<String> toggleFavoriteCode(String code) {
    final next = loadFavoriteCodes();
    if (next.contains(code)) {
      next.remove(code);
    } else {
      next.add(code);
    }
    _box.put(_favoriteCodesKey, next.toList()..sort());
    return next;
  }

  Set<String> loadCompareCodes() {
    return _readStringSet(_compareCodesKey);
  }

  Set<String> toggleCompareCode(String code) {
    final next = loadCompareCodes();
    if (next.contains(code)) {
      next.remove(code);
    } else {
      if (next.length >= 3) {
        final sorted = next.toList()..sort();
        next.remove(sorted.first);
      }
      next.add(code);
    }
    _box.put(_compareCodesKey, next.toList()..sort());
    return next;
  }

  void clearCompareCodes() {
    _box.put(_compareCodesKey, const <String>[]);
  }

  Set<String> _readStringSet(String key) {
    final raw = _box.get(key);
    if (raw is List) {
      return raw.map((item) => item.toString()).toSet();
    }
    return <String>{};
  }
}
