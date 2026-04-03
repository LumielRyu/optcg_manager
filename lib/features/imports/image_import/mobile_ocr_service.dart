import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MobileOcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> readTextFromFile(String path) async {
    final inputImage = InputImage.fromFile(File(path));
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}