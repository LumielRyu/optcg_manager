import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/collection_view_mode_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../data/repositories/auth_repository.dart';
import 'router.dart';

class OptcgManagerApp extends ConsumerWidget {
  const OptcgManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0D5C63),
      onPrimary: Color(0xFFFDFBF7),
      primaryContainer: Color(0xFFD9EEE8),
      onPrimaryContainer: Color(0xFF0A3135),
      secondary: Color(0xFF9B2226),
      onSecondary: Color(0xFFFFF8F5),
      secondaryContainer: Color(0xFFF7D9D1),
      onSecondaryContainer: Color(0xFF3F1114),
      tertiary: Color(0xFFD4A017),
      onTertiary: Color(0xFF2A1B00),
      tertiaryContainer: Color(0xFFF8E7B2),
      onTertiaryContainer: Color(0xFF4C3400),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF7F1E6),
      onSurface: Color(0xFF231F1A),
      surfaceContainerHighest: Color(0xFFE7DDCE),
      onSurfaceVariant: Color(0xFF53463A),
      outline: Color(0xFF857567),
      outlineVariant: Color(0xFFD2C4B4),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF372F28),
      onInverseSurface: Color(0xFFFDF1E3),
      inversePrimary: Color(0xFF84D1CB),
      surfaceTint: Color(0xFF0D5C63),
    );

    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF84D1CB),
      onPrimary: Color(0xFF00373B),
      primaryContainer: Color(0xFF004F56),
      onPrimaryContainer: Color(0xFFD9EEE8),
      secondary: Color(0xFFF0B7AC),
      onSecondary: Color(0xFF5F1D21),
      secondaryContainer: Color(0xFF7D2F34),
      onSecondaryContainer: Color(0xFFFFDAD4),
      tertiary: Color(0xFFF0CC65),
      onTertiary: Color(0xFF3D2D00),
      tertiaryContainer: Color(0xFF5A4300),
      onTertiaryContainer: Color(0xFFFFE08E),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF16130F),
      onSurface: Color(0xFFEDE1D4),
      surfaceContainerHighest: Color(0xFF302821),
      onSurfaceVariant: Color(0xFFD6C3B2),
      outline: Color(0xFF9F8D7D),
      outlineVariant: Color(0xFF53463A),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFEDE1D4),
      onInverseSurface: Color(0xFF372F28),
      inversePrimary: Color(0xFF0D5C63),
      surfaceTint: Color(0xFF84D1CB),
    );

    return MaterialApp.router(
      title: 'OPTCG Manager',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      themeMode: themeMode,
      theme: _buildTheme(lightScheme),
      darkTheme: _buildTheme(darkScheme),
      builder: (context, child) {
        return _PreferenceBootstrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withOpacity(0.94),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface.withOpacity(0.94),
        elevation: 2,
        shadowColor: scheme.shadow.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
      ),
    );
  }
}

class _PreferenceBootstrapper extends ConsumerStatefulWidget {
  final Widget child;

  const _PreferenceBootstrapper({required this.child});

  @override
  ConsumerState<_PreferenceBootstrapper> createState() =>
      _PreferenceBootstrapperState();
}

class _PreferenceBootstrapperState
    extends ConsumerState<_PreferenceBootstrapper> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPreferences);
  }

  Future<void> _loadPreferences() async {
    await ref.read(themeModeProvider.notifier).loadForCurrentUser(force: true);
    await ref
        .read(collectionViewModeProvider.notifier)
        .loadForCurrentUser(force: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, __) {
      _loadPreferences();
    });

    return widget.child;
  }
}
