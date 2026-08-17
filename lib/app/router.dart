import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/collection_types.dart';
import '../core/tcg/tcg_game.dart';
import '../core/utils/admin_access.dart';
import '../data/models/op_card.dart';
import '../data/repositories/user_preferences_repository.dart';
import '../features/admin/liga_price_admin_screen.dart' deferred as liga_admin;
import '../features/auth/auth_gate.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/help/help_screen.dart';
import '../features/home/home_screen.dart';
import '../features/integrations/liga_one_piece_test_screen.dart'
    deferred as liga_test;
import '../features/imports/camera_import/camera_import_screen.dart'
    deferred as camera_import;
import '../features/imports/card_scan_test/card_scan_test_screen.dart'
    deferred as scan_test;
import '../features/imports/code_import/code_import_screen.dart'
    deferred as code_import;
import '../features/imports/image_import/image_import_screen.dart'
    deferred as image_import;
import '../features/legal/legal_document_screen.dart';
import '../features/marketplace/global_marketplace_screen.dart'
    deferred as global_marketplace;
import '../features/products/products_screen.dart' deferred as products;
import '../features/profile/profile_screen.dart';
import '../features/tcg/tcg_hub_screen.dart';
import '../features/tcg/tcg_selector_screen.dart';
import '../features/weeklies/pokemon_weekly_report_screen.dart'
    deferred as pokemon_weekly;
import '../features/weeklies/weekly_dashboard_screen.dart'
    deferred as weekly_dashboard;
import '../features/weeklies/weekly_selector_screen.dart'
    deferred as weekly_selector;
import 'deferred/one_piece_routes.dart' deferred as op_routes;
import 'deferred/shared_routes.dart' deferred as shared_routes;
import 'deferred/tcg_routes.dart' deferred as tcg_routes;

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
    final isProfileRoute = location == '/profile';
    final isLegalRoute = const {
      '/privacy',
      '/cookies',
      '/terms',
      '/contact',
    }.contains(location);
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
      if (isProfileRoute) {
        return '/login';
      }

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

      if (needsCompletion &&
          !isCompleteProfileRoute &&
          !isSharedRoute &&
          !isLegalRoute) {
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
        return _DeferredRoute(
          loadLibrary: shared_routes.loadLibrary,
          builder: () => shared_routes.deckScreen(shareCode: shareCode),
        );
      },
    ),
    GoRoute(
      path: '/shared/sale/:shareCode',
      builder: (context, state) {
        final shareCode = state.pathParameters['shareCode'] ?? '';
        return _DeferredRoute(
          loadLibrary: shared_routes.loadLibrary,
          builder: () => shared_routes.saleScreen(shareCode: shareCode),
        );
      },
    ),
    GoRoute(
      path: '/shared/store/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        return _DeferredRoute(
          loadLibrary: shared_routes.loadLibrary,
          builder: () => shared_routes.storeScreen(userId: userId),
        );
      },
    ),
    GoRoute(
      path: '/shared/wanted/:gameSlug/:userId',
      builder: (context, state) {
        final game = TcgGame.fromSlug(state.pathParameters['gameSlug']);
        final userId = state.pathParameters['userId'] ?? '';
        return _DeferredRoute(
          loadLibrary: tcg_routes.loadLibrary,
          builder: () => tcg_routes.wantedScreen(game, sharedUserId: userId),
        );
      },
    ),
    GoRoute(
      path: '/shared/wanted/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        return _DeferredRoute(
          loadLibrary: shared_routes.loadLibrary,
          builder: () => shared_routes.wantedScreen(userId: userId),
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const TcgSelectorScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) =>
          const LegalDocumentScreen(type: LegalDocumentType.privacy),
    ),
    GoRoute(
      path: '/cookies',
      builder: (context, state) =>
          const LegalDocumentScreen(type: LegalDocumentType.cookies),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) =>
          const LegalDocumentScreen(type: LegalDocumentType.terms),
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) =>
          const LegalDocumentScreen(type: LegalDocumentType.contact),
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
        importRoute: '/digimon/import',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/digimon/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.libraryScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.collectionScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/decks',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.decksScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.salesScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.marketplaceScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.wantedScreen(TcgGame.digimon),
      ),
    ),
    GoRoute(
      path: '/digimon/import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.importScreen(TcgGame.digimon),
      ),
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
        importRoute: '/magic/import',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/magic/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.libraryScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.collectionScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/decks',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.decksScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.salesScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.marketplaceScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.wantedScreen(TcgGame.magic),
      ),
    ),
    GoRoute(
      path: '/magic/import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.importScreen(TcgGame.magic),
      ),
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
        importRoute: '/pokemon/import',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/pokemon/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.libraryScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.collectionScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/decks',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.decksScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.salesScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.marketplaceScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.wantedScreen(TcgGame.pokemon),
      ),
    ),
    GoRoute(
      path: '/pokemon/import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.importScreen(TcgGame.pokemon),
      ),
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
        importRoute: '/riftbound/import',
        highlights: ['Busca em API', 'Preços Liga', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/riftbound/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.libraryScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.collectionScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/decks',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.decksScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.salesScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.marketplaceScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.wantedScreen(TcgGame.riftbound),
      ),
    ),
    GoRoute(
      path: '/riftbound/import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.importScreen(TcgGame.riftbound),
      ),
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
        importRoute: '/yugioh/import',
        highlights: ['Busca em API', 'Preços por edição', 'Coleção'],
      ),
    ),
    GoRoute(
      path: '/yugioh/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.libraryScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.collectionScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/decks',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.decksScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.salesScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.marketplaceScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.wantedScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/yugioh/import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: tcg_routes.loadLibrary,
        builder: () => tcg_routes.importScreen(TcgGame.yugioh),
      ),
    ),
    GoRoute(
      path: '/integrations/liga-one-piece-test',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: liga_test.loadLibrary,
        builder: () => liga_test.LigaOnePieceTestScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/liga-prices',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: liga_admin.loadLibrary,
        builder: () => liga_admin.LigaPriceAdminScreen(),
      ),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: op_routes.loadLibrary,
        builder: () => op_routes.libraryScreen(),
      ),
    ),
    GoRoute(
      path: '/marketplace',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: global_marketplace.loadLibrary,
        builder: () => global_marketplace.GlobalMarketplaceScreen(),
      ),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: products.loadLibrary,
        builder: () => products.ProductsScreen(),
      ),
    ),
    GoRoute(
      path: '/wanted',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: op_routes.loadLibrary,
        builder: () => op_routes.wantedScreen(),
      ),
    ),
    GoRoute(
      path: '/library/card/:cardCode',
      builder: (context, state) {
        final cardCode = state.pathParameters['cardCode'] ?? '';
        final imageUrl = state.uri.queryParameters['image'];
        final cardName = state.uri.queryParameters['name'];
        final extraCard = state.extra is OpCard ? state.extra as OpCard : null;
        return _DeferredRoute(
          loadLibrary: op_routes.loadLibrary,
          builder: () => op_routes.libraryCardDetailsScreen(
            cardCode: cardCode,
            preferredImageUrl: imageUrl,
            preferredName: cardName,
            initialCard: extraCard,
          ),
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
        return _DeferredRoute(
          loadLibrary: op_routes.loadLibrary,
          builder: () => op_routes.libraryCompareScreen(cardCodes: codes),
        );
      },
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: op_routes.loadLibrary,
        builder: () => op_routes.collectionScreen(),
      ),
    ),
    GoRoute(
      path: '/weeklies',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: weekly_selector.loadLibrary,
        builder: () => weekly_selector.WeeklySelectorScreen(),
      ),
    ),
    GoRoute(
      path: '/weeklies/pokemon',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: pokemon_weekly.loadLibrary,
        builder: () => pokemon_weekly.PokemonWeeklyReportScreen(),
      ),
    ),
    GoRoute(
      path: '/weeklies/:gameSlug',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: weekly_dashboard.loadLibrary,
        builder: () => weekly_dashboard.WeeklyDashboardScreen(
          gameSlug: state.pathParameters['gameSlug'] ?? 'one-piece',
        ),
      ),
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: op_routes.loadLibrary,
        builder: () => op_routes.salesScreen(),
      ),
    ),
    GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
    GoRoute(
      path: '/code-import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: code_import.loadLibrary,
        builder: () => code_import.CodeImportScreen(
          initialDestination: _parseDestination(
            state.uri.queryParameters['destination'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/image-import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: image_import.loadLibrary,
        builder: () => image_import.ImageImportScreen(
          initialImageSource: state.extra,
          initialDestination: _parseDestination(
            state.uri.queryParameters['destination'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/camera-import',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: camera_import.loadLibrary,
        builder: () => camera_import.CameraImportScreen(
          initialDestination: _parseDestination(
            state.uri.queryParameters['destination'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/card-scan-test',
      builder: (context, state) => _DeferredRoute(
        loadLibrary: scan_test.loadLibrary,
        builder: () => scan_test.CardScanTestScreen(),
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

class _DeferredRoute extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const _DeferredRoute({required this.loadLibrary, required this.builder});

  @override
  State<_DeferredRoute> createState() => _DeferredRouteState();
}

class _DeferredRouteState extends State<_DeferredRoute> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadLibrary();
  }

  void _retry() {
    setState(() => _loadFuture = widget.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Semantics(
                label: 'Carregando pagina',
                child: const CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    const Text('Nao foi possivel carregar esta pagina.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.builder();
      },
    );
  }
}
