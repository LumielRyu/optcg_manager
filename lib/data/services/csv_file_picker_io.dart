import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedCsvFile {
  final String name;
  final Uint8List bytes;

  const PickedCsvFile({required this.name, required this.bytes});
}

Future<PickedCsvFile?> pickCsvFile() async {
  final picked = await FilePicker.pickFiles(
    dialogTitle: 'Selecione a classificacao do torneio One Piece',
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    withData: true,
  );
  if (picked == null || picked.files.isEmpty) return null;
  final file = picked.files.single;
  return PickedCsvFile(name: file.name, bytes: file.bytes ?? Uint8List(0));
}
