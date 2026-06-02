import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/home_navigation_button.dart';
import '../../../core/widgets/primary_bottom_navigation.dart';
import '../image_import/image_import_controller.dart';

class CardScanTestScreen extends ConsumerStatefulWidget {
  const CardScanTestScreen({super.key});

  @override
  ConsumerState<CardScanTestScreen> createState() => _CardScanTestScreenState();
}

class _CardScanTestScreenState extends ConsumerState<CardScanTestScreen> {
  static const _sampleImagePath = 'assets/test_samples/boa_hancock_p115.jpeg';

  final ImagePicker _picker = ImagePicker();
  final List<_ScanHistoryItem> _history = [];

  CameraController? _cameraController;
  Timer? _continuousTimer;
  Uint8List? _imageBytes;
  String? _imagePath;
  String? _cameraError;

  bool _cameraReady = false;
  bool _initializingCamera = false;
  bool _scanInProgress = false;
  bool _continuousScan = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeCamera);
  }

  @override
  void dispose() {
    _continuousTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_initializingCamera || _cameraReady) return;

    setState(() {
      _initializingCamera = true;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Nenhuma camera encontrada neste dispositivo.');
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _initializingCamera = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _initializingCamera = false;
        _cameraError = 'Nao foi possivel inicializar a camera: $e';
      });
    }
  }

  Future<void> _scanFromLiveCamera({bool visualOnly = false}) async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _scanInProgress) {
      return;
    }

    setState(() {
      _scanInProgress = true;
    });

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final analysisBytes = _cropToGuide(bytes) ?? bytes;
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imagePath = kIsWeb ? null : file.path;
      });

      await _analyzeLiveCapture(
        path: file.path,
        bytes: analysisBytes,
        visualOnly: visualOnly,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nao foi possivel escanear: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _scanInProgress = false;
        });
      }
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 92);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final analysisBytes = _cropToGuide(bytes) ?? bytes;
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imagePath = kIsWeb ? null : file.path;
    });

    if (kIsWeb) {
      await ref
          .read(imageImportControllerProvider.notifier)
          .analyzeImageBytes(analysisBytes, preferVisual: true);
      _rememberCurrentResult();
    } else {
      await _analyzeBytes(path: file.path, bytes: analysisBytes);
    }
  }

  Future<void> _analyzeBundledSample() async {
    final data = await rootBundle.load(_sampleImagePath);
    final bytes = data.buffer.asUint8List();
    final analysisBytes = _cropToGuide(bytes) ?? bytes;
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imagePath = null;
    });

    await ref
        .read(imageImportControllerProvider.notifier)
        .analyzeImageBytes(analysisBytes, preferVisual: true);
    _rememberCurrentResult();
  }

  Uint8List? _cropToGuide(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final source = img.bakeOrientation(decoded);
    final isPortrait = source.height >= source.width;
    final cropWidth = (source.width * (isPortrait ? 0.72 : 0.48)).round();
    final cropHeight = (cropWidth / 0.72).round();
    final safeHeight = cropHeight.clamp(1, source.height);
    final safeWidth = cropWidth.clamp(1, source.width);
    final x = ((source.width - safeWidth) / 2).round().clamp(
      0,
      source.width - 1,
    );
    final y = ((source.height - safeHeight) / 2).round().clamp(
      0,
      source.height - 1,
    );

    final cropped = img.copyCrop(
      source,
      x: x,
      y: y,
      width: safeWidth,
      height: safeHeight,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  Future<void> _analyzeBytes({
    required String path,
    required Uint8List bytes,
    bool visualOnly = false,
  }) async {
    await ref
        .read(imageImportControllerProvider.notifier)
        .analyzeImageFile(
          path: path,
          sourceBytes: bytes,
          preferVisual: true,
          skipOcrFallback: visualOnly,
        );
    _rememberCurrentResult();
  }

  Future<void> _analyzeLiveCapture({
    required String path,
    required Uint8List bytes,
    bool visualOnly = false,
  }) async {
    if (kIsWeb) {
      await ref
          .read(imageImportControllerProvider.notifier)
          .analyzeImageBytes(
            bytes,
            preferVisual: true,
            skipOcrFallback: visualOnly,
          );
      _rememberCurrentResult();
      return;
    }

    await _analyzeBytes(path: path, bytes: bytes, visualOnly: visualOnly);
  }

  void _toggleContinuousScan() {
    if (_continuousScan) {
      _continuousTimer?.cancel();
      setState(() {
        _continuousScan = false;
      });
      return;
    }

    setState(() {
      _continuousScan = true;
    });
    _scanFromLiveCamera(visualOnly: true);
    _continuousTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted || !_continuousScan) return;
      _scanFromLiveCamera(visualOnly: true);
    });
  }

  void _rememberCurrentResult() {
    final state = ref.read(imageImportControllerProvider);
    final found = state.candidates.where((item) => item.found).toList();
    if (found.isEmpty) return;

    setState(() {
      for (final candidate in found) {
        final existingIndex = _history.indexWhere(
          (item) => item.code == candidate.code,
        );
        final item = _ScanHistoryItem(
          code: candidate.code,
          name: candidate.name ?? candidate.code,
          imageUrl: candidate.imageUrl,
          matchedBy: candidate.matchedBy,
          scannedAt: DateTime.now(),
        );

        if (existingIndex >= 0) {
          _history[existingIndex] = item.copyWith(
            count: _history[existingIndex].count + 1,
          );
        } else {
          _history.insert(0, item);
        }
      }
    });
  }

  void _openImportFlow() {
    final extra = kIsWeb ? _imageBytes : _imagePath;
    if (extra == null) return;
    context.push('/image-import', extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageImportControllerProvider);
    final theme = Theme.of(context);
    final isBusy = state.isBusy || _scanInProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconhecimento por imagem'),
        actions: const [HomeNavigationButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusPanel(
                  icon: Icons.image_search_outlined,
                  title: 'Laboratorio de reconhecimento',
                  text:
                      'Use uma foto da carta inteira para comparar a imagem com o catalogo visual armazenado no Supabase. Teste com a amostra pronta ou envie uma imagem da galeria.',
                ),
                const SizedBox(height: 12),
                Container(
                  height: MediaQuery.of(context).size.width < 640 ? 360 : 500,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildCameraArea(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: !_cameraReady || isBusy
                          ? null
                          : _scanFromLiveCamera,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.center_focus_strong_outlined),
                      label: const Text('Escanear agora'),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_cameraReady ? null : _toggleContinuousScan,
                      icon: Icon(
                        _continuousScan
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(
                        _continuousScan ? 'Pausar continuo' : 'Auto scan',
                      ),
                    ),
                    if (!_cameraReady)
                      OutlinedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _pickAndAnalyze(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera do sistema'),
                      ),
                    OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _pickAndAnalyze(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Testar imagem'),
                    ),
                    OutlinedButton.icon(
                      onPressed: isBusy ? null : _analyzeBundledSample,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Testar foto de exemplo'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          isBusy ||
                              _imageBytes == null ||
                              state.candidates.isEmpty
                          ? null
                          : _openImportFlow,
                      icon: const Icon(Icons.playlist_add_outlined),
                      label: const Text('Abrir importacao'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.error?.trim().isNotEmpty ?? false)
                  _StatusPanel(
                    icon: Icons.warning_amber_outlined,
                    title: 'Falha no reconhecimento',
                    text: state.error!,
                  )
                else
                  _StatusPanel(
                    icon: _continuousScan
                        ? Icons.sensors_outlined
                        : Icons.psychology_outlined,
                    title: _continuousScan
                        ? 'Camera em varredura'
                        : 'Pipeline local',
                    text:
                        'A tela testa OCR local, busca por codigo e matching visual somente quando necessario.',
                  ),
                const SizedBox(height: 12),
                _ResultPanel(state: state),
                const SizedBox(height: 12),
                _HistoryPanel(history: _history),
                const SizedBox(height: 12),
                _DebugPanel(state: state),
                const SizedBox(height: 8),
                Text(
                  'Dica: mantenha a carta inteira no quadro por um instante. O OCR por codigo e mais rapido; o matching visual entra como fallback.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentRoute: '/card-scan-test',
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_initializingCamera) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_cameraError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _cameraError!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _initializeCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (kIsWeb && _imageBytes != null && !_cameraReady) {
      return _ImagePreview(bytes: _imageBytes!);
    }

    final controller = _cameraController;
    if (!_cameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: FilledButton.icon(
          onPressed: _initializeCamera,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Ligar camera'),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        IgnorePointer(
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        if (_continuousScan)
          const Positioned(left: 12, top: 12, child: _LiveBadge()),
        if (_imageBytes != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 84,
                height: 116,
                child: _ImagePreview(bytes: _imageBytes!),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'AUTO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanHistoryItem {
  final String code;
  final String name;
  final String? imageUrl;
  final String? matchedBy;
  final DateTime scannedAt;
  final int count;

  const _ScanHistoryItem({
    required this.code,
    required this.name,
    required this.scannedAt,
    this.imageUrl,
    this.matchedBy,
    this.count = 1,
  });

  _ScanHistoryItem copyWith({int? count}) {
    return _ScanHistoryItem(
      code: code,
      name: name,
      imageUrl: imageUrl,
      matchedBy: matchedBy,
      scannedAt: DateTime.now(),
      count: count ?? this.count,
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List bytes;

  const _ImagePreview({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final ImageImportState state;

  const _ResultPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.candidates.isEmpty) {
      return _Section(
        title: 'Resultado atual',
        child: Text(
          'Nenhuma carta analisada ainda.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return _Section(
      title: 'Resultado atual',
      child: Column(
        children: state.candidates.map((candidate) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 56,
              height: 56,
              child: _CardThumb(imageUrl: candidate.imageUrl),
            ),
            title: Text(
              candidate.name?.trim().isNotEmpty ?? false
                  ? candidate.name!.trim()
                  : candidate.code,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                candidate.code,
                if (candidate.matchedBy?.isNotEmpty ?? false)
                  'via ${candidate.matchedBy}',
                if (candidate.rarity?.isNotEmpty ?? false) candidate.rarity,
              ].join(' - '),
            ),
            trailing: candidate.found
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : const Icon(Icons.help_outline),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final List<_ScanHistoryItem> history;

  const _HistoryPanel({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Section(
      title: 'Cartas escaneadas',
      child: Column(
        children: history.map((item) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: _CardThumb(imageUrl: item.imageUrl),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item.code}${item.matchedBy == null ? '' : ' - via ${item.matchedBy}'}',
            ),
            trailing: item.count > 1 ? Text('${item.count}x') : null,
          );
        }).toList(),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final ImageImportState state;

  const _DebugPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final hasDebug =
        (state.debugMessage?.trim().isNotEmpty ?? false) ||
        (state.detectedInput?.trim().isNotEmpty ?? false) ||
        (state.rawOcrText?.trim().isNotEmpty ?? false) ||
        state.extractedLines.isNotEmpty ||
        state.candidateNames.isNotEmpty;

    if (!hasDebug) return const SizedBox.shrink();

    return _Section(
      title: 'Debug',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.debugMessage?.trim().isNotEmpty ?? false)
            Text('Status: ${state.debugMessage!}'),
          if (state.extractedLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText('Codigos: ${state.extractedLines.join(', ')}'),
          ],
          if (state.candidateNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText('Nomes: ${state.candidateNames.join(', ')}'),
          ],
          if (state.detectedInput?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text('Entrada normalizada:'),
            SelectableText(state.detectedInput!),
          ],
          if (state.rawOcrText?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            const Text('OCR bruto:'),
            SelectableText(state.rawOcrText!),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CardThumb extends StatelessWidget {
  final String? imageUrl;

  const _CardThumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return const Icon(Icons.image_not_supported_outlined);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) {
          return const Icon(Icons.broken_image_outlined);
        },
      ),
    );
  }
}
