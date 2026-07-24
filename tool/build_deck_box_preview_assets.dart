import 'dart:io';

import 'package:image/image.dart' as image;

const filamentColors = <String, (int, int, int)>{
  'preto': (0x17, 0x19, 0x1D),
  'branco': (0xF2, 0xF2, 0xF2),
  'verde': (0x23, 0x8A, 0x52),
  'amarelo': (0xF1, 0xC6, 0x2E),
  'azul': (0x24, 0x58, 0xB8),
  'azul_claro': (0x83, 0xCE, 0xE4),
  'vermelho': (0xC9, 0x38, 0x32),
  'roxo': (0x74, 0x40, 0xA7),
  'laranja': (0xE8, 0x75, 0x25),
  'marrom': (0x76, 0x50, 0x3A),
  'rosa': (0xE5, 0x6F, 0x9F),
};

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Uso: dart run tool/build_deck_box_preview_assets.dart '
      '<diretorio Metadata extraido do 3MF> <diretorio de destino>',
    );
    exitCode = 64;
    return;
  }

  final sourceDirectory = Directory(arguments[0]);
  final outputDirectory = Directory(arguments[1])..createSync(recursive: true);
  if (!sourceDirectory.existsSync()) {
    stderr.writeln('Diretorio de origem nao encontrado: ${arguments[0]}');
    exitCode = 66;
    return;
  }

  image.Image? tokenPreview;
  for (var plate = 1; plate <= 7; plate++) {
    final source = File('${sourceDirectory.path}/plate_$plate.png');
    if (!source.existsSync()) {
      stderr.writeln('Preview ausente: ${source.path}');
      exitCode = 66;
      return;
    }
    final decoded = image.decodePng(source.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('Nao foi possivel decodificar ${source.path}.');
      exitCode = 65;
      return;
    }
    final transparent = _removeBlackBackground(decoded);
    final grayscale = _grayscaleForTint(transparent);
    _writePreviewAndColors(outputDirectory, 'plate_$plate', grayscale);
    if (plate == 3) tokenPreview = transparent;
  }

  final decoded = tokenPreview!;

  final body = image.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 4,
  );
  final detail = image.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 4,
  );

  for (final pixel in decoded) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();
    final alpha = pixel.a.toDouble();
    if (alpha == 0) continue;

    final yellowStrength = (red < green ? red : green) - blue;
    final bodyWeight = ((yellowStrength - 7) / 24).clamp(0.0, 1.0);
    final detailWeight = 1 - bodyWeight;

    body.setPixelRgba(pixel.x, pixel.y, red, green, blue, alpha * bodyWeight);
    detail.setPixelRgba(
      pixel.x,
      pixel.y,
      red,
      green,
      blue,
      alpha * detailWeight,
    );
  }

  _writePreviewAndColors(
    outputDirectory,
    'plate_3_body',
    _grayscaleForTint(body),
  );
  _writePreviewAndColors(
    outputDirectory,
    'plate_3_detail',
    _grayscaleForTint(detail),
  );

  stdout.writeln(
    'Previews originais e camadas das fichas gerados em '
    '${outputDirectory.path}.',
  );
}

image.Image _removeBlackBackground(image.Image source) {
  final width = source.width;
  final height = source.height;
  final background = List<bool>.filled(width * height, false);
  final queue = <int>[];

  void enqueue(int x, int y) {
    final index = y * width + x;
    if (background[index]) return;
    final pixel = source.getPixel(x, y);
    final maximum = [
      pixel.r.toDouble(),
      pixel.g.toDouble(),
      pixel.b.toDouble(),
    ].reduce((a, b) => a > b ? a : b);
    if (maximum > 72) return;
    background[index] = true;
    queue.add(index);
  }

  for (var x = 0; x < width; x++) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  var cursor = 0;
  while (cursor < queue.length) {
    final index = queue[cursor++];
    final x = index % width;
    final y = index ~/ width;
    if (x > 0) enqueue(x - 1, y);
    if (x + 1 < width) enqueue(x + 1, y);
    if (y > 0) enqueue(x, y - 1);
    if (y + 1 < height) enqueue(x, y + 1);
  }

  final output = image.Image(width: width, height: height, numChannels: 4);
  for (final pixel in source) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();
    final alpha = pixel.a.toDouble();
    final index = pixel.y * width + pixel.x;
    output.setPixelRgba(
      pixel.x,
      pixel.y,
      red,
      green,
      blue,
      background[index] ? 0 : alpha,
    );
  }
  return output;
}

image.Image _grayscaleForTint(image.Image source) {
  var maximumLuminance = 1.0;
  for (final pixel in source) {
    if (pixel.a <= 128) continue;
    final luminance =
        pixel.r.toDouble() * 0.2126 +
        pixel.g.toDouble() * 0.7152 +
        pixel.b.toDouble() * 0.0722;
    if (luminance > maximumLuminance) maximumLuminance = luminance;
  }

  final output = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (final pixel in source) {
    final alpha = pixel.a.toDouble();
    if (alpha == 0) continue;
    final luminance =
        pixel.r.toDouble() * 0.2126 +
        pixel.g.toDouble() * 0.7152 +
        pixel.b.toDouble() * 0.0722;
    final normalized = (luminance / maximumLuminance * 255).clamp(0, 255);
    output.setPixelRgba(
      pixel.x,
      pixel.y,
      normalized,
      normalized,
      normalized,
      alpha,
    );
  }
  return output;
}

void _writePreviewAndColors(
  Directory outputDirectory,
  String name,
  image.Image grayscale,
) {
  File(
    '${outputDirectory.path}/$name.png',
  ).writeAsBytesSync(image.encodePng(grayscale));
  for (final entry in filamentColors.entries) {
    File(
      '${outputDirectory.path}/${name}_${entry.key}_calibrated_v2.png',
    ).writeAsBytesSync(
      image.encodePng(_applyFilamentColor(grayscale, entry.value)),
    );
  }
}

image.Image _applyFilamentColor(image.Image source, (int, int, int) color) {
  final output = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  final (targetRed, targetGreen, targetBlue) = color;
  for (final pixel in source) {
    final alpha = pixel.a.toDouble();
    if (alpha == 0) continue;
    final light = pixel.r.toDouble() / 255;
    final shade = 0.42 + light * 0.58;
    output.setPixelRgba(
      pixel.x,
      pixel.y,
      targetRed * shade,
      targetGreen * shade,
      targetBlue * shade,
      alpha,
    );
  }
  return output;
}
