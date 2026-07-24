import 'dart:io';

import 'package:image/image.dart' as image;

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
    File(
      '${outputDirectory.path}/plate_$plate.png',
    ).writeAsBytesSync(image.encodePng(_grayscaleForTint(transparent)));
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

    final maximum = [red, green, blue].reduce((a, b) => a > b ? a : b);
    final minimum = [red, green, blue].reduce((a, b) => a < b ? a : b);
    final saturation = maximum == 0 ? 0.0 : (maximum - minimum) / maximum;
    final bodyWeight = ((saturation - 0.06) / 0.16).clamp(0.0, 1.0);
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

  File(
    '${outputDirectory.path}/plate_3_body.png',
  ).writeAsBytesSync(image.encodePng(_grayscaleForTint(body)));
  File(
    '${outputDirectory.path}/plate_3_detail.png',
  ).writeAsBytesSync(image.encodePng(_grayscaleForTint(detail)));

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
    if (pixel.a == 0) continue;
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
