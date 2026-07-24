import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> savePokemonReportCsv({
  required String fileName,
  required String csv,
}) async {
  final blob = web.Blob(
    [csv.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.children.add(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
