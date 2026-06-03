import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../../data/models/op_card.dart';

class VisualCardMatchResult {
  final OpCard card;
  final int distance;

  const VisualCardMatchResult({required this.card, required this.distance});
}

class VisualCardCatalogEntry {
  final String code;
  final String name;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String color;
  final String type;
  final String fullHash;
  final String artHash;
  final String footerHash;
  final List<int> avgRgb;

  const VisualCardCatalogEntry({
    required this.code,
    required this.name,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.color,
    required this.type,
    required this.fullHash,
    required this.artHash,
    required this.footerHash,
    required this.avgRgb,
  });

  factory VisualCardCatalogEntry.fromJson(Map<String, dynamic> json) {
    final avg = (json['avgRgb'] as List? ?? const [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();

    return VisualCardCatalogEntry(
      code: (json['code'] ?? '').toString().trim().toUpperCase(),
      name: (json['name'] ?? '').toString().trim(),
      imageUrl: (json['imageUrl'] ?? '').toString().trim(),
      setName: (json['setName'] ?? '').toString().trim(),
      rarity: (json['rarity'] ?? '').toString().trim(),
      color: (json['color'] ?? '').toString().trim(),
      type: (json['type'] ?? '').toString().trim(),
      fullHash: (json['fullHash'] ?? '').toString(),
      artHash: (json['artHash'] ?? '').toString(),
      footerHash: (json['footerHash'] ?? '').toString(),
      avgRgb: avg.length >= 3 ? avg.take(3).toList() : const [0, 0, 0],
    );
  }

  OpCard toCard({OpCard? fallback}) {
    return OpCard(
      code: code,
      name: name.isNotEmpty ? name : fallback?.name ?? code,
      image: imageUrl.isNotEmpty ? imageUrl : fallback?.image ?? '',
      setName: setName.isNotEmpty ? setName : fallback?.setName ?? '',
      rarity: rarity.isNotEmpty ? rarity : fallback?.rarity ?? '',
      color: color.isNotEmpty ? color : fallback?.color ?? '',
      type: type.isNotEmpty ? type : fallback?.type ?? '',
      subTypes: fallback?.subTypes ?? '',
      text: fallback?.text ?? '',
      attribute: fallback?.attribute ?? '',
    );
  }
}

class _SourceFingerprint {
  final String fullHash;
  final String artHash;
  final String footerHash;
  final List<int> avgRgb;

  const _SourceFingerprint({
    required this.fullHash,
    required this.artHash,
    required this.footerHash,
    required this.avgRgb,
  });
}

class VisualCardMatcher {
  final Map<String, BigInt> _hashCache = {};
  final Map<String, BigInt> _hexHashCache = {};
  List<VisualCardCatalogEntry>? _databaseCache;

  Future<List<VisualCardMatchResult>> rankCandidates({
    required Uint8List sourceBytes,
    required List<OpCard> candidates,
    int limit = 3,
  }) async {
    if (candidates.isEmpty) return const [];

    final sourceHash = _computeSourceHash(sourceBytes);
    if (sourceHash == null) return const [];

    final results = <VisualCardMatchResult>[];

    for (final card in candidates) {
      final imageUrl = card.image.trim();
      if (imageUrl.isEmpty) continue;

      final targetHash = await _getTargetHash(imageUrl);
      if (targetHash == null) continue;

      results.add(
        VisualCardMatchResult(
          card: card,
          distance: _hammingDistance(sourceHash, targetHash),
        ),
      );
    }

    results.sort((a, b) => a.distance.compareTo(b.distance));
    return results.take(limit).toList();
  }

  Future<List<VisualCardMatchResult>> rankAgainstFingerprintDatabase({
    required Uint8List sourceBytes,
    required List<OpCard> cards,
    int limit = 3,
    bool fastMode = false,
  }) async {
    final fingerprints = await _loadFingerprintDatabase();
    return rankAgainstCatalog(
      sourceBytes: sourceBytes,
      cards: cards,
      fingerprints: fingerprints,
      limit: limit,
      fastMode: fastMode,
    );
  }

  List<VisualCardMatchResult> rankAgainstCatalog({
    required Uint8List sourceBytes,
    required List<OpCard> cards,
    required List<VisualCardCatalogEntry> fingerprints,
    int limit = 3,
    bool fastMode = false,
  }) {
    if (fingerprints.isEmpty || cards.isEmpty) return const [];

    final sourceVariants = _computeSourceFingerprints(
      sourceBytes,
      fastMode: fastMode,
    );
    if (sourceVariants.isEmpty) return const [];

    final cardsByCode = <String, OpCard>{
      for (final card in cards) card.code: card,
    };
    final results = <VisualCardMatchResult>[];

    for (final fingerprint in fingerprints) {
      final fallback = cardsByCode[fingerprint.code];
      if (fallback == null) continue;
      final card = fingerprint.toCard(fallback: fallback);

      var score = 999999;
      for (final source in sourceVariants) {
        final fullDistance = _hammingDistanceFromHex(
          source.fullHash,
          fingerprint.fullHash,
        );
        final artDistance = _hammingDistanceFromHex(
          source.artHash,
          fingerprint.artHash,
        );
        final footerDistance = _hammingDistanceFromHex(
          source.footerHash,
          fingerprint.footerHash,
        );
        final rgbDistance = _rgbDistance(source.avgRgb, fingerprint.avgRgb);

        score = min(
          score,
          fullDistance * 2 + artDistance * 3 + footerDistance + rgbDistance,
        );
      }

      results.add(VisualCardMatchResult(card: card, distance: score));
    }

    results.sort((a, b) => a.distance.compareTo(b.distance));
    return results.take(limit).toList();
  }

  Future<List<VisualCardCatalogEntry>> _loadFingerprintDatabase() async {
    if (_databaseCache != null) return _databaseCache!;

    try {
      final raw = await rootBundle.loadString(
        'assets/visual_card_fingerprints.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _databaseCache = const [];
        return _databaseCache!;
      }

      _databaseCache = decoded
          .whereType<Map>()
          .map(
            (item) => VisualCardCatalogEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.code.isNotEmpty)
          .toList();
      return _databaseCache!;
    } catch (_) {
      _databaseCache = const [];
      return _databaseCache!;
    }
  }

  BigInt? _computeSourceHash(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final cropped = _extractLikelyCardRegion(decoded);
    return _differenceHash(cropped);
  }

  List<_SourceFingerprint> _computeSourceFingerprints(
    Uint8List bytes, {
    bool fastMode = false,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const [];

    final oriented = img.bakeOrientation(decoded);
    final variants = _candidateCardRegions(oriented, fastMode: fastMode)
        .expand((item) => _lightingAdjustedVariants(item, fastMode: fastMode))
        .toList(growable: false);
    final fingerprints = <_SourceFingerprint>[];

    for (final full in variants) {
      final art = cropBox(full, 0.08, 0.08, 0.92, 0.78);
      final footer = cropBox(full, 0.05, 0.74, 0.95, 0.98);

      fingerprints.add(
        _SourceFingerprint(
          fullHash: _differenceHash(full).toRadixString(16).padLeft(16, '0'),
          artHash: _differenceHash(art).toRadixString(16).padLeft(16, '0'),
          footerHash: _differenceHash(
            footer,
          ).toRadixString(16).padLeft(16, '0'),
          avgRgb: _averageRgb(full),
        ),
      );
    }

    return fingerprints;
  }

  Future<BigInt?> _getTargetHash(String imageUrl) async {
    if (_hashCache.containsKey(imageUrl)) {
      return _hashCache[imageUrl];
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;

      final decoded = img.decodeImage(response.bodyBytes);
      if (decoded == null) return null;

      final hash = _differenceHash(decoded);
      _hashCache[imageUrl] = hash;
      return hash;
    } catch (_) {
      return null;
    }
  }

  img.Image _extractLikelyCardRegion(img.Image source) {
    final preview = img.copyResize(
      source,
      width: 180,
      height: max(180, (source.height * (180 / source.width)).round()),
      interpolation: img.Interpolation.average,
    );

    final threshold = _estimateBrightThreshold(preview);
    final maskBounds = _findLargestBrightRegion(preview, threshold);

    if (maskBounds == null) {
      return _fallbackCentralCrop(source);
    }

    final scaleX = source.width / preview.width;
    final scaleY = source.height / preview.height;
    final x = max(0, (maskBounds.$1 * scaleX).round());
    final y = max(0, (maskBounds.$2 * scaleY).round());
    final width = min(
      source.width - x,
      max(1, (maskBounds.$3 * scaleX).round()),
    );
    final height = min(
      source.height - y,
      max(1, (maskBounds.$4 * scaleY).round()),
    );

    if (width < source.width * 0.25 || height < source.height * 0.35) {
      return _fallbackCentralCrop(source);
    }

    return img.copyCrop(source, x: x, y: y, width: width, height: height);
  }

  List<img.Image> _candidateCardRegions(
    img.Image source, {
    bool fastMode = false,
  }) {
    if (fastMode) {
      return [
        source,
        _fallbackCentralCrop(source),
        _centralCrop(source, widthRatio: 0.82, heightRatio: 0.94),
      ];
    }

    return [
      _fallbackCentralCrop(source),
      _centralCrop(source, widthRatio: 0.82, heightRatio: 0.94),
      _centralCrop(source, widthRatio: 0.68, heightRatio: 0.88),
      ..._centeredCardAspectCrops(source),
      source,
    ];
  }

  Iterable<img.Image> _lightingAdjustedVariants(
    img.Image source, {
    bool fastMode = false,
  }) sync* {
    yield source;

    final luma = _averageLuma(source);
    if (fastMode) {
      if (luma < 125) {
        yield img.adjustColor(
          source,
          brightness: 1.34,
          gamma: 0.74,
          contrast: 1.08,
        );
      }
      return;
    }

    if (luma < 150) {
      yield img.adjustColor(
        source,
        brightness: 1.22,
        gamma: 0.82,
        contrast: 1.08,
      );
    }

    if (luma < 115) {
      yield img.adjustColor(
        source,
        brightness: 1.48,
        gamma: 0.68,
        contrast: 1.12,
      );
    }
  }

  List<img.Image> _centeredCardAspectCrops(img.Image source) {
    const cardAspectRatio = 0.715;
    const widthRatios = [0.42, 0.48, 0.54, 0.60, 0.66, 0.72, 0.78];

    return widthRatios
        .map((widthRatio) {
          final heightRatio =
              (widthRatio * source.width / source.height / cardAspectRatio)
                  .clamp(0.1, 1.0);
          return _centralCrop(
            source,
            widthRatio: widthRatio,
            heightRatio: heightRatio,
          );
        })
        .toList(growable: false);
  }

  img.Image _fallbackCentralCrop(img.Image source) {
    return _centralCrop(source, widthRatio: 0.74, heightRatio: 0.9);
  }

  img.Image _centralCrop(
    img.Image source, {
    required double widthRatio,
    required double heightRatio,
  }) {
    final cropWidth = max(1, (source.width * widthRatio).round());
    final cropHeight = max(1, (source.height * heightRatio).round());
    final offsetX = max(0, ((source.width - cropWidth) / 2).round());
    final offsetY = max(0, ((source.height - cropHeight) / 2).round());

    return img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );
  }

  int _estimateBrightThreshold(img.Image source) {
    var total = 0;
    var count = 0;

    for (var y = 0; y < source.height; y += 2) {
      for (var x = 0; x < source.width; x += 2) {
        final pixel = source.getPixel(x, y);
        final brightness =
            ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3).round();
        total += brightness;
        count++;
      }
    }

    final average = count == 0 ? 180 : (total / count).round();
    return min(245, max(165, average + 20));
  }

  (int, int, int, int)? _findLargestBrightRegion(
    img.Image source,
    int threshold,
  ) {
    final visited = List.generate(
      source.height,
      (_) => List<bool>.filled(source.width, false),
    );

    (int, int, int, int)? best;
    var bestArea = 0;

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (visited[y][x] || !_isBright(source.getPixel(x, y), threshold)) {
          continue;
        }

        final queue = <(int, int)>[(x, y)];
        visited[y][x] = true;

        var minX = x;
        var minY = y;
        var maxX = x;
        var maxY = y;
        var pixels = 0;

        while (queue.isNotEmpty) {
          final current = queue.removeLast();
          final cx = current.$1;
          final cy = current.$2;
          pixels++;

          minX = min(minX, cx);
          minY = min(minY, cy);
          maxX = max(maxX, cx);
          maxY = max(maxY, cy);

          for (final (nx, ny) in [
            (cx - 1, cy),
            (cx + 1, cy),
            (cx, cy - 1),
            (cx, cy + 1),
          ]) {
            if (nx < 0 ||
                ny < 0 ||
                nx >= source.width ||
                ny >= source.height ||
                visited[ny][nx]) {
              continue;
            }

            visited[ny][nx] = true;
            if (_isBright(source.getPixel(nx, ny), threshold)) {
              queue.add((nx, ny));
            }
          }
        }

        final width = maxX - minX + 1;
        final height = maxY - minY + 1;
        final area = width * height;
        final ratio = height / max(1, width);

        final looksLikeCard = ratio > 1.2 && ratio < 1.8;
        final enoughPixels = pixels > 300;

        if (looksLikeCard && enoughPixels && area > bestArea) {
          bestArea = area;
          best = (minX, minY, width, height);
        }
      }
    }

    return best;
  }

  bool _isBright(img.Pixel pixel, int threshold) {
    final brightness =
        ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3).round();
    return brightness >= threshold;
  }

  BigInt _differenceHash(img.Image image) {
    final grayscale = img.grayscale(_cropAndResizeForHash(image));
    var hash = BigInt.zero;

    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width - 1; x++) {
        final left = grayscale.getPixel(x, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        hash <<= 1;
        if (left > right) {
          hash |= BigInt.one;
        }
      }
    }

    return hash;
  }

  img.Image _cropAndResizeForHash(img.Image image) {
    return img.copyResize(
      image,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );
  }

  img.Image cropBox(
    img.Image image,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    final width = image.width;
    final height = image.height;

    return img.copyCrop(
      image,
      x: max(0, (width * left).round()),
      y: max(0, (height * top).round()),
      width: max(1, (width * (right - left)).round()),
      height: max(1, (height * (bottom - top)).round()),
    );
  }

  List<int> _averageRgb(img.Image image) {
    final resized = img.copyResize(
      image,
      width: 32,
      height: 32,
      interpolation: img.Interpolation.average,
    );

    var r = 0;
    var g = 0;
    var b = 0;
    var count = 0;

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        r += pixel.r.toInt();
        g += pixel.g.toInt();
        b += pixel.b.toInt();
        count++;
      }
    }

    if (count == 0) return const [0, 0, 0];
    return [r ~/ count, g ~/ count, b ~/ count];
  }

  int _averageLuma(img.Image image) {
    final resized = img.copyResize(
      image,
      width: 24,
      height: 24,
      interpolation: img.Interpolation.average,
    );

    var total = 0;
    var count = 0;

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        total += _pixelLuma(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        count++;
      }
    }

    if (count == 0) return 180;
    return total ~/ count;
  }

  int _hammingDistance(BigInt a, BigInt b) {
    var value = a ^ b;
    var count = 0;

    while (value > BigInt.zero) {
      count++;
      value &= (value - BigInt.one);
    }

    return count;
  }

  int _hammingDistanceFromHex(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 64;
    return _hammingDistance(_parseHexHash(a), _parseHexHash(b));
  }

  BigInt _parseHexHash(String value) {
    return _hexHashCache[value] ??= BigInt.parse(value, radix: 16);
  }

  int _rgbDistance(List<int> a, List<int> b) {
    if (a.length < 3 || b.length < 3) return 40;

    final normalizedA = _normalizeRgbBrightness(a);
    final normalizedB = _normalizeRgbBrightness(b);
    final chromaDistance =
        ((normalizedA[0] - normalizedB[0]).abs() +
            (normalizedA[1] - normalizedB[1]).abs() +
            (normalizedA[2] - normalizedB[2]).abs()) ~/
        18;
    final brightnessDistance = (_rgbLuma(a) - _rgbLuma(b)).abs() ~/ 34;

    return min(35, chromaDistance + brightnessDistance);
  }

  List<int> _normalizeRgbBrightness(List<int> rgb) {
    final luma = max(32, _rgbLuma(rgb));
    final scale = 128 / luma;
    return [
      (rgb[0] * scale).round().clamp(0, 255),
      (rgb[1] * scale).round().clamp(0, 255),
      (rgb[2] * scale).round().clamp(0, 255),
    ];
  }

  int _rgbLuma(List<int> rgb) {
    if (rgb.length < 3) return 0;
    return _pixelLuma(rgb[0], rgb[1], rgb[2]);
  }

  int _pixelLuma(int r, int g, int b) {
    return ((r * 299) + (g * 587) + (b * 114)) ~/ 1000;
  }
}
