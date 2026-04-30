import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/collection_types.dart';
import '../data/models/op_card.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/shared_sale_card_screen.dart';
import '../features/collection/shared_store_screen.dart';
import '../features/decks/shared_deck_screen.dart';
import '../features/digimon/digimon_library_screen.dart';
import '../features/home/home_screen.dart';
import '../features/integrations/liga_one_piece_test_screen.dart';
import '../features/imports/camera_import/camera_import_screen.dart';
import '../features/imports/code_import/code_import_screen.dart';
import '../features/imports/image_import/image_import_screen.dart';
import '../features/library/library_card_details_screen.dart';
import '../features/library/library_compare_screen.dart';
import '../features/library/one_piece_library_screen.dart';
import '../features/marketplace/global_marketplace_screen.dart';
import '../features/magic/magic_library_screen.dart';
import '../features/pokemon/pokemon_library_screen.dart';
import '../features/riftbound/riftbound_library_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/tcg/tcg_hub_screen.dart';
import '../features/tcg/tcg_selector_screen.dart';
import '../features/yugioh/yugioh_library_screen.dart';
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

    final isRegisterRoute = location == '/register';
    final isCompleteProfileRoute = location == '/complete-profile';
    final isRootRoute = location == '/';
    final isSharedDeckRoute = location.startsWith('/shared/deck/');
    final isSharedSaleRoute = location.startsWith('/shared/sale/');
    final isSharedStoreRoute = location.startsWith('/shared/store/');
    final isSharedRoute =
        isSharedDeckRoute || isSharedSaleRoute || isSharedStoreRoute;

    final isPublicRoute =
        isRootRoute ||
        isRegisterRoute ||
        isSharedRoute ||
        isCompleteProfileRoute;

    if (isSharedRoute) {
      return null;
    }

    if (!loggedIn && !isPublicRoute) {
      return '/';
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

      if (isRootRoute || isRegisterRoute) {
        return needsCompletion ? '/complete-profile' : '/home';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const AuthGate()),
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
            'Entrada inicial do ecossistema Digimon dentro do TCG Manager, com biblioteca conectada a API publica e espaco para futuras expansoes.',
        sourceLabel: 'Fonte: Heroicc Digimon API',
        accent: Color(0xFF0F766E),
        heroIcon: Icons.memory_outlined,
        libraryRoute: '/digimon/library',
        highlights: ['Busca em API', 'Biblioteca inicial'],
      ),
    ),
    GoRoute(
      path: '/digimon/library',
      builder: (context, state) => const DigimonLibraryScreen(),
    ),
    GoRoute(
      path: '/magic',
      builder: (context, state) => const TcgHubScreen(
        title: 'Magic',
        subtitle:
            'Entrada inicial do ecossistema Magic: The Gathering dentro do TCG Manager, com biblioteca conectada ao Scryfall e estrutura pronta para modulos futuros.',
        sourceLabel: 'Fonte: Scryfall',
        accent: Color(0xFFB45309),
        heroIcon: Icons.auto_fix_high_outlined,
        libraryRoute: '/magic/library',
        highlights: ['Busca em API', 'Biblioteca inicial'],
      ),
    ),
    GoRoute(
      path: '/magic/library',
      builder: (context, state) => const MagicLibraryScreen(),
    ),
    GoRoute(
      path: '/pokemon',
      builder: (context, state) => const TcgHubScreen(
        title: 'Pokemon',
        subtitle:
            'Entrada inicial do ecossistema Pokemon dentro do TCG Manager, com biblioteca conectada a API e espaco pronto para futuras expansoes.',
        sourceLabel: 'Fonte: Pokemon TCG API',
        accent: Color(0xFFD62828),
        heroIcon: Icons.catching_pokemon,
        libraryRoute: '/pokemon/library',
        highlights: ['Busca em API', 'Biblioteca inicial'],
      ),
    ),
    GoRoute(
      path: '/pokemon/library',
      builder: (context, state) => const PokemonLibraryScreen(),
    ),
    GoRoute(
      path: '/riftbound',
      builder: (context, state) => const TcgHubScreen(
        title: 'Riftbound',
        subtitle:
            'Entrada inicial do ecossistema Riftbound dentro do TCG Manager, com biblioteca conectada ao Riftcodex e espaco para consolidar modulos depois.',
        sourceLabel: 'Fonte: Riftcodex',
        accent: Color(0xFF2563EB),
        heroIcon: Icons.bolt_outlined,
        libraryRoute: '/riftbound/library',
        highlights: ['Busca em API', 'Biblioteca inicial'],
      ),
    ),
    GoRoute(
      path: '/riftbound/library',
      builder: (context, state) => const RiftboundLibraryScreen(),
    ),
    GoRoute(
      path: '/yugioh',
      builder: (context, state) => const TcgHubScreen(
        title: 'Yu-Gi-Oh',
        subtitle:
            'Entrada inicial do ecossistema Yu-Gi-Oh dentro do TCG Manager, com biblioteca conectada ao YGOPRODeck e espaco para modulos futuros.',
        sourceLabel: 'Fonte: YGOPRODeck',
        accent: Color(0xFF4A4E9B),
        heroIcon: Icons.auto_awesome_outlined,
        libraryRoute: '/yugioh/library',
        highlights: ['Busca em API', 'Biblioteca inicial'],
      ),
    ),
    GoRoute(
      path: '/yugioh/library',
      builder: (context, state) => const YugiohLibraryScreen(),
    ),
    GoRoute(
      path: '/integrations/liga-one-piece-test',
      builder: (context, state) => const LigaOnePieceTestScreen(),
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
    GoRoute(path: '/sales', builder: (context, state) => const SalesScreen()),
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
  ],
);

String _parseDestination(String? rawDestination) {
  if (CollectionTypes.all.contains(rawDestination)) {
    return rawDestination!;
  }

  return CollectionTypes.owned;
}
