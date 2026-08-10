import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/card_record.dart';
import '../../data/repositories/collection_repository.dart';

enum CollectionLoadPhase { initial, details, idle }

final collectionLoadPhaseProvider = StateProvider<CollectionLoadPhase>(
  (ref) => CollectionLoadPhase.initial,
);

final collectionControllerProvider =
    StateNotifierProvider<CollectionController, List<CardRecord>>((ref) {
      final repo = ref.watch(collectionRepositoryProvider);
      final controller = CollectionController(
        repo,
        onPhaseChanged: (phase) {
          ref.read(collectionLoadPhaseProvider.notifier).state = phase;
        },
      );
      Future<void>.microtask(controller.load);
      return controller;
    });

class CollectionController extends StateNotifier<List<CardRecord>> {
  final CollectionRepository _repo;
  final void Function(CollectionLoadPhase phase) _onPhaseChanged;
  Future<void>? _detailsRefresh;

  CollectionController(
    this._repo, {
    required void Function(CollectionLoadPhase phase) onPhaseChanged,
  }) : _onPhaseChanged = onPhaseChanged,
       super(const []);

  Future<void> load() async {
    if (state.isEmpty) _onPhaseChanged(CollectionLoadPhase.initial);
    try {
      await _repo.seedIfEmpty();
      await _repo.refreshAll(loadCatalog: false);
      if (!mounted) return;
      state = _repo.getAll();
      _onPhaseChanged(CollectionLoadPhase.details);
      unawaited(_refreshDetails());
    } catch (_) {
      if (mounted) _onPhaseChanged(CollectionLoadPhase.idle);
      rethrow;
    }
  }

  Future<void> _refreshDetails() {
    final running = _detailsRefresh;
    if (running != null) return running;

    final future = () async {
      try {
        await _repo.refreshAll();
        if (mounted) state = _repo.getAll();
      } catch (_) {
        // Os dados salvos continuam visiveis se o catalogo estiver indisponivel.
      } finally {
        if (mounted) _onPhaseChanged(CollectionLoadPhase.idle);
        _detailsRefresh = null;
      }
    }();
    _detailsRefresh = future;
    return future;
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

  Future<void> upsertMany(List<CardRecord> records) async {
    await _repo.upsertMany(records);
    state = _repo.getAll();
  }
}
