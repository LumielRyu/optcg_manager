import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/collection_types.dart';
import '../core/tcg/tcg_game.dart';
import '../core/utils/admin_access.dart';
import '../data/models/op_card.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/admin/liga_price_admin_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/shared_sale_card_screen.dart';
import '../features/collection/shared_store_screen.dart';
import '../features/collection/tcg_collection_screen.dart';
import '../features/decks/shared_deck_screen.dart';
import '../features/decks/tcg_decks_screen.dart';
import '../features/digimon/digimon_library_screen.dart';
import '../features/help/help_screen.dart';
import '../features/home/home_screen.dart';
import '../features/integrations/liga_one_piece_test_screen.dart';
import '../features/imports/camera_import/camera_import_screen.dart';
import '../features/imports/card_scan_test/card_scan_test_screen.dart';
import '../features/imports/code_import/code_import_screen.dart';
import '../features/imports/image_import/image_import_screen.dart';
import '../features/library/library_card_details_screen.dart';
import '../features/library/library_compare_screen.dart';
import '../features/library/one_piece_library_screen.dart';
import '../features/marketplace/global_marketplace_screen.dart';
import '../features/marketplace/tcg_marketplace_screen.dart';
import '../features/magic/magic_library_screen.dart';
import '../features/pokemon/pokemon_library_screen.dart';
import '../features/products/products_screen.dart';
import '../features/riftbound/riftbound_library_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/sales/tcg_sales_screen.dart';
import '../features/tcg/tcg_hub_screen.dart';
import '../features/tcg/tcg_selector_screen.dart';
import '../features/wanted/wanted_cards_screen.dart';
import '../features/wanted/shared_wanted_cards_screen.dart';
import '../features/wanted/tcg_wanted_screen.dart';
import '../features/yugioh/yugioh_library_screen.dart';
import '../features/weeklies/pokemon_weekly_report_screen.dart';
import '../features/weeklies/weekly_dashboard_screen.dart';
import '../features/weeklies/weekly_selector_screen.dart';
import '../data/repositories/user_preferences_repository.dart';

class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final AuthRouterNotifier _authRouterNotifier = AuthRouterNotifier();
final UserPreferencesRepository _userPreferencesRepository =
    UserPreferencesRepository(Supabase.instance.client);

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRouterNotifier,
  redirect: (context, state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final loggedIn = user != null;
    final location = state.uri.path;

    final isLoginRoute = location == '/login';
    final isRegisterRoute = location == '/register';
    final isCompleteProfileRoute = location == '/complete-profile';
    final isRootRoute = location == '/';
    final isSharedDeckRoute = location.startsWith('/shared/deck/');
    final isSharedSaleRoute = location.startsWith('/shared/sale/');
    final isSharedStoreRoute = location.startsWith('/shared/store/');
    final isSharedWantedRoute = location.startsWith('/shared/wanted/');
    final isSharedRoute =
        isSharedDeckRoute ||
        isSharedSaleRoute ||
        isSharedStoreRoute ||
        isSharedWantedRoute;
    final isAdminRoute = location.startsWith('/admin/');

    if (isSharedRoute) {
      return null;
    }

    if (isAdminRoute) {
      if (!loggedIn) return '/login';
      if (!isApplicationAdmin(user)) return '/home/one-piece';
    }

    if (!loggedIn) {
      if (isRootRoute) {
        return '/home';
      }

      if (isCompleteProfileRoute) {
        return '/login';
      }

      return null;
    }

    if (loggedIn) {
      final hasCompletedProfile =
          _userPreferencesRepository.getCachedProfileCompletionStatus() ??
          await _userPreferencesRepository.hasCompletedProfile(
            preferCache: false,
          );
      final needsCompletion = !hasCompletedProfile;

      if (needsCompletion && !isCompleteProfileRoute && !isSharedRoute) {
        return '/complete-profile';
      }

      if (!needsCompletion && isCompleteProfileRoute) {
        return '/home';
      }

      if (isRootRoute || isLoginRoute || isRegisterRoute) {
        return needsCompletion ? '/complete-profile' : '/home';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: '/shared/deck/:shareCode',
      builder: (context, state) {
        final shareCode = state.pathParameters['shareCode'] ?? '';
        return SharedDeckScreen(shareCode: shareCode);
      },
    ),
    GoRoute(
      path: '/shared/sale/:shareCode',
      builder: (context, state) {
        final shareCode = state.pathParameters['shareCode'] ?? '';
        return SharedSaleCardScreen(shareCode: shareCode);
      },
    ),
    GoRoute(
      path: '/shared/store/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        return SharedStoreScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/shared/wanted/:gameSlug/:userId',
      builder: (context, state) {
        final game = TcgGame.fromSlug(state.pathParameters['gameSlug']);
        final userId = state.pathParameters['userId'] ?? '';
        return TcgWantedScreen(game: game, sharedUserId: userId);
      },
    ),
    GoRoute(
      path: '/shared/wanted/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        return SharedWantedCardsScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const TcgSelectorScreen(),
    ),
    GoRoute(
      path: '/home/one-piece',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/digimon',
      builder: (context, state) => const TcgHubScreen(
        title: 'Digimon',
        subtitle:
            'Entrada inicial do ecossistema Digimon dentro do TCG BH, com biblioteca conectada a API publica e espaco para futuras expansoes.',
        sourceLabel: 'Fonte: Heroicc Digimon API',
        accent: Color(0xFF0F766E),
        heroIcon: Icons.memory_outlined,
        libraryRoute: '/digimon/library',
        collectionRoute: '/digimon/collection',
        deckRoute: '/digimon/decks',
        salesRoute: '/digimon/sales',
        marketplaceRoute: '/digimon/marketplace',
        wantedRoute: '/digimon/wanted',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/digimon/library',
      builder: (context, state) => const DigimonLibraryScreen(),
    ),
    GoRoute(
      path: '/digimon/collection',
      builder: (context, state) =>
          const TcgCollectionScreen(game: TcgGame.digimon),
    ),
    GoRoute(
      path: '/digimon/decks',
      builder: (context, state) => const TcgDecksScreen(game: TcgGame.digimon),
    ),
    GoRoute(
      path: '/digimon/sales',
      builder: (context, state) => const TcgSalesScreen(game: TcgGame.digimon),
    ),
    GoRoute(
      path: '/digimon/marketplace',
      builder: (context, state) =>
          const TcgMarketplaceScreen(game: TcgGame.digimon),
    ),
    GoRoute(
      path: '/digimon/wanted',
      builder: (context, state) => const TcgWantedScreen(game: TcgGame.digimon),
    ),
    GoRoute(
      path: '/magic',
      builder: (context, state) => const TcgHubScreen(
        title: 'Magic',
        subtitle:
            'Entrada inicial do ecossistema Magic: The Gathering dentro do TCG BH, com biblioteca conectada ao Scryfall e estrutura pronta para modulos futuros.',
        sourceLabel: 'Fonte: Scryfall',
        accent: Color(0xFFB45309),
        heroIcon: Icons.auto_fix_high_outlined,
        libraryRoute: '/magic/library',
        collectionRoute: '/magic/collection',
        deckRoute: '/magic/decks',
        salesRoute: '/magic/sales',
        marketplaceRoute: '/magic/marketplace',
        wantedRoute: '/magic/wanted',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/magic/library',
      builder: (context, state) => const MagicLibraryScreen(),
    ),
    GoRoute(
      path: '/magic/collection',
      builder: (context, state) =>
          const TcgCollectionScreen(game: TcgGame.magic),
    ),
    GoRoute(
      path: '/magic/decks',
      builder: (context, state) => const TcgDecksScreen(game: TcgGame.magic),
    ),
    GoRoute(
      path: '/magic/sales',
      builder: (context, state) => const TcgSalesScreen(game: TcgGame.magic),
    ),
    GoRoute(
      path: '/magic/marketplace',
      builder: (context, state) =>
          const TcgMarketplaceScreen(game: TcgGame.magic),
    ),
    GoRoute(
      path: '/magic/wanted',
      builder: (context, state) => const TcgWantedScreen(game: TcgGame.magic),
    ),
    GoRoute(
      path: '/pokemon',
      builder: (context, state) => const TcgHubScreen(
        title: 'Pokemon',
        subtitle:
            'Entrada inicial do ecossistema Pokemon dentro do TCG BH, com biblioteca conectada a API e espaco pronto para futuras expansoes.',
        sourceLabel: 'Fonte: Pokemon TCG API',
        accent: Color(0xFFD62828),
        heroIcon: Icons.catching_pokemon,
        libraryRoute: '/pokemon/library',
        collectionRoute: '/pokemon/collection',
        deckRoute: '/pokemon/decks',
        salesRoute: '/pokemon/sales',
        marketplaceRoute: '/pokemon/marketplace',
        wantedRoute: '/pokemon/wanted',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/pokemon/library',
      builder: (context, state) => const PokemonLibraryScreen(),
    ),
    GoRoute(
      path: '/pokemon/collection',
      builder: (context, state) =>
          const TcgCollectionScreen(game: TcgGame.pokemon),
    ),
    GoRoute(
      path: '/pokemon/decks',
      builder: (context, state) => const TcgDecksScreen(game: TcgGame.pokemon),
    ),
    GoRoute(
      path: '/pokemon/sales',
      builder: (context, state) => const TcgSalesScreen(game: TcgGame.pokemon),
    ),
    GoRoute(
      path: '/pokemon/marketplace',
      builder: (context, state) =>
          const TcgMarketplaceScreen(game: TcgGame.pokemon),
    ),
    GoRoute(
      path: '/pokemon/wanted',
      builder: (context, state) => const TcgWantedScreen(game: TcgGame.pokemon),
    ),
    GoRoute(
      path: '/riftbound',
      builder: (context, state) => const TcgHubScreen(
        title: 'Riftbound',
        subtitle:
            'Entrada inicial do ecossistema Riftbound dentro do TCG BH, com biblioteca conectada ao Riftcodex e espaco para consolidar modulos depois.',
        sourceLabel: 'Fonte: Riftcodex',
        accent: Color(0xFF2563EB),
        heroIcon: Icons.bolt_outlined,
        libraryRoute: '/riftbound/library',
        collectionRoute: '/riftbound/collection',
        deckRoute: '/riftbound/decks',
        salesRoute: '/riftbound/sales',
        marketplaceRoute: '/riftbound/marketplace',
        wantedRoute: '/riftbound/wanted',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/riftbound/library',
      builder: (context, state) => const RiftboundLibraryScreen(),
    ),
    GoRoute(
      path: '/riftbound/collection',
      builder: (context, state) =>
          const TcgCollectionScreen(game: TcgGame.riftbound),
    ),
    GoRoute(
      path: '/riftbound/decks',
      builder: (context, state) =>
          const TcgDecksScreen(game: TcgGame.riftbound),
    ),
    GoRoute(
      path: '/riftbound/sales',
      builder: (context, state) =>
          const TcgSalesScreen(game: TcgGame.riftbound),
    ),
    GoRoute(
      path: '/riftbound/marketplace',
      builder: (context, state) =>
          const TcgMarketplaceScreen(game: TcgGame.riftbound),
    ),
    GoRoute(
      path: '/riftbound/wanted',
      builder: (context, state) =>
          const TcgWantedScreen(game: TcgGame.riftbound),
    ),
    GoRoute(
      path: '/yugioh',
      builder: (context, state) => const TcgHubScreen(
        title: 'Yu-Gi-Oh',
        subtitle:
            'Entrada inicial do ecossistema Yu-Gi-Oh dentro do TCG BH, com biblioteca conectada ao YGOPRODeck e espaco para modulos futuros.',
        sourceLabel: 'Fonte: YGOPRODeck',
        accent: Color(0xFF4A4E9B),
        heroIcon: Icons.auto_awesome_outlined,
        libraryRoute: '/yugioh/library',
        collectionRoute: '/yugioh/collection',
        deckRoute: '/yugioh/decks',
        salesRoute: '/yugioh/sales',
        marketplaceRoute: '/yugioh/marketplace',
        wantedRoute: '/yugioh/wanted',
        highlights: ['Busca em API', 'Preços por edição', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/yugioh/library',
      builder: (context, state) => const YugiohLibraryScreen(),
    ),
    GoRoute(
      path: '/yugioh/collection',
      builder: (context, state) =>
          const TcgCollectionScreen(game: TcgGame.yugioh),
    ),
    GoRoute(
      path: '/yugioh/decks',
      builder: (context, state) => const TcgDecksScreen(game: TcgGame.yugioh),
    ),
    GoRoute(
      path: '/yugioh/sales',
      builder: (context, state) => const TcgSalesScreen(game: TcgGame.yugioh),
    ),
    GoRoute(
      path: '/yugioh/marketplace',
      builder: (context, state) =>
          const TcgMarketplaceScreen(game: TcgGame.yugioh),
    ),
    GoRoute(
      path: '/yugioh/wanted',
      builder: (context, state) => const TcgWantedScreen(game: TcgGame.yugioh),
    ),
    GoRoute(
      path: '/integrations/liga-one-piece-test',
      builder: (context, state) => const LigaOnePieceTestScreen(),
    ),
    GoRoute(
      path: '/admin/liga-prices',
      builder: (context, state) => const LigaPriceAdminScreen(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const OnePieceLibraryScreen(),
    ),
    GoRoute(
      path: '/marketplace',
      builder: (context, state) => const GlobalMarketplaceScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/wanted',
      builder: (context, state) => const WantedCardsScreen(),
    ),
    GoRoute(
      path: '/library/card/:cardCode',
      builder: (context, state) {
        final cardCode = state.pathParameters['cardCode'] ?? '';
        final imageUrl = state.uri.queryParameters['image'];
        final cardName = state.uri.queryParameters['name'];
        final extraCard = state.extra is OpCard ? state.extra as OpCard : null;
        return LibraryCardDetailsScreen(
          cardCode: cardCode,
          preferredImageUrl: imageUrl,
          preferredName: cardName,
          initialCard: extraCard,
        );
      },
    ),
    GoRoute(
      path: '/library/compare',
      builder: (context, state) {
        final rawCodes = state.uri.queryParameters['codes'] ?? '';
        final codes = rawCodes
            .split(',')
            .map(Uri.decodeComponent)
            .map((code) => code.trim())
            .where((code) => code.isNotEmpty)
            .toList(growable: false);
        return LibraryCompareScreen(cardCodes: codes);
      },
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => const CollectionScreen(),
    ),
    GoRoute(
      path: '/weeklies',
      builder: (context, state) => const WeeklySelectorScreen(),
    ),
    GoRoute(
      path: '/weeklies/pokemon',
      builder: (context, state) => const PokemonWeeklyReportScreen(),
    ),
    GoRoute(
      path: '/weeklies/:gameSlug',
      builder: (context, state) => WeeklyDashboardScreen(
        gameSlug: state.pathParameters['gameSlug'] ?? 'one-piece',
      ),
    ),
    GoRoute(path: '/sales', builder: (context, state) => const SalesScreen()),
    GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
    GoRoute(
      path: '/code-import',
      builder: (context, state) => CodeImportScreen(
        initialDestination: _parseDestination(
          state.uri.queryParameters['destination'],
        ),
      ),
    ),
    GoRoute(
      path: '/image-import',
      builder: (context, state) => ImageImportScreen(
        initialImageSource: state.extra,
        initialDestination: _parseDestination(
          state.uri.queryParameters['destination'],
        ),
      ),
    ),
    GoRoute(
      path: '/camera-import',
      builder: (context, state) => CameraImportScreen(
        initialDestination: _parseDestination(
          state.uri.queryParameters['destination'],
        ),
      ),
    ),
    GoRoute(
      path: '/card-scan-test',
      builder: (context, state) => const CardScanTestScreen(),
    ),
  ],
);

String _parseDestination(String? rawDestination) {
  if (CollectionTypes.all.contains(rawDestination)) {
    return rawDestination!;
  }

  return CollectionTypes.owned;
}
