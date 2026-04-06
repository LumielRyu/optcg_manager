import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collection_types.dart';
import '../../../data/models/card_record.dart';
import '../../../data/models/op_card.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../../data/services/op_api_service.dart';
import '../../collection/collection_controller.dart';
import 'card_ocr_service.dart';
import 'ocr_code_extractor.dart';
import 'visual_card_matcher.dart';

class ImageImportCandidate {
  final int quantity;
  final String code;
  final bool found;
  final String? matchedBy;
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
    this.matchedBy,
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
  static const Object _sentinel = Object();

  final bool isBusy;
  final String? error;
  final String? imagePath;
  final List<ImageImportCandidate> candidates;
  final String? detectedInput;
  final String? rawOcrText;
  final List<String> extractedLines;
  final List<String> candidateNames;
  final String? debugMessage;

  const ImageImportState({
    required this.isBusy,
    this.error,
    this.imagePath,
    this.candidates = const [],
    this.detectedInput,
    this.rawOcrText,
    this.extractedLines = const [],
    this.candidateNames = const [],
    this.debugMessage,
  });

  ImageImportState copyWith({
    bool? isBusy,
    String? error,
    String? imagePath,
    List<ImageImportCandidate>? candidates,
    Object? detectedInput = _sentinel,
    Object? rawOcrText = _sentinel,
    List<String>? extractedLines,
    List<String>? candidateNames,
    Object? debugMessage = _sentinel,
  }) {
    return ImageImportState(
      isBusy: isBusy ?? this.isBusy,
      error: error,
      imagePath: imagePath ?? this.imagePath,
      candidates: candidates ?? this.candidates,
      detectedInput: identical(detectedInput, _sentinel)
          ? this.detectedInput
          : detectedInput as String?,
      rawOcrText: identical(rawOcrText, _sentinel)
          ? this.rawOcrText
          : rawOcrText as String?,
      extractedLines: extractedLines ?? this.extractedLines,
      candidateNames: candidateNames ?? this.candidateNames,
      debugMessage: identical(debugMessage, _sentinel)
          ? this.debugMessage
          : debugMessage as String?,
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
  CardOcrService? _ocrService;
  final VisualCardMatcher _visualMatcher = VisualCardMatcher();

  ImageImportController(this._ref, this._repo, this._api)
    : super(ImageImportState.initial);

  void setImagePath(String? path) {
    state = state.copyWith(
      imagePath: path,
      rawOcrText: null,
      extractedLines: const [],
      candidateNames: const [],
      debugMessage: null,
    );
  }

  Future<void> analyzeCodes(String rawInput) async {
    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: [],
      debugMessage: 'Analise manual iniciada.',
    );

    try {
      final parsed = _parseLines(rawInput);

      if (parsed.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          error: 'Nenhuma linha valida encontrada.',
          detectedInput: rawInput.trim().isEmpty ? null : rawInput.trim(),
          extractedLines: const [],
          candidateNames: const [],
          debugMessage: 'Nenhum codigo valido foi extraido do texto informado.',
        );
        return;
      }

      final results = await _resolveCandidates(parsed);
      final normalizedDetected = parsed
          .map((item) => '${item.quantity}x${item.code}')
          .join('\n');

      state = state.copyWith(
        isBusy: false,
        candidates: results,
        detectedInput: normalizedDetected,
        extractedLines: normalizedDetected.split('\n'),
        candidateNames: const [],
        debugMessage:
            'Analise manual concluiu ${results.length} item(ns). Encontradas: ${results.where((item) => item.found).length}.',
      );
      debugPrint('[ImageImport][manual] input="$rawInput"');
      debugPrint('[ImageImport][manual] normalized="$normalizedDetected"');
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Erro ao analisar codigos: $e',
        debugMessage: 'Erro durante a analise manual: $e',
      );
      debugPrint('[ImageImport][manual][error] $e');
    }
  }

  Future<String?> analyzeImagePath(String path) async {
    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: [],
      imagePath: path,
      rawOcrText: null,
      extractedLines: const [],
      candidateNames: const [],
      debugMessage: 'Lendo texto da imagem...',
    );

    try {
      final rawText = await (_ocrService ??= CardOcrService())
          .readTextFromFile(path);
      final extractedLines = OcrCodeExtractor.extractPrioritizedDeckLines(
        rawText,
      );
      final candidateNames = OcrCodeExtractor.extractCandidateNames(rawText);
      debugPrint('[ImageImport][ocr] path=$path');
      debugPrint('[ImageImport][ocr] raw="$rawText"');
      debugPrint('[ImageImport][ocr] extracted=$extractedLines');
      debugPrint('[ImageImport][ocr] names=$candidateNames');

      if (extractedLines.isEmpty) {
        final fallbackByName = await _resolveNameCandidates(
          candidateNames: candidateNames,
          rawText: rawText,
          extractedLines: extractedLines,
        );
        if (fallbackByName.isNotEmpty) {
          state = state.copyWith(
            isBusy: false,
            candidates: fallbackByName,
            detectedInput: fallbackByName
                .map((item) => '${item.quantity}x${item.code}')
                .join('\n'),
            rawOcrText: rawText,
            extractedLines: const [],
            candidateNames: candidateNames,
            debugMessage:
                'Codigo nao encontrado. A carta foi identificada por nome.',
          );
          return state.detectedInput;
        }

        state = state.copyWith(
          isBusy: false,
          error:
              'Nenhum codigo foi identificado automaticamente na foto. Ajuste o enquadramento da carta ou informe o codigo manualmente.',
          detectedInput: null,
          rawOcrText: rawText,
          extractedLines: const [],
          candidateNames: candidateNames,
          debugMessage:
              'OCR executado, mas nao encontrou nenhum codigo no texto reconhecido.',
        );
        return null;
      }

      final normalizedInput = extractedLines.join('\n');
      final parsed = _parseLines(normalizedInput);
      final results = await _resolveCandidates(parsed);

      if (results.where((item) => item.found).isEmpty) {
        final fallbackByName = await _resolveNameCandidates(
          candidateNames: candidateNames,
          rawText: rawText,
          extractedLines: extractedLines,
        );

        if (fallbackByName.isNotEmpty) {
          state = state.copyWith(
            isBusy: false,
            candidates: fallbackByName,
            detectedInput: fallbackByName
                .map((item) => '${item.quantity}x${item.code}')
                .join('\n'),
            rawOcrText: rawText,
            extractedLines: extractedLines,
            candidateNames: candidateNames,
            debugMessage:
                'OCR executado. Os codigos extraidos nao bateram na API, entao a carta foi confirmada por nome.',
          );
          return state.detectedInput;
        }
      }

      state = state.copyWith(
        isBusy: false,
        candidates: results,
        detectedInput: normalizedInput,
        rawOcrText: rawText,
        extractedLines: extractedLines,
        candidateNames: candidateNames,
        debugMessage:
            'OCR executado com sucesso. Linhas extraidas: ${extractedLines.length}. Cartas encontradas: ${results.where((item) => item.found).length}.',
      );

      return normalizedInput;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Erro ao ler a imagem da carta: $e',
        debugMessage: 'Falha ao executar OCR da imagem: $e',
      );
      debugPrint('[ImageImport][ocr][error] $e');
      return null;
    }
  }

  Future<String?> analyzeImageBytes(Uint8List bytes) async {
    state = state.copyWith(
      isBusy: true,
      error: null,
      candidates: [],
      rawOcrText: null,
      extractedLines: const [],
      candidateNames: const [],
      debugMessage: 'Lendo texto da imagem no navegador...',
    );

    try {
      final rawText = await (_ocrService ??= CardOcrService()).readTextFromBytes(
        bytes,
      );
      final extractedLines = OcrCodeExtractor.extractPrioritizedDeckLines(
        rawText,
      );
      final candidateNames = OcrCodeExtractor.extractCandidateNames(rawText);
      debugPrint('[ImageImport][ocr-web] raw="$rawText"');
      debugPrint('[ImageImport][ocr-web] extracted=$extractedLines');
      debugPrint('[ImageImport][ocr-web] names=$candidateNames');

      if (extractedLines.isEmpty) {
        final fallbackByName = await _resolveNameCandidates(
          candidateNames: candidateNames,
          rawText: rawText,
          extractedLines: extractedLines,
        );
        if (fallbackByName.isNotEmpty) {
          state = state.copyWith(
            isBusy: false,
            candidates: fallbackByName,
            detectedInput: fallbackByName
                .map((item) => '${item.quantity}x${item.code}')
                .join('\n'),
            rawOcrText: rawText,
            extractedLines: const [],
            candidateNames: candidateNames,
            debugMessage:
                'OCR web executado. Codigo nao encontrado, mas a carta foi identificada por nome.',
          );
          return state.detectedInput;
        }

        state = state.copyWith(
          isBusy: false,
          error:
              'Nenhum codigo foi identificado automaticamente na foto. Ajuste o enquadramento da carta ou informe o codigo manualmente.',
          detectedInput: null,
          rawOcrText: rawText,
          extractedLines: const [],
          candidateNames: candidateNames,
          debugMessage:
              'OCR web executado, mas nao encontrou nenhum codigo no texto reconhecido.',
        );
        return null;
      }

      final normalizedInput = extractedLines.join('\n');
      final parsed = _parseLines(normalizedInput);
      final results = await _resolveCandidates(parsed);

      if (results.where((item) => item.found).isEmpty) {
        final fallbackByName = await _resolveNameCandidates(
          candidateNames: candidateNames,
          rawText: rawText,
          extractedLines: extractedLines,
        );

        if (fallbackByName.isNotEmpty) {
          state = state.copyWith(
            isBusy: false,
            candidates: fallbackByName,
            detectedInput: fallbackByName
                .map((item) => '${item.quantity}x${item.code}')
                .join('\n'),
            rawOcrText: rawText,
            extractedLines: extractedLines,
            candidateNames: candidateNames,
            debugMessage:
                'OCR web executado. Os codigos extraidos nao bateram na API, entao a carta foi confirmada por nome.',
          );
          return state.detectedInput;
        }
      }

      state = state.copyWith(
        isBusy: false,
        candidates: results,
        detectedInput: normalizedInput,
        rawOcrText: rawText,
        extractedLines: extractedLines,
        candidateNames: candidateNames,
        debugMessage:
            'OCR web executado com sucesso. Linhas extraidas: ${extractedLines.length}. Cartas encontradas: ${results.where((item) => item.found).length}.',
      );

      return normalizedInput;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Erro ao ler a imagem no navegador: $e',
        debugMessage: 'Falha ao executar OCR web: $e',
      );
      debugPrint('[ImageImport][ocr-web][error] $e');
      return null;
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

        final currentTotal = deckItems.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );

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
        detectedInput: null,
        rawOcrText: null,
        extractedLines: const [],
        candidateNames: const [],
        debugMessage: 'Importacao concluida com sucesso.',
      );
      return null;
    } catch (e) {
      final msg = 'Erro ao importar cartas: $e';
      state = state.copyWith(isBusy: false, error: msg);
      return msg;
    }
  }

  List<_ParsedLine> _parseLines(String raw) {
    final extracted = OcrCodeExtractor.extractDeckLines(raw);
    final lines = extracted.isNotEmpty
        ? extracted
        : raw
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
      final code = _api.normalizeCode(match.group(2) ?? '');

      if (code.isEmpty) continue;

      result.add(_ParsedLine(quantity: quantity, code: code));
    }

    return result;
  }

  Future<List<ImageImportCandidate>> _resolveCandidates(
    List<_ParsedLine> parsed,
  ) async {
    await _api.preload();

    final results = <ImageImportCandidate>[];

    for (final item in parsed) {
      final resolved = await _api.findCardByCode(item.code);

      if (resolved == null) {
        results.add(
          ImageImportCandidate(
            quantity: item.quantity,
            code: item.code,
            found: false,
            matchedBy: 'code',
          ),
        );
        continue;
      }

      results.add(
        ImageImportCandidate(
          quantity: item.quantity,
          code: resolved.code,
          found: true,
          matchedBy: 'code',
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

    return results;
  }

  Future<List<ImageImportCandidate>> _resolveNameCandidates({
    required List<String> candidateNames,
    required String rawText,
    required List<String> extractedLines,
    Uint8List? sourceBytes,
  }) async {
    final visualRanked = await _resolveVisualCandidates(
      candidateNames: candidateNames,
      rawText: rawText,
      extractedLines: extractedLines,
      sourceBytes: sourceBytes,
    );

    if (visualRanked != null) {
      return [
        ImageImportCandidate(
          quantity: 1,
          code: visualRanked.code,
          found: true,
          matchedBy: 'visual+name',
          name: visualRanked.name,
          imageUrl: visualRanked.image,
          setName: visualRanked.setName,
          rarity: visualRanked.rarity,
          color: visualRanked.color,
          type: visualRanked.type,
          text: visualRanked.text,
          attribute: visualRanked.attribute,
        ),
      ];
    }

    final card = await _api.findBestCardFromOcrText(
      rawText: rawText,
      candidateNames: candidateNames,
      extractedLines: extractedLines,
    );

    if (card == null) {
      return const [];
    }

    return [
      ImageImportCandidate(
        quantity: 1,
        code: card.code,
        found: true,
        matchedBy: 'name',
        name: card.name,
        imageUrl: card.image,
        setName: card.setName,
        rarity: card.rarity,
        color: card.color,
        type: card.type,
        text: card.text,
        attribute: card.attribute,
      ),
    ];
  }

  Future<OpCard?> _resolveVisualCandidates({
    required List<String> candidateNames,
    required String rawText,
    required List<String> extractedLines,
    Uint8List? sourceBytes,
  }) async {
    if (sourceBytes == null || candidateNames.isEmpty) {
      return null;
    }

    final candidateCards = <OpCard>[];
    final seenCodes = <String>{};

    for (final candidateName in candidateNames.take(4)) {
      final matches = await _api.searchCardsByName(candidateName, limit: 4);
      for (final card in matches) {
        if (seenCodes.add(card.code)) {
          candidateCards.add(card);
        }
      }
    }

    if (candidateCards.isEmpty) {
      final best = await _api.findBestCardFromOcrText(
        rawText: rawText,
        candidateNames: candidateNames,
        extractedLines: extractedLines,
      );
      if (best != null) {
        candidateCards.add(best);
      }
    }

    if (candidateCards.isEmpty) return null;

    final ranked = await _visualMatcher.rankCandidates(
      sourceBytes: sourceBytes,
      candidates: candidateCards.cast(),
      limit: 3,
    );

    if (ranked.isEmpty) return null;

    final best = ranked.first;
    final secondDistance = ranked.length > 1 ? ranked[1].distance : 99;
    final hasConfidenceGap = secondDistance - best.distance >= 3;
    final isStrongEnough = best.distance <= 18;

    debugPrint(
      '[ImageImport][visual] ranked=${ranked.map((item) => '${item.card.code}:${item.distance}').join(', ')}',
    );

    if (!isStrongEnough || !hasConfidenceGap) {
      return null;
    }

    return best.card;
  }

  String _randomId() {
    final r = Random();
    return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  @override
  void dispose() {
    _ocrService?.dispose();
    super.dispose();
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
