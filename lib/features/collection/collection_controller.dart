import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/card_record.dart';
import '../../data/repositories/collection_repository.dart';

final collectionControllerProvider =
    StateNotifierProvider<CollectionController, List<CardRecord>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return CollectionController(repo)..load();
});

class CollectionController extends StateNotifier<List<CardRecord>> {
  final CollectionRepository _repo;

  CollectionController(this._repo) : super(const []);

  Future<void> load() async {
    await _repo.seedIfEmpty();
    await _repo.refreshAll();
    state = _repo.getAll();
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
  }

  Future<void> deleteManyByIds(List<String> ids) async {
    await _repo.deleteManyByIds(ids);
    state = _repo.getAll();
  }

  Future<void> add(CardRecord record) async {
    await _repo.upsert(record);
    state = _repo.getAll();
  }

  Future<void> update(CardRecord record) async {
    await _repo.upsert(record);
    state = _repo.getAll();
  }
}