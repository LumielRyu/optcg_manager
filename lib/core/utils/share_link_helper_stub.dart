import 'package:flutter/services.dart';

Future<String> shareOrCopyText(
  String text, {
  String? subject,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  return 'copied';
}
