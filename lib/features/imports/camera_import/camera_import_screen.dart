import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/home_navigation_button.dart';

class CameraImportScreen extends StatefulWidget {
  final String initialDestination;

  const CameraImportScreen({super.key, this.initialDestination = 'owned'});

  @override
  State<CameraImportScreen> createState() => _CameraImportScreenState();
}

class _CameraImportScreenState extends State<CameraImportScreen> {
  CameraController? _cameraController;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _isWebMode = false;
  bool _hasStartedCameraFlow = false;
  bool _isInitializingCamera = false;
  bool _isOpeningImport = false;

  String? _capturedImagePath;
  Uint8List? _webCapturedBytes;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _ensureCameraInitialized() async {
    if (_hasStartedCameraFlow && (_isWebMode || _cameraController != null)) {
      return;
    }
    if (_isInitializingCamera) return;

    setState(() {
      _hasStartedCameraFlow = true;
      _isInitializingCamera = true;
    });

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isWebMode = true;
        _isCameraReady = true;
        _isInitializingCamera = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isWebMode = false;
          _isCameraReady = false;
          _isInitializingCamera = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
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
        _isWebMode = false;
        _isCameraReady = true;
        _isInitializingCamera = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isWebMode = false;
        _isCameraReady = false;
        _isInitializingCamera = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível inicializar a câmera.')),
      );
    }
  }

  Future<void> _capturePhoto() async {
    await _ensureCameraInitialized();
    if (!_isCameraReady) return;

    if (_isWebMode) {
      await _captureUsingBrowserCamera();
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedImagePath = file.path;
      });

      await _openImageImport();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível capturar a foto.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _captureUsingBrowserCamera() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (file == null) {
        if (!mounted) return;
        setState(() {
          _isCapturing = false;
        });
        return;
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _webCapturedBytes = bytes;
          _capturedImagePath = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _capturedImagePath = file.path;
          _webCapturedBytes = null;
        });
      }

      await _openImageImport();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a câmera do navegador.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _openImageImport() async {
    if (_isOpeningImport) return;

    final extra = _isWebMode ? _webCapturedBytes : _capturedImagePath;
    if (extra == null) return;

    _isOpeningImport = true;
    context.push(
      '/image-import?destination=${widget.initialDestination}',
      extra: extra,
    );
    _isOpeningImport = false;
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _isWebMode
        ? _webCapturedBytes != null
        : (_capturedImagePath != null && _capturedImagePath!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear com câmera'),
        actions: const [HomeNavigationButton()],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBodyPreview()),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _CameraActionPanel(
                isWebMode: _isWebMode,
                hasStarted: _hasStartedCameraFlow,
                canContinue: canContinue,
                isBusy:
                    _isCapturing || _isInitializingCamera || _isOpeningImport,
                onCapture: _capturePhoto,
                onContinue: _openImageImport,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyPreview() {
    if (!_hasStartedCameraFlow) {
      return _PreviewMessage(
        text: 'A câmera só será solicitada quando você tocar em "Usar câmera".',
        icon: Icons.photo_camera_outlined,
      );
    }

    if (_isInitializingCamera) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isCameraReady) {
      return const _PreviewMessage(
        text: 'Câmera indisponível neste dispositivo.',
        icon: Icons.no_photography_outlined,
      );
    }

    if (_isWebMode) {
      if (_webCapturedBytes == null) {
        return const _PreviewMessage(
          text: 'Toque em "Abrir câmera" para tirar uma foto no navegador.',
          icon: Icons.camera_alt_outlined,
        );
      }

      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.memory(_webCapturedBytes!, fit: BoxFit.contain),
      );
    }

    if (_capturedImagePath != null && _capturedImagePath!.isNotEmpty) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.file(File(_capturedImagePath!), fit: BoxFit.contain),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(color: Colors.black, child: CameraPreview(controller));
  }
}

class _CameraActionPanel extends StatelessWidget {
  final bool isWebMode;
  final bool hasStarted;
  final bool canContinue;
  final bool isBusy;
  final VoidCallback onCapture;
  final VoidCallback onContinue;

  const _CameraActionPanel({
    required this.isWebMode,
    required this.hasStarted,
    required this.canContinue,
    required this.isBusy,
    required this.onCapture,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 10,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.center_focus_strong_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enquadre a carta inteira',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              canContinue
                  ? 'Foto capturada. Continue para revisar e adicionar à coleção.'
                  : 'Use boa luz e deixe a borda da carta visível para melhorar o reconhecimento.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onCapture,
                    icon: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      hasStarted
                          ? (isWebMode ? 'Abrir câmera' : 'Capturar')
                          : 'Usar câmera',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canContinue && !isBusy ? onContinue : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Revisar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  final String text;
  final IconData icon;

  const _PreviewMessage({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 52),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
