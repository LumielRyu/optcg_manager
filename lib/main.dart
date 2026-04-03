import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'data/local/hive_init.dart';

List<CameraDescription> appCameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveInit.init();
  await dotenv.load(fileName: '.env');

  debugPrint('SUPABASE_URL = ${dotenv.env['SUPABASE_URL']}');
  debugPrint('SUPABASE_ANON_KEY = ${dotenv.env['SUPABASE_ANON_KEY'] != null ? 'OK' : 'NULL'}');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw Exception('SUPABASE_URL não foi carregada do .env');
  }

  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY não foi carregada do .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  try {
    appCameras = await availableCameras();
  } catch (_) {
    appCameras = [];
  }

  runApp(
    const ProviderScope(
      child: OptcgManagerApp(),
    ),
  );
}