import 'package:flutter/material.dart';

import '../../data/models/op_card.dart';
import '../../features/collection/collection_screen.dart';
import '../../features/library/library_card_details_screen.dart';
import '../../features/library/library_compare_screen.dart';
import '../../features/library/one_piece_library_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/wanted/wanted_cards_screen.dart';

Widget libraryScreen() => const OnePieceLibraryScreen();

Widget collectionScreen() => const CollectionScreen();

Widget salesScreen() => const SalesScreen();

Widget wantedScreen() => const WantedCardsScreen();

Widget libraryCardDetailsScreen({
  required String cardCode,
  String? preferredImageUrl,
  String? preferredName,
  OpCard? initialCard,
}) => LibraryCardDetailsScreen(
  cardCode: cardCode,
  preferredImageUrl: preferredImageUrl,
  preferredName: preferredName,
  initialCard: initialCard,
);

Widget libraryCompareScreen({required List<String> cardCodes}) =>
    LibraryCompareScreen(cardCodes: cardCodes);
