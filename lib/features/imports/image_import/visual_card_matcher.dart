import 'dart:math';
import 'dart:typed_data';

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

class VisualCardMatcher {
  final Map<String, BigInt> _hashCache = {};

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

  BigInt? _computeSourceHash(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final cropped = _extractLikelyCardRegion(decoded);
    return _differenceHash(cropped);
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
    final resized = img.copyResize(
      image,
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );
    return resized;
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
}
