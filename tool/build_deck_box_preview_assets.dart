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

  for (var plate = 1; plate <= 7; plate++) {
    final source = File('${sourceDirectory.path}/plate_$plate.png');
    if (!source.existsSync()) {
      stderr.writeln('Preview ausente: ${source.path}');
      exitCode = 66;
      return;
    }
    source.copySync('${outputDirectory.path}/plate_$plate.png');
  }

  final tokenSource = File('${sourceDirectory.path}/plate_3.png');
  final decoded = image.decodePng(tokenSource.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Nao foi possivel decodificar ${tokenSource.path}.');
    exitCode = 65;
    return;
  }

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
  ).writeAsBytesSync(image.encodePng(body));
  File(
    '${outputDirectory.path}/plate_3_detail.png',
  ).writeAsBytesSync(image.encodePng(detail));

  stdout.writeln(
    'Previews originais e camadas das fichas gerados em '
    '${outputDirectory.path}.',
  );
}
