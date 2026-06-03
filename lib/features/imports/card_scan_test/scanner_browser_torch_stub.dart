class BrowserTorchResult {
  final bool supported;
  final String? message;

  const BrowserTorchResult({required this.supported, this.message});
}

Future<BrowserTorchResult> setBrowserTorch(bool enabled) async {
  return const BrowserTorchResult(
    supported: false,
    message: 'Controle direto de flash disponivel apenas no navegador.',
  );
}
