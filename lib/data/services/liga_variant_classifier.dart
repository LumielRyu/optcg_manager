enum LigaVariantKind {
  normal,
  alternateArt,
  manga,
  treasureCup,
  treasureRare,
  winnerPack,
  winner,
  finalist,
  participant,
  preRelease,
  releaseEvent,
  dashPack,
  fullArt,
  gold,
  anniversary,
  special,
  parallel,
  reprint,
  promotional,
}

class LigaVariantDescriptor {
  final LigaVariantKind kind;
  final String baseCode;
  final String normalizedCode;
  final String suffix;

  const LigaVariantDescriptor({
    required this.kind,
    required this.baseCode,
    required this.normalizedCode,
    required this.suffix,
  });

  bool get requiresStrictMatch => kind != LigaVariantKind.normal;
}

LigaVariantDescriptor classifyLigaVariant({
  required String cardName,
  required String cardCode,
}) {
  final code = cardCode.trim().toUpperCase();
  final suffix = ligaVariantSuffix(code);
  final baseCode = baseLigaCardCode(code);
  final name = normalizeLigaVariantText(cardName);
  final tokens = name.split(' ').where((token) => token.isNotEmpty).toSet();

  LigaVariantKind kind;
  if (name.contains('anniversary') || RegExp(r'^\d+A$').hasMatch(suffix)) {
    kind = LigaVariantKind.anniversary;
  } else if (name.contains('manga') || suffix == 'MA') {
    kind = LigaVariantKind.manga;
  } else if (name.contains('treasure cup') || suffix == 'TC') {
    kind = LigaVariantKind.treasureCup;
  } else if (name.contains('treasure rare') || suffix == 'TR') {
    kind = LigaVariantKind.treasureRare;
  } else if (name.contains('winner pack') || suffix == 'WP') {
    kind = LigaVariantKind.winnerPack;
  } else if (name.contains('winner') || suffix == 'RW') {
    kind = LigaVariantKind.winner;
  } else if (name.contains('finalist')) {
    kind = LigaVariantKind.finalist;
  } else if (name.contains('participant') ||
      name.contains('participation') ||
      suffix == 'OP') {
    kind = LigaVariantKind.participant;
  } else if (name.contains('pre release') ||
      name.contains('prerelease') ||
      suffix == 'PR') {
    kind = LigaVariantKind.preRelease;
  } else if (name.contains('release event') || suffix == 'RE') {
    kind = name.contains('reprint')
        ? LigaVariantKind.reprint
        : LigaVariantKind.releaseEvent;
  } else if (name.contains('dash pack') || suffix == 'DP') {
    kind = LigaVariantKind.dashPack;
  } else if (name.contains('full art') || suffix == 'FA') {
    kind = LigaVariantKind.fullArt;
  } else if (name.contains('gold') || suffix == 'G') {
    kind = LigaVariantKind.gold;
  } else if (name.contains('reprint')) {
    kind = LigaVariantKind.reprint;
  } else if (tokens.contains('sp') ||
      tokens.contains('spr') ||
      name.contains('special') ||
      suffix == 'SP') {
    kind = LigaVariantKind.special;
  } else if (name.contains('parallel') ||
      const {'PA', 'PAR', 'E', 'A', 'P'}.contains(suffix)) {
    kind = LigaVariantKind.parallel;
  } else if (name.contains('alternate art') ||
      name.contains('alt art') ||
      suffix == 'AA') {
    kind = LigaVariantKind.alternateArt;
  } else if (_looksPromotional(name)) {
    kind = LigaVariantKind.promotional;
  } else {
    kind = LigaVariantKind.normal;
  }

  return LigaVariantDescriptor(
    kind: kind,
    baseCode: baseCode,
    normalizedCode: code,
    suffix: suffix,
  );
}

String inferPrimaryLigaVariantCode({
  required String cardName,
  required String cardCode,
}) {
  final descriptor = classifyLigaVariant(
    cardName: cardName,
    cardCode: cardCode,
  );
  if (descriptor.suffix.isNotEmpty) return descriptor.normalizedCode;
  final suffix = switch (descriptor.kind) {
    LigaVariantKind.alternateArt => 'AA',
    LigaVariantKind.manga => 'MA',
    LigaVariantKind.treasureCup => 'TC',
    LigaVariantKind.treasureRare => 'TR',
    LigaVariantKind.winnerPack => 'WP',
    LigaVariantKind.winner => 'RW',
    LigaVariantKind.participant => 'OP',
    LigaVariantKind.preRelease => 'PR',
    LigaVariantKind.releaseEvent => 'RE',
    LigaVariantKind.dashPack => 'DP',
    LigaVariantKind.fullArt => 'FA',
    LigaVariantKind.gold => 'G',
    LigaVariantKind.anniversary => _anniversarySuffix(cardName),
    LigaVariantKind.special => 'SP',
    LigaVariantKind.parallel => 'PA',
    LigaVariantKind.reprint => 'RE',
    LigaVariantKind.normal ||
    LigaVariantKind.finalist ||
    LigaVariantKind.promotional => '',
  };
  return suffix.isEmpty
      ? descriptor.normalizedCode
      : '${descriptor.baseCode}-$suffix';
}

List<String> inferLigaVariantCandidateCodes({
  required String cardName,
  required String cardCode,
}) {
  final normalizedCode = cardCode.trim().toUpperCase();
  if (normalizedCode.isEmpty) return const [];
  final descriptor = classifyLigaVariant(
    cardName: cardName,
    cardCode: normalizedCode,
  );
  final primary = inferPrimaryLigaVariantCode(
    cardName: cardName,
    cardCode: normalizedCode,
  );

  if (descriptor.kind == LigaVariantKind.alternateArt ||
      descriptor.kind == LigaVariantKind.parallel) {
    return <String>{
      primary,
      '${descriptor.baseCode}-AA',
      '${descriptor.baseCode}-PA',
      '${descriptor.baseCode}-PAR',
      '${descriptor.baseCode}-E',
      '${descriptor.baseCode}-A',
      '${descriptor.baseCode}-P',
      descriptor.baseCode,
    }.toList(growable: false);
  }
  if (descriptor.requiresStrictMatch) {
    return <String>{primary, descriptor.baseCode}.toList(growable: false);
  }
  return <String>{primary, descriptor.baseCode}.toList(growable: false);
}

bool ligaVariantKindsCompatible(
  LigaVariantKind requested,
  LigaVariantKind candidate,
) {
  if (requested == candidate) return true;
  const alternateFamily = {
    LigaVariantKind.alternateArt,
    LigaVariantKind.parallel,
  };
  return alternateFamily.contains(requested) &&
      alternateFamily.contains(candidate);
}

bool ligaVariantMatchesEditionHint(
  LigaVariantKind requested,
  LigaVariantKind candidate,
  String editionCode,
) {
  if (ligaVariantKindsCompatible(requested, candidate)) return true;
  if (candidate != LigaVariantKind.normal) return false;
  final edition = editionCode.trim().toUpperCase();
  return switch (requested) {
    LigaVariantKind.releaseEvent ||
    LigaVariantKind.reprint => edition.endsWith('-RE'),
    LigaVariantKind.preRelease => edition.endsWith('-PR'),
    _ => false,
  };
}

String baseLigaCardCode(String cardCode) {
  final normalized = cardCode.trim().toUpperCase().split('@').first;
  return normalized.replaceFirst(
    RegExp(r'-(?:\d+A|AA|DP|FA|G|MA|OP|PA|PAR|PR|RE|RW|SP|TC|TR|WP|E|A|P)$'),
    '',
  );
}

String ligaVariantSuffix(String cardCode) {
  final normalized = cardCode.trim().toUpperCase().split('@').first;
  final match = RegExp(
    r'-(\d+A|AA|DP|FA|G|MA|OP|PA|PAR|PR|RE|RW|SP|TC|TR|WP|E|A|P)$',
  ).firstMatch(normalized);
  return match?.group(1) ?? '';
}

String normalizeLigaVariantText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String ligaVariantKindLabel(LigaVariantKind kind) {
  return switch (kind) {
    LigaVariantKind.normal => 'Comum',
    LigaVariantKind.alternateArt => 'Alternate Art',
    LigaVariantKind.manga => 'Manga',
    LigaVariantKind.treasureCup => 'Treasure Cup',
    LigaVariantKind.treasureRare => 'Treasure Rare',
    LigaVariantKind.winnerPack => 'Winner Pack',
    LigaVariantKind.winner => 'Winner',
    LigaVariantKind.finalist => 'Finalist',
    LigaVariantKind.participant => 'Participante',
    LigaVariantKind.preRelease => 'Pre-release',
    LigaVariantKind.releaseEvent => 'Release Event',
    LigaVariantKind.dashPack => 'Dash Pack',
    LigaVariantKind.fullArt => 'Full Art',
    LigaVariantKind.gold => 'Gold',
    LigaVariantKind.anniversary => 'Anniversary',
    LigaVariantKind.special => 'SP / Special',
    LigaVariantKind.parallel => 'Parallel',
    LigaVariantKind.reprint => 'Reprint',
    LigaVariantKind.promotional => 'Promocional',
  };
}

String _anniversarySuffix(String cardName) {
  final normalized = normalizeLigaVariantText(cardName);
  final match = RegExp(
    r'\b(\d+)(?:st|nd|rd|th)?\s+anniversary\b',
  ).firstMatch(normalized);
  final number = match?.group(1);
  return number == null || number.isEmpty ? '' : '${number}A';
}

bool _looksPromotional(String name) {
  return name.contains('regional') ||
      name.contains('championship') ||
      name.contains('event pack') ||
      name.contains('promotion pack') ||
      name.contains('promo pack') ||
      name.contains('gift collection') ||
      name.contains('trophy card');
}
