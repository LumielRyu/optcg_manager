import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/services/app_error_reporter.dart';
import 'data/local/hive_init.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addObserver(_AppMemoryPressureObserver());

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppErrorReporter.reportFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppErrorReporter.report(error, stackTrace, context: 'platform-dispatcher');
    return true;
  };

  if (kIsWeb) {
    final imageCache = PaintingBinding.instance.imageCache;
    final mobileWeb =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    imageCache.maximumSize = mobileWeb ? 48 : 120;
    imageCache.maximumSizeBytes = (mobileWeb ? 20 : 48) * 1024 * 1024;
  }

  final supabaseUrl = _supabaseUrl.trim();
  final supabaseAnonKey = _supabaseAnonKey.trim();

  if (supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL nao foi informada no build.');
  }

  if (supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY nao foi informada no build.');
  }

  // Local storage and the Supabase client do not depend on each other. Doing
  // both cold-start tasks in parallel reduces time spent behind the HTML app
  // loader without changing what is ready before the first widget is built.
  await Future.wait<dynamic>([
    HiveInit.init(),
    Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey),
  ]);

  runApp(const ProviderScope(child: OptcgManagerApp()));
}

class _AppMemoryPressureObserver extends WidgetsBindingObserver {
  void _releaseDecodedImages() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  @override
  void didHaveMemoryPressure() {
    _releaseDecodedImages();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _releaseDecodedImages();
    }
  }
}
