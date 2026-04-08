import 'package:flutter/material.dart';

import '../../../core/constants/collection_types.dart';
import '../../../core/enums/collection_sort_option.dart';

class CollectionFiltersBar extends StatelessWidget {
  final String selectedLibrary;
  final TextEditingController searchController;
  final bool favoritesOnly;
  final CollectionSortOption sortOption;
  final String? selectedDeckFilter;
  final List<String> availableDeckNames;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final ValueChanged<CollectionSortOption?> onSortChanged;
  final ValueChanged<String?> onDeckFilterChanged;

  const CollectionFiltersBar({
    super.key,
    required this.selectedLibrary,
    required this.searchController,
    required this.favoritesOnly,
    required this.sortOption,
    required this.selectedDeckFilter,
    required this.availableDeckNames,
    required this.onFavoritesOnlyChanged,
    required this.onSortChanged,
    required this.onDeckFilterChanged,
  });

  String _sortLabel(CollectionSortOption option) {
    switch (option) {
      case CollectionSortOption.nameAsc:
        return 'Nome A-Z';
      case CollectionSortOption.nameDesc:
        return 'Nome Z-A';
      case CollectionSortOption.codeAsc:
        return 'Código A-Z';
      case CollectionSortOption.codeDesc:
        return 'Código Z-A';
      case CollectionSortOption.quantityDesc:
        return 'Quantidade ↓';
      case CollectionSortOption.quantityAsc:
        return 'Quantidade ↑';
      case CollectionSortOption.recentFirst:
        return 'Mais recentes';
      case CollectionSortOption.recentLast:
        return 'Mais antigas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDeckFilter = selectedLibrary == CollectionTypes.deck;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              FilterChip(
                label: const Text('Somente favoritos'),
                selected: favoritesOnly,
                onSelected: onFavoritesOnlyChanged,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<CollectionSortOption>(
                  initialValue: sortOption,
                  decoration: const InputDecoration(
                    labelText: 'Ordenação',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: CollectionSortOption.values.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(_sortLabel(option)),
                    );
                  }).toList(),
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
          if (showDeckFilter) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectedDeckFilter,
              decoration: const InputDecoration(
                labelText: 'Filtrar deck',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os decks'),
                ),
                ...availableDeckNames.map(
                  (deck) => DropdownMenuItem<String?>(
                    value: deck,
                    child: Text(deck),
                  ),
                ),
              ],
              onChanged: onDeckFilterChanged,
            ),
          ],
        ],
      ),
    );
  }
}