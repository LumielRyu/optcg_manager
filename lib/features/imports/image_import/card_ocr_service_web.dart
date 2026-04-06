import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
    final tesseract = (web.window as JSObject).getProperty('Tesseract'.toJS);
    if (tesseract == null) {
      throw Exception('Tesseract.js não foi carregado no navegador.');
    }

    final promise = (tesseract as JSObject).callMethod(
      'recognize'.toJS,
      source.toJS,
      'eng'.toJS,
    ) as JSPromise<JSAny?>;

    final result = await promise.toDart;
    final data = (result as JSObject).getProperty('data'.toJS);
    final text = data == null
        ? null
        : (data as JSObject).getProperty('text'.toJS);
    return (text ?? '').toString();
  }

  Future<void> dispose() async {}
}
