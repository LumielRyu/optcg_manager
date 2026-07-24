import 'package:flutter/material.dart';

class CatalogSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String semanticLabel;

  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.semanticLabel = 'Buscar no catalogo',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close),
                )
              : null,
        ),
      ),
    );
  }
}
