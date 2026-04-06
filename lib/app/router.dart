import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_gate.dart';
import '../features/auth/register_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/shared_sale_card_screen.dart';
import '../features/collection/shared_store_screen.dart';
import '../features/decks/shared_deck_screen.dart';
import '../features/home/home_screen.dart';
import '../features/imports/camera_import/camera_import_screen.dart';
import '../features/imports/code_import/code_import_screen.dart';
import '../features/imports/image_import/image_import_screen.dart';
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
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final loggedIn = user != null;
    final location = state.uri.path;

    final isRegisterRoute = location == '/register';
    final isRootRoute = location == '/';
    final isSharedDeckRoute = location.startsWith('/shared/deck/');
    final isSharedSaleRoute = location.startsWith('/shared/sale/');
    final isSharedStoreRoute = location.startsWith('/shared/store/');
    final isSharedRoute =
        isSharedDeckRoute || isSharedSaleRoute || isSharedStoreRoute;

    final isPublicRoute = isRootRoute || isRegisterRoute || isSharedRoute;

    if (isSharedRoute) {
      return null;
    }

    if (!loggedIn && !isPublicRoute) {
      return '/';
    }

    if (loggedIn && (isRootRoute || isRegisterRoute)) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
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
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => const CollectionScreen(),
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => const SalesScreen(),
    ),
    GoRoute(
      path: '/code-import',
      builder: (context, state) => const CodeImportScreen(),
    ),
    GoRoute(
      path: '/image-import',
      builder: (context, state) => ImageImportScreen(
        initialImageSource: state.extra,
      ),
    ),
    GoRoute(
      path: '/camera-import',
      builder: (context, state) => const CameraImportScreen(),
    ),
  ],
);