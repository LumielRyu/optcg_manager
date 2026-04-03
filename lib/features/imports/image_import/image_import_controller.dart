import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../data/models/card_record.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/services/op_api_service.dart';
import '../../collection/collection_controller.dart';

class ImageImportCandidate {
  final int quantity;
  final String code;
  final bool found;
  final String? name;
  final String? imageUrl;
  final String? setName;
  final String? rarity;
  final String? color;
  final String? type;
  final String? text;
  final String? attribute;

  const ImageImportCandidate({
    required this.quantity,
    required this.code,
    required this.found,
    this.name,
    this.imageUrl,
    this.setName,
    this.rarity,
    this.color,
    this.type,
    this.text,
    this.attribute,
  });
}

class ImageImportState {
  final bool isBusy;
  final String? error;
  final String? imagePath;
  final List<ImageImportCandidate> candidates;

  const ImageImportState({
    required this.isBusy,
    this.error,
    this.imagePath,
    this.candidates = const [],
  });

  ImageImportState copyWith({
    bool? isBusy,
    String? error,
    String? imagePath,
    List<ImageImportCandidate>? candidates,
  }) {
    return ImageImportState(
      isBusy: isBusy ?? this.isBusy,
      error: error,
      imagePath: imagePath ?? this.imagePath,
      candidates: candidates ?? this.candidates,
    );
  }

  static const initial = ImageImportState(isBusy: false);
}

final imageImportControllerProvider =
    StateNotifierProvider<ImageImportController, ImageImportState>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  final api = ref.watch(opApiServiceProvider);

  return ImageImportController(ref, repo, api);
});

class ImageImportController extends StateNotifier<ImageImportState> {
  final Ref _ref;
  final CollectionRepository _repo;
  final OpApiService _api;

  ImageImportController(this._ref, this._repo, this._api)
      : super(ImageImportState.initial);

  void setImagePath(String? path) {
    state = state.copyWith(imagePath: path);
  }

  Future<void> analyzeCodes(String rawInput) async {
    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: [],
    );

    try {
      await _api.preload();

      final parsed = _parseLines(rawInput);

      if (parsed.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          error: 'Nenhuma linha válida encontrada.',
        );
        return;
      }

      final results = <ImageImportCandidate>[];

      for (final item in parsed) {
        final resolved = await _api.findCardByCode(item.code);

        if (resolved == null) {
          results.add(
            ImageImportCandidate(
              quantity: item.quantity,
              code: item.code,
              found: false,
            ),
          );
        } else {
          results.add(
            ImageImportCandidate(
              quantity: item.quantity,
              code: resolved.code,
              found: true,
              name: resolved.name,
              imageUrl: resolved.image,
              setName: resolved.setName,
              rarity: resolved.rarity,
              color: resolved.color,
              type: resolved.type,
              text: resolved.text,
              attribute: resolved.attribute,
            ),
          );
        }
      }

      state = state.copyWith(
        isBusy: false,
        candidates: results,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Erro ao analisar códigos: $e',
      );
    }
  }

  void removeCandidate(int index) {
    final list = [...state.candidates];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    state = state.copyWith(candidates: list);
  }

  Future<String?> confirmImport({
    required String collectionType,
    String? deckName,
  }) async {
    state = state.copyWith(isBusy: true, error: null);

    try {
      if (collectionType == CollectionTypes.deck) {
        final deckItems = _repo.getAll().where((item) {
          return item.collectionType == CollectionTypes.deck &&
              (item.deckName ?? '').trim() == (deckName ?? '').trim();
        }).toList();

        final currentTotal =
            deckItems.fold<int>(0, (sum, item) => sum + item.quantity);

        final incomingTotal = state.candidates
            .where((item) => item.found)
            .fold<int>(0, (sum, item) => sum + item.quantity);

        if (currentTotal + incomingTotal > 51) {
          state = state.copyWith(isBusy: false);
          return 'Este deck ultrapassaria o limite de 51 cartas.';
        }
      }

      for (final item in state.candidates) {
        if (!item.found) continue;

        final existing = _repo.findByCodeAndCollection(
          cardCode: item.code,
          collectionType: collectionType,
          deckName: deckName,
        );

        if (existing != null) {
          await _repo.upsert(
            existing.copyWith(
              quantity: existing.quantity + item.quantity,
              imageUrl: (item.imageUrl?.isNotEmpty ?? false)
                  ? item.imageUrl!
                  : existing.imageUrl,
              name: (item.name?.isNotEmpty ?? false)
                  ? item.name!
                  : existing.name,
              setName: (item.setName?.isNotEmpty ?? false)
                  ? item.setName!
                  : existing.setName,
              rarity: (item.rarity?.isNotEmpty ?? false)
                  ? item.rarity!
                  : existing.rarity,
              color: (item.color?.isNotEmpty ?? false)
                  ? item.color!
                  : existing.color,
              type: (item.type?.isNotEmpty ?? false)
                  ? item.type!
                  : existing.type,
              text: (item.text?.isNotEmpty ?? false)
                  ? item.text!
                  : existing.text,
              attribute: (item.attribute?.isNotEmpty ?? false)
                  ? item.attribute!
                  : existing.attribute,
            ),
          );
        } else {
          await _repo.upsert(
            CardRecord(
              id: _randomId(),
              cardCode: item.code,
              name: item.name ?? '',
              imageUrl: item.imageUrl ?? '',
              dateAddedUtc: DateTime.now(),
              setName: item.setName ?? '',
              rarity: item.rarity ?? '',
              color: item.color ?? '',
              type: item.type ?? '',
              text: item.text ?? '',
              attribute: item.attribute ?? '',
              quantity: item.quantity,
              collectionType: collectionType,
              deckName: deckName,
            ),
          );
        }
      }

      await _ref.read(collectionControllerProvider.notifier).load();
      state = state.copyWith(
        isBusy: false,
        error: null,
        candidates: const [],
      );
      return null;
    } catch (e) {
      final msg = 'Erro ao importar cartas: $e';
      state = state.copyWith(
        isBusy: false,
        error: msg,
      );
      return msg;
    }
  }

  List<_ParsedLine> _parseLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = <_ParsedLine>[];

    for (final line in lines) {
      final compact = line.replaceAll(' ', '');

      final match =
          RegExp(r'^(\d+)x([A-Za-z0-9\-]+)$', caseSensitive: false)
              .firstMatch(compact);

      if (match == null) continue;

      final quantity = int.tryParse(match.group(1) ?? '1') ?? 1;
      final code = (match.group(2) ?? '').toUpperCase().trim();

      if (code.isEmpty) continue;

      result.add(_ParsedLine(quantity: quantity, code: code));
    }

    return result;
  }

  String _randomId() {
    final r = Random();
    return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
  }
}

class _ParsedLine {
  final int quantity;
  final String code;

  _ParsedLine({
    required this.quantity,
    required this.code,
  });
}