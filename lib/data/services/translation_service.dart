import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translateToPortuguese(String text) async {
    if (text.trim().isEmpty) return '';
    final result = await _translator.translate(text, from: 'en', to: 'pt');
    return result.text;
  }
}