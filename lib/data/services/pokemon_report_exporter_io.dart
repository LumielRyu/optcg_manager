import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> savePokemonReportCsv({
  required String fileName,
  required String csv,
}) async {
  await FilePicker.saveFile(
    dialogTitle: 'Salvar relatorio Pokemon',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: Uint8List.fromList(utf8.encode(csv)),
  );
}
