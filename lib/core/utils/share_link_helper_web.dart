import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

Future<String> shareOrCopyText(
  String text, {
  String? subject,
}) async {
  final navigatorObject = web.window.navigator as JSObject;

  try {
    final share = navigatorObject.getProperty('share'.toJS);
    if (share != null) {
      final sharePayload = <String, String>{
        'title': subject ?? 'Compartilhar link',
        'text': subject ?? 'Compartilhar link',
        'url': text,
      }.jsify() as JSObject;
      final promise = navigatorObject.callMethod(
        'share'.toJS,
        sharePayload,
      ) as JSPromise<JSAny?>;
      await promise.toDart;
      return 'shared';
    }
  } catch (_) {}

  try {
    final clipboard = navigatorObject.getProperty('clipboard'.toJS);
    if (clipboard != null) {
      final promise = (clipboard as JSObject).callMethod(
        'writeText'.toJS,
        text.toJS,
      ) as JSPromise<JSAny?>;
      await promise.toDart;
      return 'copied';
    }
  } catch (_) {}

  try {
    await Clipboard.setData(ClipboardData(text: text));
    return 'copied';
  } catch (_) {}

  final textArea = web.HTMLTextAreaElement()
    ..value = text
    ..style.position = 'fixed'
    ..style.opacity = '0'
    ..style.left = '-9999px'
    ..style.top = '0';

  web.document.body?.append(textArea);
  textArea.focus();
  textArea.select();

  final copied = web.document.execCommand('copy');
  textArea.remove();

  if (copied == true) {
    return 'copied';
  }

  throw Exception(
    'N\u00E3o foi poss\u00EDvel copiar ou compartilhar o link neste navegador.',
  );
}
