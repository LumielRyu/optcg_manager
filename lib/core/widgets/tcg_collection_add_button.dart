import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tcg_collection_item.dart';
import '../../data/repositories/tcg_collection_repository.dart';
import '../utils/auth_action_guard.dart';

class TcgCollectionAddButton extends ConsumerStatefulWidget {
  final TcgCollectionDraft draft;
  final String gameLabel;
  final String collectionRoute;
  final bool compact;

  const TcgCollectionAddButton({
    super.key,
    required this.draft,
    required this.gameLabel,
    required this.collectionRoute,
    this.compact = false,
  });

  @override
  ConsumerState<TcgCollectionAddButton> createState() =>
      _TcgCollectionAddButtonState();
}

class _TcgCollectionAddButtonState
    extends ConsumerState<TcgCollectionAddButton> {
  bool _saving = false;

  Future<void> _add() async {
    if (_saving || !requireSignedIn(context)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tcgCollectionRepositoryProvider)
          .addOrIncrement(widget.draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.draft.name} adicionada à coleção ${widget.gameLabel}.',
          ),
          action: SnackBarAction(
            label: 'Ver coleção',
            onPressed: () => context.go(widget.collectionRoute),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível adicionar a carta: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: 'Adicionar à coleção',
        visualDensity: VisualDensity.compact,
        onPressed: _saving ? null : _add,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_circle_outline),
      );
    }

    return FilledButton.icon(
      onPressed: _saving ? null : _add,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_circle_outline),
      label: Text(_saving ? 'Adicionando...' : 'Adicionar à minha coleção'),
    );
  }
}
