import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedTdfFile {
  final String name;
  final Uint8List bytes;

  const PickedTdfFile({required this.name, required this.bytes});
}

Future<PickedTdfFile?> pickTdfFile() async {
  final picked = await FilePicker.pickFiles(
    dialogTitle: 'Selecione o resultado do torneio Pokemon',
    type: FileType.any,
    withData: true,
  );
  if (picked == null || picked.files.isEmpty) return null;
  final file = picked.files.single;
  final bytes = file.bytes;
  if (bytes == null) return PickedTdfFile(name: file.name, bytes: Uint8List(0));
  return PickedTdfFile(name: file.name, bytes: bytes);
}
