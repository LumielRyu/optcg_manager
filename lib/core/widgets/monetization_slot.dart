import 'package:flutter/material.dart';

/// Ponto estável para publicidade ou patrocínio futuro.
///
/// Sem um conteúdo aprovado, não ocupa espaço e não carrega rastreadores.
class MonetizationSlot extends StatelessWidget {
  final String placement;
  final Widget? approvedContent;

  const MonetizationSlot({
    super.key,
    required this.placement,
    this.approvedContent,
  });

  @override
  Widget build(BuildContext context) {
    final content = approvedContent;
    if (content == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Conteúdo patrocinado',
      child: KeyedSubtree(key: ValueKey(placement), child: content),
    );
  }
}
