import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/weekly_tournament.dart';
import '../../data/repositories/weekly_tournament_repository.dart';

class WeeklyDashboardScreen extends ConsumerStatefulWidget {
  final String gameSlug;

  const WeeklyDashboardScreen({super.key, required this.gameSlug});

  @override
  ConsumerState<WeeklyDashboardScreen> createState() =>
      _WeeklyDashboardScreenState();
}

class _WeeklyDashboardScreenState extends ConsumerState<WeeklyDashboardScreen> {
  late DateTime _month;
  late Future<WeeklyDashboardData> _future;
  bool _showAdminPanel = false;

  WeeklyTournamentRepository get _repository =>
      ref.read(weeklyTournamentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _future = _loadInitialDashboard();
  }

  void _reload() {
    _future = _repository.loadDashboard(
      gameSlug: widget.gameSlug,
      month: _month,
    );
  }

  Future<WeeklyDashboardData> _loadInitialDashboard() async {
    final currentMonthData = await _repository.loadDashboard(
      gameSlug: widget.gameSlug,
      month: _month,
    );
    if (currentMonthData.events.isNotEmpty) return currentMonthData;

    final latestMonth = await _repository.loadLatestEventMonth(
      gameSlug: widget.gameSlug,
    );
    if (!mounted || latestMonth == null || latestMonth == _month) {
      return currentMonthData;
    }

    _month = latestMonth;
    return _repository.loadDashboard(
      gameSlug: widget.gameSlug,
      month: latestMonth,
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _reload();
    });
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _repository.isAdmin;
    final title = _gameTitle(widget.gameSlug);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => context.go(_hubRoute(widget.gameSlug)),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Semanais - $title'),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _showAdminPanel = !_showAdminPanel;
                  });
                },
                icon: Icon(
                  _showAdminPanel
                      ? Icons.leaderboard_outlined
                      : Icons.admin_panel_settings_outlined,
                ),
                label: Text(
                  _showAdminPanel ? 'Voltar ao ranking' : 'Gerenciar semanais',
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<WeeklyDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              error: 'O servidor nao retornou os dados dos semanais.',
              onRetry: _refresh,
            );
          }

          if (isAdmin && _showAdminPanel) {
            return _AdminPanel(
              data: data,
              gameSlug: widget.gameSlug,
              month: _month,
              repository: _repository,
              onChanged: _refresh,
            );
          }

          return _PlayerPanel(
            data: data,
            gameSlug: widget.gameSlug,
            currentUserId: _repository.currentUserId,
            repository: _repository,
            month: _month,
            onPreviousMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onRefresh: _refresh,
          );
        },
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final WeeklyDashboardData data;
  final String gameSlug;
  final String currentUserId;
  final WeeklyTournamentRepository repository;
  final DateTime month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function() onRefresh;

  const _PlayerPanel({
    required this.data,
    required this.gameSlug,
    required this.currentUserId,
    required this.repository,
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final myRanking = data.ranking
        .where((entry) => entry.userId == currentUserId)
        .firstOrNull;
    final myParticipants = data.participants
        .where((participant) => participant.userId == currentUserId)
        .toList(growable: false);
    final eventsById = {for (final event in data.events) event.id: event};
    final joinedEventIds = myParticipants
        .map((participant) => participant.eventId)
        .toSet();
    final openEvents = data.events
        .where(
          (event) =>
              event.status == 'open' && !joinedEventIds.contains(event.id),
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WeeklyHero(
                    month: month,
                    entry: myRanking,
                    openEvents: openEvents.length,
                    participationCount: myParticipants.length,
                    onPreviousMonth: onPreviousMonth,
                    onNextMonth: onNextMonth,
                  ),
                  if (openEvents.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionHeading(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Inscricoes abertas',
                      subtitle:
                          'Escolha seu lider e confirme sua participacao nos proximos encontros.',
                    ),
                    const SizedBox(height: 12),
                    for (final event in openEvents)
                      _OpenEnrollmentCard(
                        event: event,
                        onJoin: () async {
                          final joined = await showDialog<bool>(
                            context: context,
                            builder: (_) => _JoinWeeklyDialog(
                              event: event,
                              gameSlug: gameSlug,
                              gameProfile: data.currentGameProfile,
                              leaders: data.leaders,
                              repository: repository,
                            ),
                          );
                          if (joined == true) await onRefresh();
                        },
                      ),
                  ],
                  const SizedBox(height: 28),
                  _PlayerDashboard(entry: myRanking),
                  const SizedBox(height: 28),
                  const _SectionHeading(
                    icon: Icons.event_note_outlined,
                    title: 'Meus semanais',
                    subtitle:
                        'Abra um encontro para acompanhar suas rodadas e confirmar resultados.',
                  ),
                  const SizedBox(height: 12),
                  if (myParticipants.isEmpty)
                    const _EmptyCard(
                      message:
                          'Voce ainda nao participou de semanais neste mes.',
                    )
                  else
                    for (final participant in myParticipants)
                      _PlayerEventCard(
                        participant: participant,
                        event: eventsById[participant.eventId]!,
                        matches: data.matches,
                        participants: data.participants,
                        currentUserId: currentUserId,
                        repository: repository,
                        onChanged: onRefresh,
                      ),
                  const SizedBox(height: 28),
                  const _SectionHeading(
                    icon: Icons.emoji_events_outlined,
                    title: 'Ranking mensal',
                    subtitle:
                        'Classificacao por pontos, com desempate pelo numero de vitorias.',
                  ),
                  const SizedBox(height: 12),
                  if (data.ranking.isEmpty)
                    const _EmptyCard(
                      message:
                          'O ranking deste mes sera exibido apos as inscricoes.',
                    )
                  else
                    _RankingTable(entries: data.ranking),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  final WeeklyDashboardData data;
  final String gameSlug;
  final DateTime month;
  final WeeklyTournamentRepository repository;
  final Future<void> Function() onChanged;

  const _AdminPanel({
    required this.data,
    required this.gameSlug,
    required this.month,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final openEvents = data.events
        .where((event) => event.status == 'open')
        .length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminOverview(
                  month: month,
                  eventCount: data.events.length,
                  openEventCount: openEvents,
                  playerCount: data.participants.length,
                  matchCount: data.matches.length,
                  onCreate: () async {
                    final created = await showDialog<bool>(
                      context: context,
                      builder: (_) => _CreateEventDialog(
                        gameSlug: gameSlug,
                        repository: repository,
                      ),
                    );
                    if (created == true) await onChanged();
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeading(
                  icon: Icons.tune_outlined,
                  title: 'Gerenciar encontros',
                  subtitle:
                      'Abra um semanal para controlar participantes, mesas, byes e resultados.',
                ),
                const SizedBox(height: 12),
                if (data.events.isEmpty)
                  const _EmptyCard(
                    message: 'Nenhum semanal cadastrado neste mes.',
                  )
                else
                  for (final event in data.events)
                    _AdminEventCard(
                      event: event,
                      participants: data.participants
                          .where((item) => item.eventId == event.id)
                          .toList(growable: false),
                      matches: data.matches
                          .where((item) => item.eventId == event.id)
                          .toList(growable: false),
                      profiles: data.profiles,
                      leaders: data.leaders,
                      repository: repository,
                      onChanged: onChanged,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminOverview extends StatelessWidget {
  final DateTime month;
  final int eventCount;
  final int openEventCount;
  final int playerCount;
  final int matchCount;
  final Future<void> Function() onCreate;

  const _AdminOverview({
    required this.month,
    required this.eventCount,
    required this.openEventCount,
    required this.playerCount,
    required this.matchCount,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Painel administrativo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Visao operacional de ${weeklyMonthLabel(month)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Iniciar semanal'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AdminMetric(
                icon: Icons.calendar_month_outlined,
                label: 'Eventos',
                value: '$eventCount',
              ),
              _AdminMetric(
                icon: Icons.play_circle_outline,
                label: 'Abertos',
                value: '$openEventCount',
              ),
              _AdminMetric(
                icon: Icons.groups_outlined,
                label: 'Inscricoes',
                value: '$playerCount',
              ),
              _AdminMetric(
                icon: Icons.sports_esports_outlined,
                label: 'Partidas',
                value: '$matchCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AdminMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.secondary),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyHero extends StatelessWidget {
  final DateTime month;
  final MonthlyRankingEntry? entry;
  final int openEvents;
  final int participationCount;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _WeeklyHero({
    required this.month,
    required this.entry,
    required this.openEvents,
    required this.participationCount,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Circuito mensal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Acompanhe inscricoes, rodadas, desempenho e classificacao.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MonthSelector(
            month: month,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 16),
          _SummaryCard(entry: entry),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(
                icon: Icons.event_available_outlined,
                label: '$participationCount participacoes no mes',
              ),
              _InfoBadge(
                icon: Icons.how_to_reg_outlined,
                label: '$openEvents inscricoes abertas',
              ),
              if (entry != null)
                _InfoBadge(
                  icon: Icons.person_outline,
                  label: 'Nick: ${entry!.playerNickname}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpenEnrollmentCard extends StatelessWidget {
  final WeeklyEvent event;
  final Future<void> Function() onJoin;

  const _OpenEnrollmentCard({required this.event, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.tertiary, width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.event_available_outlined,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd/MM/yyyy').format(event.eventDate)),
                    const SizedBox(height: 6),
                    const _StatusChip(
                      label: 'Aceitando participantes',
                      icon: Icons.circle,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.login),
                label: const Text('Participar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                weeklyMonthLabel(month),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Proximo mes',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthlyRankingEntry? entry;

  const _SummaryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final item = entry;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu desempenho',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(
                label: 'Pontos',
                value: '${item?.points ?? 0}',
                icon: Icons.stars_outlined,
              ),
              _Stat(
                label: 'Partidas',
                value: '${item?.games ?? 0}',
                icon: Icons.sports_esports_outlined,
              ),
              _Stat(
                label: 'Vitorias',
                value: '${item?.wins ?? 0}',
                icon: Icons.emoji_events_outlined,
              ),
              _Stat(
                label: 'Empates',
                value: '${item?.draws ?? 0}',
                icon: Icons.handshake_outlined,
              ),
              _Stat(
                label: 'Derrotas',
                value: '${item?.losses ?? 0}',
                icon: Icons.close,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 124),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerDashboard extends StatelessWidget {
  final MonthlyRankingEntry? entry;

  const _PlayerDashboard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final item = entry;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              icon: Icons.insights_outlined,
              title: 'Seu dashboard',
              subtitle:
                  'Uma leitura rapida dos seus decks e confrontos confirmados neste mes.',
            ),
            const SizedBox(height: 14),
            Text(
              item == null
                  ? 'Suas estatisticas aparecerao depois da primeira inscricao.'
                  : '${item.playerDisplayName} | Nick: ${item.playerNickname}',
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.46,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decks mais jogados',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (item == null || item.deckUsage.isEmpty)
                    const Text('Nenhum deck registrado neste mes.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final deck in item.deckUsage)
                          Chip(
                            avatar: const Icon(Icons.style_outlined, size: 17),
                            label: Text('${deck.deckName}  |  ${deck.games}x'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Desempenho contra decks adversarios',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (item == null || item.opponentDeckStats.isEmpty)
              const Text('Nenhuma partida confirmada contra adversarios.')
            else
              _TableShell(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Deck adversario')),
                    DataColumn(label: Text('Partidas')),
                    DataColumn(label: Text('Vitorias')),
                    DataColumn(label: Text('Empates')),
                    DataColumn(label: Text('Derrotas')),
                  ],
                  rows: [
                    for (final deck in item.opponentDeckStats)
                      DataRow(
                        cells: [
                          DataCell(Text(deck.deckName)),
                          DataCell(Text('${deck.games}')),
                          DataCell(Text('${deck.wins}')),
                          DataCell(Text('${deck.draws}')),
                          DataCell(Text('${deck.losses}')),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerEventCard extends StatelessWidget {
  final WeeklyParticipant participant;
  final WeeklyEvent event;
  final List<WeeklyMatch> matches;
  final List<WeeklyParticipant> participants;
  final String currentUserId;
  final WeeklyTournamentRepository repository;
  final Future<void> Function() onChanged;

  const _PlayerEventCard({
    required this.participant,
    required this.event,
    required this.matches,
    required this.participants,
    required this.currentUserId,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final eventMatches = matches
        .where(
          (match) =>
              match.eventId == event.id &&
              (match.playerOneId == participant.id ||
                  match.playerTwoId == participant.id),
        )
        .toList(growable: false);
    var wins = 0;
    var draws = 0;
    for (final match in eventMatches.where((item) => item.isCompleted)) {
      if (match.result == 'draw') {
        draws++;
      } else if ((match.result == 'player_one' &&
              match.playerOneId == participant.id) ||
          (match.result == 'player_two' &&
              match.playerTwoId == participant.id)) {
        wins++;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.event_available_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              Text(DateFormat('dd/MM/yyyy').format(event.eventDate)),
              Text('Lider/deck: ${participant.leaderName}'),
            ],
          ),
        ),
        trailing: Text(
          '${(wins * 3) + draws} pts',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (eventMatches.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhuma partida cadastrada para voce.'),
            )
          else
            for (final match in eventMatches)
              _PlayerMatchTile(
                match: match,
                participant: participant,
                participants: participants,
                currentUserId: currentUserId,
                repository: repository,
                onChanged: onChanged,
              ),
        ],
      ),
    );
  }
}

class _PlayerMatchTile extends StatelessWidget {
  final WeeklyMatch match;
  final WeeklyParticipant participant;
  final List<WeeklyParticipant> participants;
  final String currentUserId;
  final WeeklyTournamentRepository repository;
  final Future<void> Function() onChanged;

  const _PlayerMatchTile({
    required this.match,
    required this.participant,
    required this.participants,
    required this.currentUserId,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final opponentId = match.playerOneId == participant.id
        ? match.playerTwoId
        : match.playerOneId;
    final opponent = participants
        .where((item) => item.id == opponentId)
        .firstOrNull;
    final canReport =
        !match.isBye &&
        (match.resultStatus == 'scheduled' || match.resultStatus == 'disputed');
    final canReview =
        !match.isBye &&
        match.resultStatus == 'pending_confirmation' &&
        match.reportedBy != currentUserId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(match.isBye ? Icons.star_outline : Icons.sports_esports),
      title: Text(
        match.isBye
            ? 'Rodada ${match.roundNumber}: Bye'
            : 'Rodada ${match.roundNumber}: ${opponent?.playerName ?? '?'}',
      ),
      subtitle: Text(_matchStatusLabel(match)),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (canReport)
            TextButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (_) => _ReportResultDialog(
                    match: match,
                    participantId: participant.id,
                  ),
                );
                if (result == null) return;
                await repository.reportMatchResult(
                  matchId: match.id,
                  result: result,
                );
                await onChanged();
              },
              child: const Text('Informar resultado'),
            ),
          if (canReview) ...[
            TextButton(
              onPressed: () async {
                await repository.reviewMatchResult(
                  matchId: match.id,
                  confirm: false,
                );
                await onChanged();
              },
              child: const Text('Contestar'),
            ),
            FilledButton(
              onPressed: () async {
                await repository.reviewMatchResult(
                  matchId: match.id,
                  confirm: true,
                );
                await onChanged();
              },
              child: const Text('Confirmar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RankingTable extends StatelessWidget {
  final List<MonthlyRankingEntry> entries;

  const _RankingTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _TableShell(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Nome')),
          DataColumn(label: Text('Nick')),
          DataColumn(label: Text('Partidas')),
          DataColumn(label: Text('Wins')),
          DataColumn(label: Text('Empates')),
          DataColumn(label: Text('Loses')),
          DataColumn(label: Text('Top decks')),
          DataColumn(label: Text('Pontos')),
        ],
        rows: [
          for (var index = 0; index < entries.length; index++)
            DataRow(
              cells: [
                DataCell(_RankingPosition(position: index + 1)),
                DataCell(
                  Text(
                    entries[index].playerDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text(entries[index].playerNickname)),
                DataCell(Text('${entries[index].games}')),
                DataCell(Text('${entries[index].wins}')),
                DataCell(Text('${entries[index].draws}')),
                DataCell(Text('${entries[index].losses}')),
                DataCell(Text(entries[index].topDecks.join(', '))),
                DataCell(
                  Text(
                    '${entries[index].points}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  final Widget child;

  const _TableShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

class _RankingPosition extends StatelessWidget {
  final int position;

  const _RankingPosition({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = switch (position) {
      1 => const Color(0xFFD4A017),
      2 => const Color(0xFF8A8F98),
      3 => const Color(0xFFB87333),
      _ => Theme.of(context).colorScheme.outline,
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$position',
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AdminEventCard extends StatelessWidget {
  final WeeklyEvent event;
  final List<WeeklyParticipant> participants;
  final List<WeeklyMatch> matches;
  final List<WeeklyPlayerProfile> profiles;
  final List<WeeklyLeaderOption> leaders;
  final WeeklyTournamentRepository repository;
  final Future<void> Function() onChanged;

  const _AdminEventCard({
    required this.event,
    required this.participants,
    required this.matches,
    required this.profiles,
    required this.leaders,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final isOpen = event.status == 'open';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                (isOpen ? theme.colorScheme.primary : theme.colorScheme.outline)
                    .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            isOpen ? Icons.play_arrow_rounded : Icons.check_rounded,
            color: isOpen
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(
                label: isOpen ? 'Inscricoes abertas' : 'Encerrado',
                icon: isOpen ? Icons.circle : Icons.check_circle,
                color: isOpen ? Colors.green : theme.colorScheme.outline,
              ),
              Text(DateFormat('dd/MM/yyyy').format(event.eventDate)),
              Text('${participants.length} jogadores'),
              Text('${matches.length} partidas'),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isOpen ? 'Semanal aberto' : 'Semanal encerrado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await repository.setEventStatus(
                    eventId: event.id,
                    status: isOpen ? 'finished' : 'open',
                  );
                  await onChanged();
                },
                icon: const Icon(Icons.sync),
                label: Text(isOpen ? 'Encerrar' : 'Reabrir'),
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jogadores',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (_) => _EnrollPlayerDialog(
                      event: event,
                      profiles: profiles,
                      leaders: leaders,
                      repository: repository,
                    ),
                  );
                  if (changed == true) await onChanged();
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          if (participants.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhum jogador inscrito.'),
            )
          else
            for (final participant in participants)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  participant.playerDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Nick: ${participant.playerName}'
                  '  |  Lider/deck: ${participant.deckName}',
                ),
              ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Partidas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: participants.length < 2
                    ? null
                    : () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => _CreateMatchDialog(
                            event: event,
                            participants: participants,
                            repository: repository,
                          ),
                        );
                        if (changed == true) await onChanged();
                      },
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar partida'),
              ),
              TextButton.icon(
                onPressed: participants.isEmpty
                    ? null
                    : () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => _CreateByeDialog(
                            event: event,
                            participants: participants,
                            repository: repository,
                          ),
                        );
                        if (changed == true) await onChanged();
                      },
                icon: const Icon(Icons.star_outline),
                label: const Text('Adicionar bye'),
              ),
            ],
          ),
          if (matches.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nenhuma partida cadastrada.'),
            )
          else
            for (final match in matches)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Rodada ${match.roundNumber}'
                  '${match.tableNumber == null ? '' : ' - Mesa ${match.tableNumber}'}',
                ),
                subtitle: Text(
                  match.isBye
                      ? '${participantsById[match.playerOneId]?.playerName ?? '?'}'
                            ' recebeu bye: vitoria automatica'
                      : '${participantsById[match.playerOneId]?.playerName ?? '?'}'
                            ' x '
                            '${participantsById[match.playerTwoId]?.playerName ?? '?'}'
                            ' | ${_matchStatusLabel(match)}',
                ),
                trailing: match.isBye
                    ? const Text('3 pts')
                    : DropdownButton<String>(
                        value: match.result,
                        onChanged: (value) async {
                          if (value == null) return;
                          await repository.updateMatchResultAsAdmin(
                            matchId: match.id,
                            result: value,
                          );
                          await onChanged();
                        },
                        items: _resultItems,
                      ),
              ),
        ],
      ),
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  final String gameSlug;
  final WeeklyTournamentRepository repository;

  const _CreateEventDialog({required this.gameSlug, required this.repository});

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Iniciar semanal'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nome do semanal',
                hintText: 'Ex.: Semanal 01',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (selected != null) setState(() => _date = selected);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (_titleController.text.trim().isEmpty) return;
                  setState(() => _busy = true);
                  await widget.repository.createEvent(
                    gameSlug: widget.gameSlug,
                    title: _titleController.text,
                    date: _date,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

class _EnrollPlayerDialog extends StatefulWidget {
  final WeeklyEvent event;
  final List<WeeklyPlayerProfile> profiles;
  final WeeklyTournamentRepository repository;
  final List<WeeklyLeaderOption> leaders;

  const _EnrollPlayerDialog({
    required this.event,
    required this.profiles,
    required this.repository,
    required this.leaders,
  });

  @override
  State<_EnrollPlayerDialog> createState() => _EnrollPlayerDialogState();
}

class _EnrollPlayerDialogState extends State<_EnrollPlayerDialog> {
  final _deckController = TextEditingController();
  String? _profileId;
  String? _leaderCode;
  bool _busy = false;

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar jogador'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _profileId,
              decoration: const InputDecoration(labelText: 'Jogador'),
              items: [
                for (final profile in widget.profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    child: Text(
                      profile.name.trim().isEmpty
                          ? profile.email
                          : profile.name,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _profileId = value),
            ),
            const SizedBox(height: 12),
            if (widget.leaders.isNotEmpty)
              _LeaderAutocomplete(
                leaders: widget.leaders,
                onSelected: (leader) {
                  setState(() => _leaderCode = leader?.code);
                },
              )
            else
              TextField(
                controller: _deckController,
                decoration: const InputDecoration(
                  labelText: 'Deck / lider utilizado',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final id = _profileId;
                  final leader = _findLeader(widget.leaders, _leaderCode);
                  final deck = leader?.label ?? _deckController.text.trim();
                  if (id == null || deck.isEmpty) return;
                  setState(() => _busy = true);
                  final profile = widget.profiles.firstWhere(
                    (item) => item.id == id,
                  );
                  await widget.repository.enrollPlayer(
                    eventId: widget.event.id,
                    profile: profile,
                    deckName: deck,
                    leaderCode: leader?.code ?? '',
                    leaderName: leader?.name ?? deck,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _JoinWeeklyDialog extends StatefulWidget {
  final WeeklyEvent event;
  final String gameSlug;
  final WeeklyGameProfile? gameProfile;
  final List<WeeklyLeaderOption> leaders;
  final WeeklyTournamentRepository repository;

  const _JoinWeeklyDialog({
    required this.event,
    required this.gameSlug,
    required this.gameProfile,
    required this.leaders,
    required this.repository,
  });

  @override
  State<_JoinWeeklyDialog> createState() => _JoinWeeklyDialogState();
}

class _JoinWeeklyDialogState extends State<_JoinWeeklyDialog> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _bandaiController;
  final _deckController = TextEditingController();
  String? _leaderCode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.gameProfile?.nickname ?? '',
    );
    _bandaiController = TextEditingController(
      text: widget.gameProfile?.bandaiCode ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bandaiController.dispose();
    _deckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Participar de ${widget.event.title}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Seu nick neste card game',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bandaiController,
              decoration: const InputDecoration(
                labelText: 'Codigo Bandai (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            if (widget.leaders.isNotEmpty)
              _LeaderAutocomplete(
                leaders: widget.leaders,
                onSelected: (leader) {
                  setState(() => _leaderCode = leader?.code);
                },
              )
            else
              TextField(
                controller: _deckController,
                decoration: const InputDecoration(
                  labelText: 'Deck / lider utilizado',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final nickname = _nicknameController.text.trim();
                  final leader = _findLeader(widget.leaders, _leaderCode);
                  final deck = leader?.label ?? _deckController.text.trim();
                  if (nickname.isEmpty || deck.isEmpty) return;
                  setState(() => _busy = true);
                  await widget.repository.joinOpenEvent(
                    eventId: widget.event.id,
                    gameSlug: widget.gameSlug,
                    nickname: nickname,
                    bandaiCode: _bandaiController.text,
                    deckName: deck,
                    leaderCode: leader?.code ?? '',
                    leaderName: leader?.name ?? deck,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Confirmar participacao'),
        ),
      ],
    );
  }
}

class _CreateMatchDialog extends StatefulWidget {
  final WeeklyEvent event;
  final List<WeeklyParticipant> participants;
  final WeeklyTournamentRepository repository;

  const _CreateMatchDialog({
    required this.event,
    required this.participants,
    required this.repository,
  });

  @override
  State<_CreateMatchDialog> createState() => _CreateMatchDialogState();
}

class _CreateMatchDialogState extends State<_CreateMatchDialog> {
  final _roundController = TextEditingController(text: '1');
  final _tableController = TextEditingController();
  String? _playerOneId;
  String? _playerTwoId;
  String _result = 'scheduled';
  bool _busy = false;

  @override
  void dispose() {
    _roundController.dispose();
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cadastrar partida'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roundController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rodada'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tableController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mesa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _playerOneId,
              decoration: const InputDecoration(labelText: 'Jogador 1'),
              items: _participantItems(widget.participants),
              onChanged: (value) => setState(() => _playerOneId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _playerTwoId,
              decoration: const InputDecoration(labelText: 'Jogador 2'),
              items: _participantItems(widget.participants),
              onChanged: (value) => setState(() => _playerTwoId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _result,
              decoration: const InputDecoration(labelText: 'Resultado'),
              items: _resultItems,
              onChanged: (value) => setState(() => _result = value!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final round = int.tryParse(_roundController.text);
                  final table = int.tryParse(_tableController.text);
                  if (round == null ||
                      round <= 0 ||
                      _playerOneId == null ||
                      _playerTwoId == null ||
                      _playerOneId == _playerTwoId) {
                    return;
                  }
                  setState(() => _busy = true);
                  await widget.repository.createMatch(
                    eventId: widget.event.id,
                    roundNumber: round,
                    tableNumber: table,
                    playerOneId: _playerOneId!,
                    playerTwoId: _playerTwoId!,
                    result: _result,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _CreateByeDialog extends StatefulWidget {
  final WeeklyEvent event;
  final List<WeeklyParticipant> participants;
  final WeeklyTournamentRepository repository;

  const _CreateByeDialog({
    required this.event,
    required this.participants,
    required this.repository,
  });

  @override
  State<_CreateByeDialog> createState() => _CreateByeDialogState();
}

class _CreateByeDialogState extends State<_CreateByeDialog> {
  final _roundController = TextEditingController(text: '1');
  String? _playerId;
  bool _busy = false;

  @override
  void dispose() {
    _roundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar bye'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _roundController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rodada'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _playerId,
              decoration: const InputDecoration(labelText: 'Jogador'),
              items: _participantItems(widget.participants),
              onChanged: (value) => setState(() => _playerId = value),
            ),
            const SizedBox(height: 10),
            const Text('O jogador recebera uma vitoria automatica e 3 pontos.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final round = int.tryParse(_roundController.text);
                  if (round == null || round <= 0 || _playerId == null) return;
                  setState(() => _busy = true);
                  await widget.repository.createBye(
                    eventId: widget.event.id,
                    roundNumber: round,
                    playerId: _playerId!,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Adicionar bye'),
        ),
      ],
    );
  }
}

class _ReportResultDialog extends StatelessWidget {
  final WeeklyMatch match;
  final String participantId;

  const _ReportResultDialog({required this.match, required this.participantId});

  @override
  Widget build(BuildContext context) {
    final winResult = match.playerOneId == participantId
        ? 'player_one'
        : 'player_two';
    final lossResult = match.playerOneId == participantId
        ? 'player_two'
        : 'player_one';
    return AlertDialog(
      title: const Text('Informar resultado'),
      content: const Text(
        'O adversario precisara confirmar o resultado antes da pontuacao.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'draw'),
          child: const Text('Empate'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, lossResult),
          child: const Text('Derrota'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, winResult),
          child: const Text('Vitoria'),
        ),
      ],
    );
  }
}

class _LeaderAutocomplete extends StatefulWidget {
  final List<WeeklyLeaderOption> leaders;
  final ValueChanged<WeeklyLeaderOption?> onSelected;

  const _LeaderAutocomplete({required this.leaders, required this.onSelected});

  @override
  State<_LeaderAutocomplete> createState() => _LeaderAutocompleteState();
}

class _LeaderAutocompleteState extends State<_LeaderAutocomplete> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<WeeklyLeaderOption>(
      displayStringForOption: (leader) => leader.label,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return widget.leaders;
        return widget.leaders.where(
          (leader) =>
              leader.name.toLowerCase().contains(query) ||
              leader.code.toLowerCase().contains(query),
        );
      },
      onSelected: (leader) {
        _selectedLabel = leader.label;
        widget.onSelected(leader);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmitted(),
          onChanged: (value) {
            if (_selectedLabel != null && value != _selectedLabel) {
              _selectedLabel = null;
              widget.onSelected(null);
            }
          },
          decoration: const InputDecoration(
            labelText: 'Pesquisar lider',
            hintText: 'Digite o nome ou codigo. Ex.: Enel',
            prefixIcon: Icon(Icons.search),
          ),
        );
      },
      optionsViewBuilder: (context, selectOption, options) {
        final items = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 460),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final leader = items[index];
                  return ListTile(
                    title: Text(leader.name),
                    subtitle: Text(leader.code),
                    onTap: () => selectOption(leader),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Nao foi possivel carregar os semanais.'),
            const SizedBox(height: 6),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

List<DropdownMenuItem<String>> _participantItems(
  List<WeeklyParticipant> participants,
) {
  return [
    for (final participant in participants)
      DropdownMenuItem(
        value: participant.id,
        child: Text(participant.playerName),
      ),
  ];
}

const _resultItems = [
  DropdownMenuItem(value: 'scheduled', child: Text('Aguardando resultado')),
  DropdownMenuItem(value: 'player_one', child: Text('Vitoria do jogador 1')),
  DropdownMenuItem(value: 'draw', child: Text('Empate')),
  DropdownMenuItem(value: 'player_two', child: Text('Vitoria do jogador 2')),
];

WeeklyLeaderOption? _findLeader(
  List<WeeklyLeaderOption> leaders,
  String? code,
) {
  return leaders.where((leader) => leader.code == code).firstOrNull;
}

String _matchStatusLabel(WeeklyMatch match) {
  if (match.isBye) return 'Vitoria automatica por bye';
  return switch (match.resultStatus) {
    'scheduled' => 'Aguardando resultado',
    'pending_confirmation' => 'Aguardando confirmacao do adversario',
    'disputed' => 'Resultado contestado',
    'confirmed' => switch (match.result) {
      'player_one' => 'Vitoria do jogador 1 confirmada',
      'player_two' => 'Vitoria do jogador 2 confirmada',
      'draw' => 'Empate confirmado',
      _ => 'Resultado confirmado',
    },
    _ => match.resultStatus,
  };
}

String _gameTitle(String slug) {
  return switch (slug) {
    'one-piece' => 'One Piece',
    'pokemon' => 'Pokemon',
    'yugioh' => 'Yu-Gi-Oh',
    'digimon' => 'Digimon',
    'magic' => 'Magic',
    'riftbound' => 'Riftbound',
    _ => slug,
  };
}

String _hubRoute(String slug) {
  return slug == 'one-piece' ? '/home/one-piece' : '/$slug';
}

String weeklyMonthLabel(DateTime month) {
  const months = [
    'janeiro',
    'fevereiro',
    'marco',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${months[month.month - 1]} ${month.year}';
}
