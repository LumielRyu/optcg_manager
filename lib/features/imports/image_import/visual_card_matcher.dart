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

  const VisualCardMatchResult({
    required this.card,
    required this.distance,
  });
}

class _VisualFingerprint {
  final String code;
  final String fullHash;
  final String artHash;
  final String footerHash;
  final List<int> avgRgb;

  const _VisualFingerprint({
    required this.code,
    required this.fullHash,
    required this.artHash,
    required this.footerHash,
    required this.avgRgb,
  });

  factory _VisualFingerprint.fromJson(Map<String, dynamic> json) {
    final avg = (json['avgRgb'] as List? ?? const [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .toList();

    return _VisualFingerprint(
      code: (json['code'] ?? '').toString().trim().toUpperCase(),
      fullHash: (json['fullHash'] ?? '').toString(),
      artHash: (json['artHash'] ?? '').toString(),
      footerHash: (json['footerHash'] ?? '').toString(),
      avgRgb: avg.length >= 3 ? avg.take(3).toList() : const [0, 0, 0],
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
  List<_VisualFingerprint>? _databaseCache;

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
  }) async {
    final fingerprints = await _loadFingerprintDatabase();
    if (fingerprints.isEmpty || cards.isEmpty) return const [];

    final source = _computeSourceFingerprint(sourceBytes);
    if (source == null) return const [];

    final cardsByCode = <String, OpCard>{for (final card in cards) card.code: card};
    final results = <VisualCardMatchResult>[];

    for (final fingerprint in fingerprints) {
      final card = cardsByCode[fingerprint.code];
      if (card == null) continue;

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

      final score = fullDistance * 2 + artDistance * 3 + footerDistance + rgbDistance;

      results.add(
        VisualCardMatchResult(
          card: card,
          distance: score,
        ),
      );
    }

    results.sort((a, b) => a.distance.compareTo(b.distance));
    return results.take(limit).toList();
  }

  Future<List<_VisualFingerprint>> _loadFingerprintDatabase() async {
    if (_databaseCache != null) return _databaseCache!;

    try {
      final raw = await rootBundle.loadString('assets/visual_card_fingerprints.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _databaseCache = const [];
        return _databaseCache!;
      }

      _databaseCache = decoded
          .whereType<Map>()
          .map((item) => _VisualFingerprint.fromJson(Map<String, dynamic>.from(item)))
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

  _SourceFingerprint? _computeSourceFingerprint(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final full = _extractLikelyCardRegion(decoded);
    final art = cropBox(full, 0.08, 0.08, 0.92, 0.78);
    final footer = cropBox(full, 0.05, 0.74, 0.95, 0.98);

    return _SourceFingerprint(
      fullHash: _differenceHash(full).toRadixString(16).padLeft(16, '0'),
      artHash: _differenceHash(art).toRadixString(16).padLeft(16, '0'),
      footerHash: _differenceHash(footer).toRadixString(16).padLeft(16, '0'),
      avgRgb: _averageRgb(full),
    );
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

  img.Image _fallbackCentralCrop(img.Image source) {
    final cropWidth = max(1, (source.width * 0.74).round());
    final cropHeight = max(1, (source.height * 0.9).round());
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
    var bitIndex = 0;

    for (var y = 0; y < grayscale.height; y++) {
      for (var x = 0; x < grayscale.width - 1; x++) {
        final left = grayscale.getPixel(x, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        if (left > right) {
          hash |= (BigInt.one << bitIndex);
        }
        bitIndex++;
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
    return _hammingDistance(BigInt.parse(a, radix: 16), BigInt.parse(b, radix: 16));
  }

  int _rgbDistance(List<int> a, List<int> b) {
    if (a.length < 3 || b.length < 3) return 255;
    return ((a[0] - b[0]).abs() + (a[1] - b[1]).abs() + (a[2] - b[2]).abs()) ~/ 12;
  }
}
