class OcrCodeExtractor {
  static List<String> extractDeckLines(String rawText) {
    final normalized = rawText
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[|;,]'), '\n');

    final lines = normalized
        .split('\n')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final results = <String>[];

    for (final line in lines) {
      final cleaned = line.replaceAll(' ', '');

      // 4xOP14-020
      final direct = RegExp(r'^(\d+)X([A-Z0-9\-]+)$').firstMatch(cleaned);
      if (direct != null) {
        final qty = direct.group(1)!;
        final code = _normalizeCode(direct.group(2)!);
        if (code != null) {
          results.add('${qty}x$code');
          continue;
        }
      }

      // OP14-020
      final codeOnly = _normalizeCode(cleaned);
      if (codeOnly != null) {
        results.add('1x$codeOnly');
        continue;
      }

      // Ex.: 4 OP14020
      final spaced = RegExp(r'^(\d+)\s*X?\s*([A-Z0-9\-]+)$').firstMatch(line);
      if (spaced != null) {
        final qty = spaced.group(1)!;
        final code = _normalizeCode(spaced.group(2)!.replaceAll(' ', ''));
        if (code != null) {
          results.add('${qty}x$code');
        }
      }
    }

    return _dedupe(results);
  }

  static String? _normalizeCode(String input) {
    var code = input.trim().toUpperCase();
    code = code.replaceAll('_', '-');
    code = code.replaceAll('—', '-');
    code = code.replaceAll('–', '-');
    code = code.replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    if (code.isEmpty) return null;

    // OP14020 -> OP14-020
    final setStyle = RegExp(r'^([A-Z]{1,4}\d{1,2})(\d{3}(?:[A-Z0-9\-]*)?)$');
    final m1 = setStyle.firstMatch(code.replaceAll('-', ''));
    if (m1 != null) {
      return '${m1.group(1)}-${m1.group(2)}';
    }

    // P044 -> P-044
    final promoStyle = RegExp(r'^([A-Z]{1,3})(\d{3})$');
    final m2 = promoStyle.firstMatch(code.replaceAll('-', ''));
    if (m2 != null) {
      return '${m2.group(1)}-${m2.group(2)}';
    }

    // já válido
    if (RegExp(r'^[A-Z0-9]{1,6}-[A-Z0-9]{2,}$').hasMatch(code)) {
      return code;
    }

    return null;
  }

  static List<String> _dedupe(List<String> lines) {
    final seen = <String>{};
    final result = <String>[];

    for (final line in lines) {
      if (seen.add(line)) {
        result.add(line);
      }
    }

    return result;
  }
}