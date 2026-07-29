import 'tcg_deck_rules.dart';

class RiftboundTextDeckEntry {
  final int quantity;
  final String cardName;
  final TcgDeckZone zone;

  const RiftboundTextDeckEntry({
    required this.quantity,
    required this.cardName,
    required this.zone,
  });
}

class RiftboundTextDeckParseResult {
  final List<RiftboundTextDeckEntry> entries;
  final List<String> errors;

  const RiftboundTextDeckParseResult({
    required this.entries,
    required this.errors,
  });

  int get totalCards =>
      entries.fold(0, (total, entry) => total + entry.quantity);
  bool get isValid => entries.isNotEmpty && errors.isEmpty;
}

RiftboundTextDeckParseResult parseRiftboundTextDeck(String raw) {
  final entries = <RiftboundTextDeckEntry>[];
  final errors = <String>[];
  TcgDeckZone? currentZone;

  final lines = raw.split(RegExp(r'\r?\n'));
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;

    if (line.endsWith(':')) {
      final section = _zoneForSection(line.substring(0, line.length - 1));
      if (section == null) {
        errors.add('Linha ${index + 1}: seção desconhecida “$line”.');
      } else {
        currentZone = section;
      }
      continue;
    }

    final match = RegExp(
      r'^(\d+)\s*(?:x\s*)?(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) {
      errors.add(
        'Linha ${index + 1}: use o formato “quantidade nome da carta”.',
      );
      continue;
    }
    if (currentZone == null) {
      errors.add('Linha ${index + 1}: informe uma seção antes das cartas.');
      continue;
    }

    final quantity = int.tryParse(match.group(1) ?? '') ?? 0;
    final cardName = (match.group(2) ?? '').trim();
    if (quantity <= 0 || cardName.isEmpty) {
      errors.add('Linha ${index + 1}: quantidade ou nome inválido.');
      continue;
    }

    entries.add(
      RiftboundTextDeckEntry(
        quantity: quantity,
        cardName: cardName,
        zone: currentZone,
      ),
    );
  }

  final aggregated = <String, RiftboundTextDeckEntry>{};
  for (final entry in entries) {
    final key =
        '${entry.zone.name}|${normalizeRiftboundCardName(entry.cardName)}';
    final existing = aggregated[key];
    aggregated[key] = RiftboundTextDeckEntry(
      quantity: (existing?.quantity ?? 0) + entry.quantity,
      cardName: existing?.cardName ?? entry.cardName,
      zone: entry.zone,
    );
  }

  if (aggregated.isEmpty && errors.isEmpty) {
    errors.add('Nenhuma carta foi encontrada na lista.');
  }

  return RiftboundTextDeckParseResult(
    entries: aggregated.values.toList(growable: false),
    errors: errors,
  );
}

String normalizeRiftboundCardName(String value) {
  return value
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\(\s*chosen\s*\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeRiftboundBaseCardName(String value) {
  return normalizeRiftboundCardName(
    value.replaceAll(
      RegExp(
        r'\s*\((?:alternate art|starter|metal|overnumbered|signature|promo)\)\s*$',
        caseSensitive: false,
      ),
      '',
    ),
  );
}

TcgDeckZone? _zoneForSection(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return switch (normalized) {
    'legend' => TcgDeckZone.legend,
    'champion' || 'chosenchampion' => TcgDeckZone.chosenChampion,
    'maindeck' || 'deck' => TcgDeckZone.main,
    'battlefield' || 'battlefields' => TcgDeckZone.battlefield,
    'rune' || 'runes' || 'resources' => TcgDeckZone.resource,
    'sideboard' || 'sidedeck' => TcgDeckZone.side,
    _ => null,
  };
}
