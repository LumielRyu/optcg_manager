import 'package:flutter/material.dart';

import '../../features/collection/shared_sale_card_screen.dart';
import '../../features/collection/shared_store_screen.dart';
import '../../features/decks/shared_deck_screen.dart';
import '../../features/wanted/shared_wanted_cards_screen.dart';

Widget deckScreen({required String shareCode}) =>
    SharedDeckScreen(shareCode: shareCode);

Widget saleScreen({required String shareCode}) =>
    SharedSaleCardScreen(shareCode: shareCode);

Widget storeScreen({required String userId}) =>
    SharedStoreScreen(userId: userId);

Widget wantedScreen({required String userId}) =>
    SharedWantedCardsScreen(userId: userId);
