import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;
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
        const SnackBar(content: Text('Nao foi possivel inicializar a camera.')),
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
        const SnackBar(content: Text('Nao foi possivel capturar a foto.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _captureUsingBrowserCamera() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
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
          content: Text('Nao foi possivel abrir a camera do navegador.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
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
      appBar: AppBar(title: const Text('Importar com camera')),
      body: Column(
        children: [
          Expanded(child: _buildBodyPreview()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasStartedCameraFlow && _isWebMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        canContinue
                            ? 'Foto capturada. A analise sera aberta em seguida.'
                            : 'No navegador, a captura usa a camera do proprio navegador.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isCapturing || _isInitializingCamera
                              ? null
                              : _capturePhoto,
                          icon: (_isCapturing || _isInitializingCamera)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _hasStartedCameraFlow
                                ? (_isWebMode
                                      ? 'Abrir camera'
                                      : 'Capturar foto')
                                : 'Usar camera',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canContinue && !_isOpeningImport
                              ? _openImageImport
                              : null,
                          icon: _isOpeningImport
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: const Text('Continuar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyPreview() {
    if (!_hasStartedCameraFlow) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'A camera so sera solicitada quando voce clicar em \"Usar camera\".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (_isInitializingCamera) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isCameraReady) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Camera indisponivel neste dispositivo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isWebMode) {
      if (_webCapturedBytes == null) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Clique em \"Abrir camera\" para tirar uma foto no navegador.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
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

    return CameraPreview(controller);
  }
}
