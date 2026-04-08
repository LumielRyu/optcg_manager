import 'package:flutter/material.dart';

class StoreShareActions extends StatelessWidget {
  final bool isBusy;
  final bool isCompact;
  final VoidCallback onCopyLink;
  final VoidCallback onDisableLink;

  const StoreShareActions({
    super.key,
    required this.isBusy,
    required this.isCompact,
    required this.onCopyLink,
    required this.onDisableLink,
  });

  @override
  Widget build(BuildContext context) {
    final copyButton = FilledButton.icon(
      onPressed: isBusy ? null : onCopyLink,
      icon: isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.copy_outlined),
      label: const Text('Copiar link'),
    );

    final disableButton = FilledButton.tonalIcon(
      onPressed: isBusy ? null : onDisableLink,
      icon: const Icon(Icons.link_off),
      label: const Text('Desativar'),
    );

    if (isCompact) {
      return Row(
        children: [
          Expanded(child: copyButton),
          const SizedBox(width: 8),
          Expanded(child: disableButton),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [copyButton, const SizedBox(width: 8), disableButton],
    );
  }
}
