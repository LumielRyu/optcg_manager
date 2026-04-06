import 'dart:typed_data';

import 'mobile_ocr_service.dart';

class CardOcrService {
  MobileOcrService? _mobileOcrService;

  Future<String> readTextFromFile(String path) async {
    final service = _mobileOcrService ??= MobileOcrService();
    return service.readTextFromFile(path);
  }

  Future<String> readTextFromBytes(Uint8List bytes) async {
    throw UnsupportedError(
      'OCR por bytes nao e suportado fora do navegador.',
    );
  }

  Future<void> dispose() async {
    await _mobileOcrService?.dispose();
  }
}
