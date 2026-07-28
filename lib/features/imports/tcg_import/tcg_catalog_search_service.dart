import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tcg/tcg_collection_drafts.dart';
import '../../../core/tcg/tcg_game.dart';
import '../../../data/models/tcg_collection_item.dart';
import '../../../data/services/digimon_tcg_service.dart';
import '../../../data/services/magic_tcg_service.dart';
import '../../../data/services/pokemon_tcg_service.dart';
import '../../../data/services/riftbound_tcg_service.dart';
import '../../../data/services/yugioh_tcg_service.dart';

final tcgCatalogSearchServiceProvider = Provider<TcgCatalogSearchService>((
  ref,
) {
  return TcgCatalogSearchService(
    pokemon: ref.watch(pokemonTcgServiceProvider),
    digimon: ref.watch(digimonTcgServiceProvider),
    magic: ref.watch(magicTcgServiceProvider),
    riftbound: ref.watch(riftboundTcgServiceProvider),
    yugioh: ref.watch(yugiohTcgServiceProvider),
  );
});

class TcgImportCandidate {
  final String id;
  final String name;
  final String imageUrl;
  final List<TcgCollectionDraft> variants;

  const TcgImportCandidate({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.variants,
  });
}

class TcgCatalogSearchService {
  final PokemonTcgService pokemon;
  final DigimonTcgService digimon;
  final MagicTcgService magic;
  final RiftboundTcgService riftbound;
  final YugiohTcgService yugioh;

  const TcgCatalogSearchService({
    required this.pokemon,
    required this.digimon,
    required this.magic,
    required this.riftbound,
    required this.yugioh,
  });

  Future<List<TcgImportCandidate>> search(TcgGame game, String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];

    return switch (game) {
      TcgGame.pokemon => _pokemon(query),
      TcgGame.digimon => _digimon(query),
      TcgGame.magic => _magic(query),
      TcgGame.riftbound => _riftbound(query),
      TcgGame.yugioh => _yugioh(query),
      TcgGame.onePiece => const [],
    };
  }

  Future<List<TcgImportCandidate>> _pokemon(String query) async {
    final result = await pokemon.searchCards(
      query: query,
      page: 1,
      pageSize: 30,
    );
    return result.cards
        .map(
          (card) => TcgImportCandidate(
            id: card.id,
            name: card.name,
            imageUrl: card.largeImageUrl,
            variants: [card.collectionDraft],
          ),
        )
        .toList(growable: false);
  }

  Future<List<TcgImportCandidate>> _digimon(String query) async {
    final result = await digimon.searchCards(
      query: query,
      page: 1,
      pageSize: 30,
    );
    return result.cards
        .map(
          (card) => TcgImportCandidate(
            id: card.id,
            name: card.name,
            imageUrl: card.imageUrl,
            variants: [card.collectionDraft],
          ),
        )
        .toList(growable: false);
  }

  Future<List<TcgImportCandidate>> _magic(String query) async {
    final result = await magic.searchCards(query: query, page: 1, pageSize: 30);
    return result.cards
        .map(
          (card) => TcgImportCandidate(
            id: card.id,
            name: card.name,
            imageUrl: card.largeImageUrl,
            variants: [card.collectionDraft],
          ),
        )
        .toList(growable: false);
  }

  Future<List<TcgImportCandidate>> _riftbound(String query) async {
    final result = await riftbound.searchCards(
      query: query,
      page: 1,
      pageSize: 30,
    );
    return result.cards
        .map(
          (card) => TcgImportCandidate(
            id: card.id,
            name: card.name,
            imageUrl: card.imageUrl,
            variants: [card.collectionDraft],
          ),
        )
        .toList(growable: false);
  }

  Future<List<TcgImportCandidate>> _yugioh(String query) async {
    final result = await yugioh.searchCards(
      query: query,
      page: 1,
      pageSize: 30,
    );
    return result.cards
        .map(
          (card) => TcgImportCandidate(
            id: '${card.id}',
            name: card.name,
            imageUrl: card.largeImageUrl,
            variants: card.printings
                .map(card.collectionDraftFor)
                .toList(growable: false),
          ),
        )
        .where((candidate) => candidate.variants.isNotEmpty)
        .toList(growable: false);
  }
}
