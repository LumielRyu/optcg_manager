import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class BrowserTorchResult {
  final bool supported;
  final String? message;

  const BrowserTorchResult({required this.supported, this.message});
}

Future<BrowserTorchResult> setBrowserTorch(bool enabled) async {
  final videos = web.document.querySelectorAll('video');

  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node == null) continue;

    final video = node as web.HTMLVideoElement;
    final provider = video.srcObject;
    if (provider == null) continue;

    final stream = provider as web.MediaStream;
    final tracks = stream.getVideoTracks().toDart;

    for (final track in tracks) {
      if (track.readyState != 'live') continue;

      try {
        final capabilities = track.getCapabilities();
        final hasTorchProperty = capabilities.hasProperty('torch'.toJS).toDart;
        final torchValues = hasTorchProperty
            ? capabilities.torch.toDart.map((item) => item.toDart).toList()
            : const <bool>[];
        final canTorch = torchValues.contains(true);

        // Some iOS versions under-report support. Try once even when the
        // capability check is inconclusive, and let applyConstraints decide.
        if (!canTorch && hasTorchProperty && enabled) {
          continue;
        }

        await track
            .applyConstraints(web.MediaTrackConstraints(torch: enabled.toJS))
            .toDart;

        return const BrowserTorchResult(supported: true);
      } catch (error) {
        // Keep searching; Flutter may have more than one video element alive
        // while switching cameras or rebuilding the preview.
        continue;
      }
    }
  }

  return const BrowserTorchResult(
    supported: false,
    message:
        'O navegador nao liberou o controle da lanterna para este stream de camera.',
  );
}
