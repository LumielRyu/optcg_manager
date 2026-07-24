import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/admin_access.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/liga_price_admin_service.dart';

class LigaPriceAdminScreen extends ConsumerStatefulWidget {
  const LigaPriceAdminScreen({super.key});

  @override
  ConsumerState<LigaPriceAdminScreen> createState() =>
      _LigaPriceAdminScreenState();
}

class _LigaPriceAdminScreenState extends ConsumerState<LigaPriceAdminScreen> {
  late Future<List<LigaEditionPriceStatus>> _statuses;
  final _searchController = TextEditingController();
  LigaEditionUpdateState? _filter;

  @override
  void initState() {
    super.initState();
    _statuses = _load();
  }

  Future<List<LigaEditionPriceStatus>> _load() {
    return ref.read(ligaPriceAdminServiceProvider).loadEditionStatuses();
  }

  void _refresh() {
    setState(() => _statuses = _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final user = ref.watch(currentUserProvider);
    if (!isApplicationAdmin(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administracao')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Acesso restrito',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta pagina esta disponivel apenas para administradores.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go('/home/one-piece'),
                    child: const Text('Voltar ao inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Precos da Liga'),
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => context.go('/home/one-piece'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<LigaEditionPriceStatus>>(
        future: _statuses,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error, onRetry: _refresh);
          }
          return _Dashboard(
            statuses: snapshot.data ?? const [],
            searchController: _searchController,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onSearchChanged: (_) => setState(() {}),
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final List<LigaEditionPriceStatus> statuses;
  final TextEditingController searchController;
  final LigaEditionUpdateState? filter;
  final ValueChanged<LigaEditionUpdateState?> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  const _Dashboard({
    required this.statuses,
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final updated = statuses.where((item) => item.latestUpdate != null).length;
    final current = statuses
        .where((item) => item.stateAt(now) == LigaEditionUpdateState.current)
        .length;
    final attention = statuses.length - current;
    final search = searchController.text.trim().toUpperCase();
    final visible = statuses
        .where((item) {
          final matchesText = search.isEmpty || item.acronym.contains(search);
          final matchesFilter = filter == null || item.stateAt(now) == filter;
          return matchesText && matchesFilter;
        })
        .toList(growable: false);

    return AppPageShell(
      maxWidth: 1280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeroPanel(
            eyebrow: 'ADMINISTRACAO',
            title: 'Monitor de precos da Liga',
            subtitle:
                'Acompanhe quais edicoes ja foram processadas, a cobertura de precos e o horario da ultima atualizacao salva no Supabase.',
            icon: Icons.monitor_heart_outlined,
            badges: [
              AppBadge(
                label: '${statuses.length} edicoes cadastradas',
                icon: Icons.inventory_2_outlined,
              ),
              AppBadge(
                label: '$updated ja processadas',
                icon: Icons.cloud_done_outlined,
              ),
            ],
            action: FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Recarregar'),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryCard(
                label: 'Todas as edicoes',
                value: statuses.length,
                icon: Icons.inventory_2_outlined,
              ),
              _SummaryCard(
                label: 'Ja processadas',
                value: updated,
                icon: Icons.cloud_done_outlined,
                color: Colors.blue,
              ),
              _SummaryCard(
                label: 'Atualizadas',
                value: current,
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              _SummaryCard(
                label: 'Pedem atencao',
                value: attention,
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Buscar edicao',
              hintText: 'Ex.: OP-16',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: filter == null,
                  onSelected: () => onFilterChanged(null),
                ),
                _FilterChip(
                  label: 'Atualizadas',
                  selected: filter == LigaEditionUpdateState.current,
                  onSelected: () =>
                      onFilterChanged(LigaEditionUpdateState.current),
                ),
                _FilterChip(
                  label: 'Parciais',
                  selected: filter == LigaEditionUpdateState.partial,
                  onSelected: () =>
                      onFilterChanged(LigaEditionUpdateState.partial),
                ),
                _FilterChip(
                  label: 'Atrasadas',
                  selected: filter == LigaEditionUpdateState.stale,
                  onSelected: () =>
                      onFilterChanged(LigaEditionUpdateState.stale),
                ),
                _FilterChip(
                  label: 'Nunca atualizadas',
                  selected: filter == LigaEditionUpdateState.neverUpdated,
                  onSelected: () =>
                      onFilterChanged(LigaEditionUpdateState.neverUpdated),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${visible.length} edicoes encontradas',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            const _EmptyView()
          else
            ...visible.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EditionCard(status: item, now: now),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _EditionCard extends StatelessWidget {
  final LigaEditionPriceStatus status;
  final DateTime now;

  const _EditionCard({required this.status, required this.now});

  @override
  Widget build(BuildContext context) {
    final state = status.stateAt(now);
    final color = _stateColor(state);
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final latest = status.latestUpdate?.toLocal();
    final ratio = status.pricedRatio.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final details = Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _Detail(
                icon: Icons.style_outlined,
                text: '${status.cardCount} cartas verificadas',
              ),
              _Detail(
                icon: Icons.sell_outlined,
                text: '${status.pricedCardCount} com menor preco',
              ),
              _Detail(
                icon: Icons.schedule,
                text: latest == null
                    ? 'Sem atualizacao'
                    : formatter.format(latest),
              ),
              _Detail(
                icon: Icons.layers_outlined,
                text: status.group == 'aux' ? 'Edicao auxiliar' : 'Edicao',
              ),
            ],
          );
          final heading = Row(
            children: [
              Expanded(
                child: Text(
                  status.acronym,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusBadge(state: state, color: color),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              SizedBox(height: compact ? 12 : 8),
              details,
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Detail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(text)],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LigaEditionUpdateState state;
  final Color color;

  const _StatusBadge({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stateLabel(state),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('Nenhuma edicao corresponde aos filtros.')),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Nao foi possivel carregar o monitor de precos.'),
            const SizedBox(height: 6),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(LigaEditionUpdateState state) {
  return switch (state) {
    LigaEditionUpdateState.current => 'Atualizada',
    LigaEditionUpdateState.partial => 'Parcial',
    LigaEditionUpdateState.stale => 'Atrasada',
    LigaEditionUpdateState.neverUpdated => 'Nunca atualizada',
  };
}

Color _stateColor(LigaEditionUpdateState state) {
  return switch (state) {
    LigaEditionUpdateState.current => Colors.green,
    LigaEditionUpdateState.partial => Colors.amber.shade800,
    LigaEditionUpdateState.stale => Colors.deepOrange,
    LigaEditionUpdateState.neverUpdated => Colors.blueGrey,
  };
}
