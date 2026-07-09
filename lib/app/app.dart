import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/collection_view_mode_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../data/repositories/auth_repository.dart';
import 'router.dart';

const Color _techVoid = Color(0xFF060A10);
const Color _techNavy = Color(0xFF0A1720);
const Color _techPanel = Color(0xFF0F2029);
const Color _techPanelSoft = Color(0xFF18323B);
const Color _techCyan = Color(0xFF28D7E8);
const Color _techBlue = Color(0xFF4F8CFF);
const Color _techAmber = Color(0xFFF4B740);
const Color _techPaper = Color(0xFFF4F7FB);
const Color _techPaperPanel = Color(0xFFFFFFFF);
const Color _techInk = Color(0xFF101923);

class OptcgManagerApp extends ConsumerWidget {
  const OptcgManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF006B78),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD4F7FB),
      onPrimaryContainer: Color(0xFF001F25),
      secondary: Color(0xFF2D5BD3),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFDDE6FF),
      onSecondaryContainer: Color(0xFF081A50),
      tertiary: Color(0xFFAE5D00),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFE2B8),
      onTertiaryContainer: Color(0xFF351900),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: _techPaper,
      onSurface: _techInk,
      surfaceContainerHighest: Color(0xFFE4EAF1),
      onSurfaceVariant: Color(0xFF52606D),
      outline: Color(0xFF82909D),
      outlineVariant: Color(0xFFC7D1DB),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: _techNavy,
      onInverseSurface: _techPaper,
      inversePrimary: _techCyan,
      surfaceTint: Color(0xFF006B78),
    );

    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _techCyan,
      onPrimary: Color(0xFF001F25),
      primaryContainer: Color(0xFF0B4652),
      onPrimaryContainer: Color(0xFFBDF4FB),
      secondary: _techBlue,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF1B356C),
      onSecondaryContainer: Color(0xFFDCE6FF),
      tertiary: _techAmber,
      onTertiary: Color(0xFF281800),
      tertiaryContainer: Color(0xFF5B3A00),
      onTertiaryContainer: Color(0xFFFFE1A6),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _techVoid,
      onSurface: Color(0xFFEAF2F7),
      surfaceContainerHighest: _techPanelSoft,
      onSurfaceVariant: Color(0xFFB4C6D0),
      outline: Color(0xFF4B6571),
      outlineVariant: Color(0xFF243D48),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: _techPaper,
      onInverseSurface: _techVoid,
      inversePrimary: Color(0xFF006B78),
      surfaceTint: _techCyan,
    );

    return MaterialApp.router(
      title: 'OPTCG BH',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      themeMode: themeMode,
      theme: _buildTheme(lightScheme),
      darkTheme: _buildTheme(darkScheme),
      builder: (context, child) {
        return _PreferenceBootstrapper(child: child ?? const SizedBox.shrink());
      },
    );
  }

  ThemeData _buildTheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? _techVoid.withValues(alpha: 0.96)
            : _techPaperPanel.withValues(alpha: 0.96),
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
        color: dark
            ? _techPanel.withValues(alpha: 0.82)
            : _techPaperPanel.withValues(alpha: 0.92),
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: dark ? 0.34 : 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: dark
                ? scheme.primary.withValues(alpha: 0.18)
                : scheme.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? _techPanel : _techPaperPanel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark
            ? _techVoid.withValues(alpha: 0.92)
            : _techPaperPanel.withValues(alpha: 0.94),
        elevation: 0,
        height: 72,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.2 : 0.13),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 24,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    ref.listen(authStateProvider, (_, _) {
      _loadPreferences();
    });

    return widget.child;
  }
}
