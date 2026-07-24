import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<void> saveOnePieceReportCsv({
  required String fileName,
  required String csv,
}) async {
  final directory = await FilePicker.getDirectoryPath(
    dialogTitle: 'Escolha onde salvar o relatorio',
  );
  if (directory == null) return;
  await File(
    '$directory${Platform.pathSeparator}$fileName',
  ).writeAsString(csv, flush: true);
}
