import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/tcg_collection_item.dart';
import '../../data/repositories/tcg_wanted_repository.dart';
import '../utils/auth_action_guard.dart';

class TcgWantedAddButton extends ConsumerStatefulWidget {
  final TcgCollectionDraft draft;
  final String gameLabel;
  final String wantedRoute;
  final bool compact;

  const TcgWantedAddButton({
    super.key,
    required this.draft,
    required this.gameLabel,
    required this.wantedRoute,
    this.compact = false,
  });

  @override
  ConsumerState<TcgWantedAddButton> createState() => _TcgWantedAddButtonState();
}

class _TcgWantedAddButtonState extends ConsumerState<TcgWantedAddButton> {
  bool _saving = false;

  Future<void> _add() async {
    if (_saving || !requireSignedIn(context)) return;
    setState(() => _saving = true);
    try {
      await ref.read(tcgWantedRepositoryProvider).addOrIncrement(widget.draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.draft.name} adicionada às procuradas ${widget.gameLabel}.',
          ),
          action: SnackBarAction(
            label: 'Ver procuradas',
            onPressed: () => context.go(widget.wantedRoute),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        tooltip: 'Adicionar às procuradas',
        visualDensity: VisualDensity.compact,
        onPressed: _saving ? null : _add,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.favorite_border),
      );
    }
    return OutlinedButton.icon(
      onPressed: _saving ? null : _add,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.favorite_border),
      label: Text(_saving ? 'Adicionando...' : 'Adicionar às procuradas'),
    );
  }
}
