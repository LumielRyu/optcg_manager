import 'package:flutter/material.dart';

class CatalogDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;
  final bool allowEmpty;
  final String emptyLabel;
  final double? width;

  const CatalogDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelBuilder,
    this.allowEmpty = false,
    this.emptyLabel = 'Todos',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowEmpty)
          DropdownMenuItem<T?>(value: null, child: Text(emptyLabel)),
        ...options.map((option) {
          final text = labelBuilder?.call(option) ?? option.toString();
          return DropdownMenuItem<T?>(
            value: option,
            child: Text(text, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: onChanged,
    );

    if (width == null) return field;
    return SizedBox(width: width, child: field);
  }
}
