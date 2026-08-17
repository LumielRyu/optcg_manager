import 'package:flutter/material.dart';

import '../../core/tcg/tcg_game.dart';
import '../../features/collection/tcg_collection_screen.dart';
import '../../features/decks/tcg_decks_screen.dart';
import '../../features/digimon/digimon_library_screen.dart';
import '../../features/imports/tcg_import/tcg_import_screen.dart';
import '../../features/magic/magic_library_screen.dart';
import '../../features/marketplace/tcg_marketplace_screen.dart';
import '../../features/pokemon/pokemon_library_screen.dart';
import '../../features/riftbound/riftbound_library_screen.dart';
import '../../features/sales/tcg_sales_screen.dart';
import '../../features/wanted/tcg_wanted_screen.dart';
import '../../features/yugioh/yugioh_library_screen.dart';

Widget libraryScreen(TcgGame game) => switch (game) {
  TcgGame.pokemon => const PokemonLibraryScreen(),
  TcgGame.digimon => const DigimonLibraryScreen(),
  TcgGame.magic => const MagicLibraryScreen(),
  TcgGame.riftbound => const RiftboundLibraryScreen(),
  TcgGame.yugioh => const YugiohLibraryScreen(),
  TcgGame.onePiece => throw ArgumentError.value(game, 'game'),
};

Widget collectionScreen(TcgGame game) => TcgCollectionScreen(game: game);

Widget decksScreen(TcgGame game) => TcgDecksScreen(game: game);

Widget salesScreen(TcgGame game) => TcgSalesScreen(game: game);

Widget marketplaceScreen(TcgGame game) => TcgMarketplaceScreen(game: game);

Widget wantedScreen(TcgGame game, {String? sharedUserId}) =>
    TcgWantedScreen(game: game, sharedUserId: sharedUserId);

Widget importScreen(TcgGame game) => TcgImportScreen(game: game);
