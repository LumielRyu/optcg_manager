import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

class CardOcrService {
  Future<String> readTextFromFile(String path) async {
    return _recognize(path);
  }

  Future<String> readTextFromBytes(Uint8List bytes) async {
    final base64Image = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Image';
    return _recognize(dataUrl);
  }

  Future<String> _recognize(String source) async {
    final tesseract = js_util.getProperty<Object?>(html.window, 'Tesseract');
    if (tesseract == null) {
      throw Exception('Tesseract.js nao foi carregado no navegador.');
    }

    final options = js_util.jsify({
      'logger': (dynamic message) {
        final status = js_util.getProperty<Object?>(message, 'status');
        final progress = js_util.getProperty<Object?>(message, 'progress');
        if (status != null) {
          // ignore: avoid_print
          print('[Tesseract][web] $status ${progress ?? ''}');
        }
      },
    });

    final promise = js_util.callMethod<Object?>(
      tesseract,
      'recognize',
      [source, 'eng', options],
    );

    final result = await js_util.promiseToFuture<Object?>(promise as Object);
    final data = js_util.getProperty<Object?>(result as Object, 'data');
    final text = data == null ? null : js_util.getProperty<Object?>(data, 'text');
    return (text ?? '').toString();
  }

  Future<void> dispose() async {}
}
