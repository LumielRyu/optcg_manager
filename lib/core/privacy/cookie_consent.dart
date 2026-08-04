import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/hive_boxes.dart';

const cookiePolicyVersion = '2026-08-04';

class CookieConsent {
  final bool analytics;
  final bool personalizedAds;
  final DateTime updatedAt;

  const CookieConsent({
    required this.analytics,
    required this.personalizedAds,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'version': cookiePolicyVersion,
    'analytics': analytics,
    'personalized_ads': personalizedAds,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CookieConsent.fromJson(Map<String, dynamic> json) => CookieConsent(
    analytics: json['analytics'] == true,
    personalizedAds: json['personalized_ads'] == true,
    updatedAt:
        DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
        DateTime.now(),
  );
}

class CookieConsentState {
  final CookieConsent? consent;
  final bool showBanner;

  const CookieConsentState({required this.consent, required this.showBanner});
}

final cookieConsentProvider =
    StateNotifierProvider<CookieConsentNotifier, CookieConsentState>((ref) {
      return CookieConsentNotifier();
    });

class CookieConsentNotifier extends StateNotifier<CookieConsentState> {
  static const _storageKey = 'cookie_consent';

  CookieConsentNotifier() : super(_load());

  static CookieConsentState _load() {
    final raw = Hive.box(HiveBoxes.appPrefs).get(_storageKey);
    if (raw is! Map) {
      return const CookieConsentState(consent: null, showBanner: true);
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['version'] != cookiePolicyVersion) {
      return const CookieConsentState(consent: null, showBanner: true);
    }
    return CookieConsentState(
      consent: CookieConsent.fromJson(json),
      showBanner: false,
    );
  }

  Future<void> save({
    required bool analytics,
    required bool personalizedAds,
  }) async {
    final consent = CookieConsent(
      analytics: analytics,
      personalizedAds: personalizedAds,
      updatedAt: DateTime.now(),
    );
    await Hive.box(HiveBoxes.appPrefs).put(_storageKey, consent.toJson());
    state = CookieConsentState(consent: consent, showBanner: false);
  }

  Future<void> acceptAll() => save(analytics: true, personalizedAds: true);

  Future<void> rejectOptional() =>
      save(analytics: false, personalizedAds: false);
}

class CookieConsentLayer extends ConsumerWidget {
  final Widget child;

  const CookieConsentLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cookieConsentProvider);
    return Stack(
      children: [
        child,
        if (state.showBanner)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(child: _CookieBanner(ref: ref)),
          ),
      ],
    );
  }
}

class _CookieBanner extends StatelessWidget {
  final WidgetRef ref;

  const _CookieBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 18,
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cookie_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sua privacidade no TCG BH',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Usamos armazenamento necessário para login e preferências. Analytics e publicidade permanecem opcionais e ainda não estão ativos.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(cookieConsentProvider.notifier)
                        .rejectOptional(),
                    child: const Text('Recusar opcionais'),
                  ),
                  OutlinedButton(
                    onPressed: () => showCookiePreferencesDialog(context, ref),
                    child: const Text('Configurar'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        ref.read(cookieConsentProvider.notifier).acceptAll(),
                    child: const Text('Aceitar todos'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCookiePreferencesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final saved = ref.read(cookieConsentProvider).consent;
  var analytics = saved?.analytics ?? false;
  var personalizedAds = saved?.personalizedAds ?? false;
  final result = await showDialog<(bool, bool)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Preferências de privacidade'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SwitchListTile(
                value: true,
                onChanged: null,
                title: Text('Armazenamento necessário'),
                subtitle: Text(
                  'Login, segurança, tema e funcionamento básico. Sempre ativo.',
                ),
              ),
              SwitchListTile(
                value: analytics,
                onChanged: (value) => setState(() => analytics = value),
                title: const Text('Medição e analytics'),
                subtitle: const Text(
                  'Será usado para entender o uso do site quando esse recurso for ativado.',
                ),
              ),
              SwitchListTile(
                value: personalizedAds,
                onChanged: (value) => setState(() => personalizedAds = value),
                title: const Text('Publicidade personalizada'),
                subtitle: const Text(
                  'Será usado pelo provedor de anúncios somente após sua ativação.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (analytics, personalizedAds)),
            child: const Text('Salvar preferências'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  await ref
      .read(cookieConsentProvider.notifier)
      .save(analytics: result.$1, personalizedAds: result.$2);
}
