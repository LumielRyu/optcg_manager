import 'package:flutter/material.dart';

class CatalogSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }
}
