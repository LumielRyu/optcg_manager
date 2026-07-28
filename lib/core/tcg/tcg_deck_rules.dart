import 'tcg_game.dart';

enum TcgDeckZone {
  main('Deck principal'),
  leader('Lider'),
  resource('Recursos'),
  digiEgg('Digi-Eggs'),
  side('Side Deck'),
  extra('Extra Deck'),
  commander('Comandante'),
  legend('Lenda'),
  chosenChampion('Campeao escolhido'),
  battlefield('Campos de batalha');

  final String label;

  const TcgDeckZone(this.label);
}

enum TcgCopyIdentity { cardNumber, cardName }

class TcgDeckZoneRule {
  final int minimum;
  final int? maximum;
  final Set<int> acceptedCounts;

  const TcgDeckZoneRule({
    required this.minimum,
    this.maximum,
    this.acceptedCounts = const {},
  });

  const TcgDeckZoneRule.exact(int count)
    : minimum = count,
      maximum = count,
      acceptedCounts = const {};

  bool accepts(int count) {
    if (acceptedCounts.isNotEmpty) return acceptedCounts.contains(count);
    return count >= minimum && (maximum == null || count <= maximum!);
  }

  String describe() {
    if (acceptedCounts.isNotEmpty) {
      final values = acceptedCounts.toList()..sort();
      return values.join(' ou ');
    }
    if (maximum == minimum) return 'exatamente $minimum';
    if (maximum == null) return 'no minimo $minimum';
    return 'entre $minimum e $maximum';
  }
}

class TcgDeckFormatRules {
  final TcgGame game;
  final String slug;
  final String label;
  final Map<TcgDeckZone, TcgDeckZoneRule> zones;
  final int defaultCopyLimit;
  final TcgCopyIdentity copyIdentity;
  final bool basicResourcesIgnoreCopyLimit;
  final bool validatesColorOrDomainIdentity;
  final bool supportsDynamicBanList;
  final Set<TcgDeckZone> uniqueCardNameZones;
  final String officialRulesUrl;

  const TcgDeckFormatRules({
    required this.game,
    required this.slug,
    required this.label,
    required this.zones,
    required this.defaultCopyLimit,
    required this.copyIdentity,
    required this.officialRulesUrl,
    this.basicResourcesIgnoreCopyLimit = false,
    this.validatesColorOrDomainIdentity = false,
    this.supportsDynamicBanList = true,
    this.uniqueCardNameZones = const {},
  });
}

class TcgDeckEntry {
  final String cardId;
  final String cardNumber;
  final String cardName;
  final int quantity;
  final TcgDeckZone zone;
  final Set<String> identities;
  final bool isBasicResource;
  final int? copyLimitOverride;

  const TcgDeckEntry({
    required this.cardId,
    required this.cardNumber,
    required this.cardName,
    required this.quantity,
    required this.zone,
    this.identities = const {},
    this.isBasicResource = false,
    this.copyLimitOverride,
  });
}

class TcgDeckValidationContext {
  final Set<String> allowedIdentities;
  final Map<String, int> restrictedCopiesByCardId;

  const TcgDeckValidationContext({
    this.allowedIdentities = const {},
    this.restrictedCopiesByCardId = const {},
  });
}

class TcgDeckValidationResult {
  final List<String> errors;

  const TcgDeckValidationResult(this.errors);

  bool get isValid => errors.isEmpty;
}

class TcgDeckRulesRegistry {
  static const onePieceConstructed = TcgDeckFormatRules(
    game: TcgGame.onePiece,
    slug: 'one-piece-constructed',
    label: 'Construido',
    zones: {
      TcgDeckZone.leader: TcgDeckZoneRule.exact(1),
      TcgDeckZone.main: TcgDeckZoneRule.exact(50),
      TcgDeckZone.resource: TcgDeckZoneRule.exact(10),
    },
    defaultCopyLimit: 4,
    copyIdentity: TcgCopyIdentity.cardNumber,
    basicResourcesIgnoreCopyLimit: true,
    validatesColorOrDomainIdentity: true,
    officialRulesUrl:
        'https://en.onepiece-cardgame.com/pdf/rule_comprehensive.pdf',
  );

  static const pokemonStandard = TcgDeckFormatRules(
    game: TcgGame.pokemon,
    slug: 'pokemon-standard',
    label: 'Padrao',
    zones: {TcgDeckZone.main: TcgDeckZoneRule.exact(60)},
    defaultCopyLimit: 4,
    copyIdentity: TcgCopyIdentity.cardName,
    basicResourcesIgnoreCopyLimit: true,
    officialRulesUrl:
        'https://www.pokemon.com/us/play-pokemon/about/tournaments-rules-and-resources',
  );

  static const digimonConstructed = TcgDeckFormatRules(
    game: TcgGame.digimon,
    slug: 'digimon-constructed',
    label: 'Construido',
    zones: {
      TcgDeckZone.main: TcgDeckZoneRule.exact(50),
      TcgDeckZone.digiEgg: TcgDeckZoneRule(minimum: 0, maximum: 5),
    },
    defaultCopyLimit: 4,
    copyIdentity: TcgCopyIdentity.cardNumber,
    officialRulesUrl: 'https://world.digimoncard.com/rule/pdf/general_rule.pdf',
  );

  static const magicStandard = TcgDeckFormatRules(
    game: TcgGame.magic,
    slug: 'magic-standard',
    label: 'Standard',
    zones: {
      TcgDeckZone.main: TcgDeckZoneRule(minimum: 60),
      TcgDeckZone.side: TcgDeckZoneRule(minimum: 0, maximum: 15),
    },
    defaultCopyLimit: 4,
    copyIdentity: TcgCopyIdentity.cardName,
    basicResourcesIgnoreCopyLimit: true,
    officialRulesUrl: 'https://magic.wizards.com/formats/standard',
  );

  static const magicCommander = TcgDeckFormatRules(
    game: TcgGame.magic,
    slug: 'magic-commander',
    label: 'Commander',
    zones: {
      TcgDeckZone.main: TcgDeckZoneRule.exact(99),
      TcgDeckZone.commander: TcgDeckZoneRule.exact(1),
    },
    defaultCopyLimit: 1,
    copyIdentity: TcgCopyIdentity.cardName,
    basicResourcesIgnoreCopyLimit: true,
    validatesColorOrDomainIdentity: true,
    officialRulesUrl: 'https://magic.wizards.com/pt-br/formats/commander',
  );

  static const riftboundConstructed = TcgDeckFormatRules(
    game: TcgGame.riftbound,
    slug: 'riftbound-constructed',
    label: 'Construido',
    zones: {
      TcgDeckZone.main: TcgDeckZoneRule.exact(39),
      TcgDeckZone.chosenChampion: TcgDeckZoneRule.exact(1),
      TcgDeckZone.legend: TcgDeckZoneRule.exact(1),
      TcgDeckZone.resource: TcgDeckZoneRule.exact(12),
      TcgDeckZone.battlefield: TcgDeckZoneRule.exact(3),
      TcgDeckZone.side: TcgDeckZoneRule(
        minimum: 0,
        maximum: 8,
        acceptedCounts: {0, 8},
      ),
    },
    defaultCopyLimit: 3,
    copyIdentity: TcgCopyIdentity.cardName,
    basicResourcesIgnoreCopyLimit: true,
    validatesColorOrDomainIdentity: true,
    uniqueCardNameZones: {TcgDeckZone.battlefield},
    officialRulesUrl:
        'https://playriftbound.com/en-us/news/organizedplay/riftbound-tournament-rules/',
  );

  static const yugiohAdvanced = TcgDeckFormatRules(
    game: TcgGame.yugioh,
    slug: 'yugioh-advanced',
    label: 'Advanced',
    zones: {
      TcgDeckZone.main: TcgDeckZoneRule(minimum: 40, maximum: 60),
      TcgDeckZone.extra: TcgDeckZoneRule(minimum: 0, maximum: 15),
      TcgDeckZone.side: TcgDeckZoneRule(minimum: 0, maximum: 15),
    },
    defaultCopyLimit: 3,
    copyIdentity: TcgCopyIdentity.cardName,
    officialRulesUrl: 'https://www.yugioh-card.com/en/limited/',
  );

  static const formats = <TcgDeckFormatRules>[
    onePieceConstructed,
    pokemonStandard,
    digimonConstructed,
    magicStandard,
    magicCommander,
    riftboundConstructed,
    yugiohAdvanced,
  ];

  static List<TcgDeckFormatRules> forGame(TcgGame game) =>
      formats.where((format) => format.game == game).toList(growable: false);

  static TcgDeckFormatRules defaultFor(TcgGame game) => forGame(game).first;

  static TcgDeckFormatRules? bySlug(String slug) {
    for (final format in formats) {
      if (format.slug == slug) return format;
    }
    return null;
  }
}

class TcgDeckValidator {
  const TcgDeckValidator();

  TcgDeckValidationResult validate({
    required TcgDeckFormatRules rules,
    required List<TcgDeckEntry> entries,
    TcgDeckValidationContext context = const TcgDeckValidationContext(),
  }) {
    final errors = <String>[];
    final zoneTotals = <TcgDeckZone, int>{};

    for (final entry in entries) {
      if (entry.quantity <= 0) {
        errors.add('${entry.cardName}: quantidade deve ser maior que zero.');
        continue;
      }
      if (!rules.zones.containsKey(entry.zone)) {
        errors.add(
          '${entry.cardName}: zona ${entry.zone.label} nao permitida.',
        );
        continue;
      }
      zoneTotals.update(
        entry.zone,
        (quantity) => quantity + entry.quantity,
        ifAbsent: () => entry.quantity,
      );

      if (rules.validatesColorOrDomainIdentity &&
          context.allowedIdentities.isNotEmpty) {
        final invalid = entry.identities.difference(context.allowedIdentities);
        if (invalid.isNotEmpty) {
          errors.add(
            '${entry.cardName}: identidade ${invalid.join(', ')} '
            'nao permitida pelo deck.',
          );
        }
      }
    }

    for (final zone in rules.zones.entries) {
      final count = zoneTotals[zone.key] ?? 0;
      if (!zone.value.accepts(count)) {
        errors.add(
          '${zone.key.label}: $count cartas; esperado ${zone.value.describe()}.',
        );
      }
    }

    final groupedCopies = <String, int>{};
    final limits = <String, int>{};
    final namesByUniqueZone = <TcgDeckZone, Set<String>>{};
    for (final entry in entries) {
      if (rules.uniqueCardNameZones.contains(entry.zone)) {
        final normalizedName = entry.cardName.trim().toUpperCase();
        final names = namesByUniqueZone.putIfAbsent(entry.zone, () => {});
        if (entry.quantity > 1 || !names.add(normalizedName)) {
          errors.add(
            '${entry.zone.label}: ${entry.cardName} precisa ter nome unico.',
          );
        }
      }
      if (rules.basicResourcesIgnoreCopyLimit && entry.isBasicResource) {
        continue;
      }
      final identity = switch (rules.copyIdentity) {
        TcgCopyIdentity.cardNumber => entry.cardNumber,
        TcgCopyIdentity.cardName => entry.cardName,
      }.trim().toUpperCase();
      if (identity.isEmpty) continue;
      groupedCopies.update(
        identity,
        (quantity) => quantity + entry.quantity,
        ifAbsent: () => entry.quantity,
      );
      final restricted = context.restrictedCopiesByCardId[entry.cardId];
      limits[identity] =
          restricted ?? entry.copyLimitOverride ?? rules.defaultCopyLimit;
    }

    for (final copies in groupedCopies.entries) {
      final limit = limits[copies.key] ?? rules.defaultCopyLimit;
      if (copies.value > limit) {
        errors.add(
          '${copies.key}: ${copies.value} copias; limite atual de $limit.',
        );
      }
    }

    return TcgDeckValidationResult(errors);
  }
}
