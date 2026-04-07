import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../features/home/home_screen.dart';
import '../features/imports/camera_import/camera_import_screen.dart';
import '../features/imports/code_import/code_import_screen.dart';
import '../features/imports/image_import/image_import_screen.dart';
import '../features/library/library_card_details_screen.dart';
import '../features/library/library_compare_screen.dart';
import '../features/library/one_piece_library_screen.dart';
import '../features/marketplace/global_marketplace_screen.dart';
import '../features/sales/sales_screen.dart';

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
        isRootRoute || isRegisterRoute || isSharedRoute || isCompleteProfileRoute;

    if (isSharedRoute) {
      return null;
    }

    if (!loggedIn && !isPublicRoute) {
      return '/';
    }

    if (loggedIn) {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('whatsapp_phone, name')
          .eq('id', user.id)
          .maybeSingle();
      final whatsAppPhone = (row?['whatsapp_phone'] ?? '').toString().trim();
      final displayName = (row?['name'] ?? '').toString().trim();
      final needsCompletion = whatsAppPhone.isEmpty || displayName.isEmpty;

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
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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
