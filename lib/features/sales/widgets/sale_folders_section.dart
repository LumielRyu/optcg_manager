import 'package:flutter/material.dart';

import '../../../data/models/sale_folder.dart';

const saleAllFolders = '__all_sale_folders__';
const saleUnfiledFolder = '__unfiled_sale_folder__';

class SaleFolderMetrics {
  final int uniqueListings;
  final int totalCards;
  final int totalValueInCents;

  const SaleFolderMetrics({
    required this.uniqueListings,
    required this.totalCards,
    required this.totalValueInCents,
  });

  static const empty = SaleFolderMetrics(
    uniqueListings: 0,
    totalCards: 0,
    totalValueInCents: 0,
  );
}

class SaleFoldersSection extends StatelessWidget {
  final List<SaleFolder> folders;
  final String selectedFolderId;
  final bool loading;
  final SaleFolderMetrics allMetrics;
  final SaleFolderMetrics unfiledMetrics;
  final Map<String, SaleFolderMetrics> folderMetrics;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<SaleFolder> onRename;
  final ValueChanged<SaleFolder> onDelete;

  const SaleFoldersSection({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.loading,
    required this.allMetrics,
    required this.unfiledMetrics,
    required this.folderMetrics,
    required this.onSelect,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_copy_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastas de vendas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (compact)
                    IconButton.filledTonal(
                      tooltip: 'Nova pasta',
                      onPressed: loading ? null : onCreate,
                      icon: const Icon(Icons.create_new_folder_outlined),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: loading ? null : onCreate,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Nova pasta'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Organize seu estoque sem alterar o que aparece no marketplace.',
              ),
              const SizedBox(height: 12),
              if (loading)
                const LinearProgressIndicator()
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FolderCard(
                        name: 'Todas as cartas',
                        icon: Icons.inventory_2_outlined,
                        metrics: allMetrics,
                        selected: selectedFolderId == saleAllFolders,
                        compact: compact,
                        onTap: () => onSelect(saleAllFolders),
                      ),
                      _FolderCard(
                        name: 'Sem pasta',
                        icon: Icons.folder_off_outlined,
                        metrics: unfiledMetrics,
                        selected: selectedFolderId == saleUnfiledFolder,
                        compact: compact,
                        onTap: () => onSelect(saleUnfiledFolder),
                      ),
                      for (final folder in folders)
                        _FolderCard(
                          name: folder.name,
                          icon: Icons.folder_outlined,
                          metrics:
                              folderMetrics[folder.id] ??
                              SaleFolderMetrics.empty,
                          selected: selectedFolderId == folder.id,
                          compact: compact,
                          onTap: () => onSelect(folder.id),
                          onRename: () => onRename(folder),
                          onDelete: () => onDelete(folder),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final SaleFolderMetrics metrics;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _FolderCard({
    required this.name,
    required this.icon,
    required this.metrics,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: compact ? 178 : 205,
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.14)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? color : null),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${metrics.uniqueListings} anuncios • ${metrics.totalCards} cartas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatCents(metrics.totalValueInCents),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRename != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Opcoes da pasta',
                  onSelected: (value) {
                    if (value == 'rename') onRename?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renomear')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCents(int cents) {
    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return 'Valor anunciado: R\$ $value';
  }
}
