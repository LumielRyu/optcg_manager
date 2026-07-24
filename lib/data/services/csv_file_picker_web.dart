import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PickedCsvFile {
  final String name;
  final Uint8List bytes;

  const PickedCsvFile({required this.name, required this.bytes});
}

Future<PickedCsvFile?> pickCsvFile() {
  final completer = Completer<PickedCsvFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv'
    ..multiple = false
    ..style.display = 'none';

  late final StreamSubscription<web.Event> changeSubscription;
  StreamSubscription<web.Event>? loadSubscription;
  void complete(PickedCsvFile? result) {
    if (!completer.isCompleted) completer.complete(result);
  }

  changeSubscription = input.onChange.listen((_) {
    final file = input.files?.item(0);
    if (file == null) return complete(null);
    final reader = web.FileReader();
    loadSubscription = reader.onLoadEnd.listen((_) {
      final result = reader.result;
      final bytes = result != null && result.isA<JSArrayBuffer>()
          ? (result as JSArrayBuffer).toDart.asUint8List()
          : Uint8List(0);
      complete(PickedCsvFile(name: file.name, bytes: bytes));
    });
    reader.readAsArrayBuffer(file);
  });

  final cancelListener = ((web.Event _) => complete(null)).toJS;
  input.addEventListener('cancel', cancelListener);
  web.document.body!.children.add(input);
  input.click();

  return completer.future.whenComplete(() async {
    await changeSubscription.cancel();
    await loadSubscription?.cancel();
    input.removeEventListener('cancel', cancelListener);
    input.remove();
  });
}
