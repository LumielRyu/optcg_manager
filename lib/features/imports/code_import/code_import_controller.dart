import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../data/models/card_record.dart';
import '../../../data/models/op_card.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/services/op_api_service.dart';
import '../../collection/collection_controller.dart';

class CodeImportVariantOption {
  final String code;
  final String name;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String text;
  final String attribute;

  const CodeImportVariantOption({
    required this.code,
    required this.name,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.text,
    required this.attribute,
  });

  factory CodeImportVariantOption.fromOpCard(OpCard card) {
    return CodeImportVariantOption(
      code: card.code,
      name: card.name,
      imageUrl: card.image,
      setName: card.setName,
      rarity: card.rarity,
      color: card.color,
      type: card.type,
      text: card.text,
      attribute: card.attribute,
    );
  }

  String get variantLabel {
    final parts = <String>[
      if (setName.trim().isNotEmpty) setName.trim(),
      if (rarity.trim().isNotEmpty) rarity.trim(),
    ];

    if (parts.isEmpty) {
      return 'Versão alternativa';
    }

    return parts.join(' • ');
  }
}

class CodeImportVariantSelection {
  final String requestId;
  final int quantity;
  final String code;
  final List<CodeImportVariantOption> options;

  const CodeImportVariantSelection({
    required this.requestId,
    required this.quantity,
    required this.code,
    required this.options,
  });
}

class CodeImportCandidate {
  final int quantity;
  final String code;
  final bool found;
  final bool manualEntry;
  final String? name;
  final String? imageUrl;
  final String? setName;
  final String? rarity;
  final String? color;
  final String? type;
  final String? text;
  final String? attribute;

  const CodeImportCandidate({
    required this.quantity,
    required this.code,
    required this.found,
    this.manualEntry = false,
    this.name,
    this.imageUrl,
    this.setName,
    this.rarity,
    this.color,
    this.type,
    this.text,
    this.attribute,
  });

  String get variantKey => imageUrl?.trim() ?? '';

  bool get canImport {
    if (found) return true;
    return (name?.trim().isNotEmpty ?? false) && (color?.trim().isNotEmpty ?? false);
  }

  CodeImportCandidate copyWith({
    int? quantity,
    String? code,
    bool? found,
    bool? manualEntry,
    Object? name = _copySentinel,
    Object? imageUrl = _copySentinel,
    Object? setName = _copySentinel,
    Object? rarity = _copySentinel,
    Object? color = _copySentinel,
    Object? type = _copySentinel,
    Object? text = _copySentinel,
    Object? attribute = _copySentinel,
  }) {
    return CodeImportCandidate(
      quantity: quantity ?? this.quantity,
      code: code ?? this.code,
      found: found ?? this.found,
      manualEntry: manualEntry ?? this.manualEntry,
      name: identical(name, _copySentinel) ? this.name : name as String?,
      imageUrl: identical(imageUrl, _copySentinel) ? this.imageUrl : imageUrl as String?,
      setName: identical(setName, _copySentinel) ? this.setName : setName as String?,
      rarity: identical(rarity, _copySentinel) ? this.rarity : rarity as String?,
      color: identical(color, _copySentinel) ? this.color : color as String?,
      type: identical(type, _copySentinel) ? this.type : type as String?,
      text: identical(text, _copySentinel) ? this.text : text as String?,
      attribute: identical(attribute, _copySentinel)
          ? this.attribute
          : attribute as String?,
    );
  }
}

const Object _copySentinel = Object();

class CodeImportState {
  final bool isBusy;
  final String? error;
  final List<CodeImportCandidate> candidates;
  final CodeImportVariantSelection? pendingSelection;

  const CodeImportState({
    required this.isBusy,
    this.error,
    this.candidates = const [],
    this.pendingSelection,
  });

  CodeImportState copyWith({
    bool? isBusy,
    String? error,
    List<CodeImportCandidate>? candidates,
    CodeImportVariantSelection? pendingSelection,
    bool clearPendingSelection = false,
  }) {
    return CodeImportState(
      isBusy: isBusy ?? this.isBusy,
      error: error,
      candidates: candidates ?? this.candidates,
      pendingSelection:
          clearPendingSelection ? null : (pendingSelection ?? this.pendingSelection),
    );
  }

  static const initial = CodeImportState(isBusy: false);
}

final codeImportControllerProvider =
    StateNotifierProvider<CodeImportController, CodeImportState>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  final api = ref.watch(opApiServiceProvider);
  return CodeImportController(ref, repo, api);
});

class CodeImportController extends StateNotifier<CodeImportState> {
  final Ref _ref;
  final CollectionRepository _repo;
  final OpApiService _api;

  CodeImportController(this._ref, this._repo, this._api)
      : super(CodeImportState.initial);

  List<_ParsedLine> _pendingQueue = [];
  List<CodeImportCandidate> _collectedCandidates = [];

  Future<void> analyzeText(
    String rawInput, {
    int singleCodeQuantity = 1,
  }) async {
    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: [],
      clearPendingSelection: true,
    );

    try {
      await _api.preload();

      final parsed = _parseLines(
        rawInput,
        singleCodeQuantity: singleCodeQuantity,
      );

      if (parsed.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          error: 'Nenhuma linha válida encontrada.',
          clearPendingSelection: true,
        );
        return;
      }

      _pendingQueue = List<_ParsedLine>.from(parsed);
      _collectedCandidates = [];

      await _processQueue();
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Erro ao analisar código: $e',
        clearPendingSelection: true,
      );
    }
  }

  Future<void> _processQueue() async {
    while (_pendingQueue.isNotEmpty) {
      final item = _pendingQueue.removeAt(0);
      final variants = await _api.findAllByCode(item.code);

      if (variants.isEmpty) {
        _collectedCandidates.add(
          CodeImportCandidate(
            quantity: item.quantity,
            code: item.code,
            found: false,
            manualEntry: true,
          ),
        );

        state = state.copyWith(
          isBusy: true,
          error: null,
          candidates: List<CodeImportCandidate>.from(_collectedCandidates),
          clearPendingSelection: true,
        );
        continue;
      }

      if (variants.length == 1) {
        final selected = variants.first;
        _collectedCandidates.add(_candidateFromOpCard(selected, item.quantity));

        state = state.copyWith(
          isBusy: true,
          error: null,
          candidates: List<CodeImportCandidate>.from(_collectedCandidates),
          clearPendingSelection: true,
        );
        continue;
      }

      final request = CodeImportVariantSelection(
        requestId: _randomId(),
        quantity: item.quantity,
        code: item.code,
        options: variants
            .map(CodeImportVariantOption.fromOpCard)
            .toList(growable: false),
      );

      state = state.copyWith(
        isBusy: false,
        error: null,
        candidates: List<CodeImportCandidate>.from(_collectedCandidates),
        pendingSelection: request,
      );
      return;
    }

    state = state.copyWith(
      isBusy: false,
      error: null,
      candidates: List<CodeImportCandidate>.from(_collectedCandidates),
      clearPendingSelection: true,
    );
  }

  Future<void> selectVariant(CodeImportVariantOption option) async {
    final pending = state.pendingSelection;
    if (pending == null) return;

    _collectedCandidates.add(
      CodeImportCandidate(
        quantity: pending.quantity,
        code: option.code,
        found: true,
        name: option.name,
        imageUrl: option.imageUrl,
        setName: option.setName,
        rarity: option.rarity,
        color: option.color,
        type: option.type,
        text: option.text,
        attribute: option.attribute,
      ),
    );

    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: List<CodeImportCandidate>.from(_collectedCandidates),
      clearPendingSelection: true,
    );

    await _processQueue();
  }

  Future<void> cancelVariantSelection() async {
    state = state.copyWith(
      isBusy: false,
      error: 'Seleção de variante cancelada.',
      candidates: List<CodeImportCandidate>.from(_collectedCandidates),
      clearPendingSelection: true,
    );
  }

  void removeCandidate(int index) {
    final list = [...state.candidates];
    if (index < 0 || index >= list.length) return;

    list.removeAt(index);
    _collectedCandidates = List<CodeImportCandidate>.from(list);

    state = state.copyWith(
      candidates: list,
      error: null,
    );
  }

  void updateManualCandidate(
    int index, {
    String? name,
    String? color,
  }) {
    final list = [...state.candidates];
    if (index < 0 || index >= list.length) return;

    final current = list[index];
    list[index] = current.copyWith(
      manualEntry: true,
      name: name?.trim(),
      color: color?.trim(),
    );

    _collectedCandidates = List<CodeImportCandidate>.from(list);
    state = state.copyWith(candidates: list, error: null);
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
            .where((item) => item.canImport)
            .fold<int>(0, (sum, item) => sum + item.quantity);

        if (currentTotal + incomingTotal > 51) {
          state = state.copyWith(isBusy: false);
          return 'Este deck ultrapassaria o limite de 51 cartas.';
        }
      }

      final existingByExactKey = <String, CardRecord>{
        for (final record in _repo.getAll())
          if (record.collectionType == collectionType &&
              (record.deckName ?? '').trim() == (deckName ?? '').trim())
            _recordKey(
              cardCode: record.cardCode,
              collectionType: record.collectionType,
              deckName: record.deckName,
              imageUrl: record.imageUrl,
            ): record,
      };
      final existingByLooseKey = <String, CardRecord>{
        for (final record in _repo.getAll())
          if (record.collectionType == collectionType &&
              (record.deckName ?? '').trim() == (deckName ?? '').trim())
            _recordKey(
              cardCode: record.cardCode,
              collectionType: record.collectionType,
              deckName: record.deckName,
            ): record,
      };
      final changedRecords = <String, CardRecord>{};

      for (final item in state.candidates) {
        if (!item.canImport) continue;

        final key = _recordKey(
          cardCode: item.code,
          collectionType: collectionType,
          deckName: deckName,
          imageUrl: item.imageUrl,
        );
        final looseKey = _recordKey(
          cardCode: item.code,
          collectionType: collectionType,
          deckName: deckName,
        );
        final existing =
            changedRecords[key] ??
            changedRecords[looseKey] ??
            ((item.imageUrl?.trim().isNotEmpty ?? false)
                ? existingByExactKey[key]
                : existingByLooseKey[looseKey]);

        if (existing != null) {
          final updatedRecord = existing.copyWith(
            quantity: existing.quantity + item.quantity,
            imageUrl: (item.imageUrl?.isNotEmpty ?? false)
                ? item.imageUrl!
                : existing.imageUrl,
            name: (item.name?.isNotEmpty ?? false) ? item.name! : existing.name,
            setName: (item.setName?.isNotEmpty ?? false)
                ? item.setName!
                : existing.setName,
            rarity: (item.rarity?.isNotEmpty ?? false)
                ? item.rarity!
                : existing.rarity,
            color: (item.color?.isNotEmpty ?? false)
                ? item.color!
                : existing.color,
            type: (item.type?.isNotEmpty ?? false) ? item.type! : existing.type,
            text: (item.text?.isNotEmpty ?? false) ? item.text! : existing.text,
            attribute: (item.attribute?.isNotEmpty ?? false)
                ? item.attribute!
                : existing.attribute,
          );
          final updatedKey = _recordKey(
            cardCode: updatedRecord.cardCode,
            collectionType: updatedRecord.collectionType,
            deckName: updatedRecord.deckName,
            imageUrl: updatedRecord.imageUrl,
          );
          changedRecords.remove(key);
          changedRecords.remove(looseKey);
          changedRecords[updatedKey] = updatedRecord;
        } else {
          changedRecords[key] = CardRecord(
            id: _randomId(),
            cardCode: item.code,
            name: (item.name?.trim().isNotEmpty ?? false)
                ? item.name!.trim()
                : item.code,
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
          );
        }
      }

      await _repo.upsertMany(changedRecords.values.toList(growable: false));
      await _ref.read(collectionControllerProvider.notifier).load();
      state = const CodeImportState(isBusy: false);
      _pendingQueue = [];
      _collectedCandidates = [];
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

  CodeImportCandidate _candidateFromOpCard(OpCard card, int quantity) {
    return CodeImportCandidate(
      quantity: quantity,
      code: card.code,
      found: true,
      name: card.name,
      imageUrl: card.image,
      setName: card.setName,
      rarity: card.rarity,
      color: card.color,
      type: card.type,
      text: card.text,
      attribute: card.attribute,
    );
  }

  List<_ParsedLine> _parseLines(
    String raw, {
    required int singleCodeQuantity,
  }) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final result = <_ParsedLine>[];

    for (final line in lines) {
      final compact = line.replaceAll(' ', '');

      final withQuantity =
          RegExp(r'^(\d+)x([A-Za-z0-9\-]+)$', caseSensitive: false)
              .firstMatch(compact);

      if (withQuantity != null) {
        final quantity = int.tryParse(withQuantity.group(1) ?? '1') ?? 1;
        final code = _api.normalizeCode(withQuantity.group(2) ?? '');

        if (code.isNotEmpty) {
          result.add(_ParsedLine(quantity: quantity, code: code));
        }
        continue;
      }

      final codeOnly = RegExp(r'^[A-Za-z0-9\-]+$', caseSensitive: false)
          .hasMatch(compact);

      if (codeOnly) {
        result.add(
          _ParsedLine(
            quantity: singleCodeQuantity,
            code: _api.normalizeCode(compact),
          ),
        );
      }
    }

    return result;
  }

  String _randomId() {
    final r = Random();
    return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  String _recordKey({
    required String cardCode,
    required String collectionType,
    String? deckName,
    String? imageUrl,
  }) {
    return [
      cardCode.trim().toUpperCase(),
      collectionType.trim(),
      (deckName ?? '').trim(),
      (imageUrl ?? '').trim(),
    ].join('|');
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
