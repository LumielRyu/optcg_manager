import 'dart:ui';

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

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppErrorReporter.reportFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppErrorReporter.report(error, stackTrace, context: 'platform-dispatcher');
    return true;
  };

  await HiveInit.init();

  final supabaseUrl = _supabaseUrl.trim();
  final supabaseAnonKey = _supabaseAnonKey.trim();

  if (supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL nao foi informada no build.');
  }

  if (supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY nao foi informada no build.');
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: OptcgManagerApp()));
}
