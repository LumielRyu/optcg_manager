import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/collection_view_mode_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../data/repositories/auth_repository.dart';
import 'router.dart';

const Color _brandInk = Color(0xFF061017);
const Color _brandBlack = Color(0xFF02070C);
const Color _brandPanel = Color(0xFF0A1A20);
const Color _brandPanelSoft = Color(0xFF10272D);
const Color _brandGold = Color(0xFFE6A935);
const Color _brandBronze = Color(0xFFB36C24);
const Color _brandCream = Color(0xFFF4E6C6);
const Color _brandLine = Color(0xFF6B461E);
const Color _brandRuby = Color(0xFFD54C3F);
const Color _brandTeal = Color(0xFF78D8D1);

class OptcgManagerApp extends ConsumerWidget {
  const OptcgManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF7C4C12),
      onPrimary: Color(0xFFFFF3CF),
      primaryContainer: Color(0xFFF3D394),
      onPrimaryContainer: Color(0xFF261604),
      secondary: Color(0xFF8A2C25),
      onSecondary: Color(0xFFFFF4ED),
      secondaryContainer: Color(0xFFF0B9A8),
      onSecondaryContainer: Color(0xFF35100C),
      tertiary: Color(0xFF006E70),
      onTertiary: Color(0xFFF1FFFF),
      tertiaryContainer: Color(0xFFA8E8E3),
      onTertiaryContainer: Color(0xFF002B2C),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF5E8CE),
      onSurface: Color(0xFF241608),
      surfaceContainerHighest: Color(0xFFE6CFA4),
      onSurfaceVariant: Color(0xFF5C4320),
      outline: Color(0xFF856331),
      outlineVariant: Color(0xFFC9A66E),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: _brandPanel,
      onInverseSurface: _brandCream,
      inversePrimary: _brandGold,
      surfaceTint: Color(0xFF7C4C12),
    );

    const darkScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _brandGold,
      onPrimary: Color(0xFF221403),
      primaryContainer: Color(0xFF4E310B),
      onPrimaryContainer: _brandCream,
      secondary: _brandRuby,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF64211B),
      onSecondaryContainer: Color(0xFFFFD8CF),
      tertiary: _brandTeal,
      onTertiary: Color(0xFF00383A),
      tertiaryContainer: Color(0xFF0F4446),
      onTertiaryContainer: Color(0xFFD6FAF8),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _brandInk,
      onSurface: _brandCream,
      surfaceContainerHighest: _brandPanelSoft,
      onSurfaceVariant: Color(0xFFD5C3A0),
      outline: _brandLine,
      outlineVariant: Color(0xFF8B642C),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: _brandCream,
      onInverseSurface: _brandInk,
      inversePrimary: _brandBronze,
      surfaceTint: _brandGold,
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
        backgroundColor: dark ? _brandBlack : const Color(0xFF3A250B),
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
            ? _brandPanel.withValues(alpha: 0.94)
            : const Color(0xFFFFF0CF).withValues(alpha: 0.96),
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: scheme.primary.withValues(alpha: dark ? 0.34 : 0.42),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.72),
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
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? _brandPanel : scheme.surface,
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
            ? _brandBlack.withValues(alpha: 0.98)
            : const Color(0xFFFFF0CF).withValues(alpha: 0.98),
        elevation: 8,
        height: 70,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          side: BorderSide(color: scheme.outlineVariant),
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
