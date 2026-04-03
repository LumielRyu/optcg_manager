import 'package:go_router/go_router.dart';

import '../features/auth/auth_gate.dart';
import '../features/auth/register_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/decks/shared_deck_screen.dart';
import '../features/home/home_screen.dart';
import '../features/imports/camera_import/camera_import_screen.dart';
import '../features/imports/code_import/code_import_screen.dart';
import '../features/imports/image_import/image_import_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => const CollectionScreen(),
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
    GoRoute(
      path: '/shared/deck/:shareCode',
      builder: (context, state) => SharedDeckScreen(
        shareCode: state.pathParameters['shareCode']!,
      ),
    ),
  ],
);