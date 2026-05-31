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
    _reload();
  }

  void _reload() {
    _future = _repository.loadDashboard(
      gameSlug: widget.gameSlug,
      month: _month,
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
            currentUserId: _repository.currentUserId,
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
  final String currentUserId;
  final DateTime month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final Future<void> Function() onRefresh;

  const _PlayerPanel({
    required this.data,
    required this.currentUserId,
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

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MonthSelector(
            month: month,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 20),
          _SummaryCard(entry: myRanking),
          const SizedBox(height: 24),
          Text(
            'Meus semanais',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (myParticipants.isEmpty)
            const _EmptyCard(
              message: 'Voce ainda nao participou de semanais neste mes.',
            )
          else
            for (final participant in myParticipants)
              _PlayerEventCard(
                participant: participant,
                event: eventsById[participant.eventId]!,
                matches: data.matches,
                participants: data.participants,
              ),
          const SizedBox(height: 24),
          Text(
            'Ranking mensal',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (data.ranking.isEmpty)
            const _EmptyCard(
              message: 'O ranking deste mes sera exibido apos as inscricoes.',
            )
          else
            _RankingTable(entries: data.ranking),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Gerenciar semanais',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateEventDialog(
                    gameSlug: gameSlug,
                    repository: repository,
                  ),
                );
                if (created == true) await onChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Iniciar semanal'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cadastre participantes, deck usado no dia e resultados das mesas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (data.events.isEmpty)
          const _EmptyCard(message: 'Nenhum semanal cadastrado neste mes.')
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
              repository: repository,
              onChanged: onChanged,
            ),
      ],
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
    return Card(
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu desempenho no mes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(label: 'Pontos', value: '${item?.points ?? 0}'),
              _Stat(label: 'Partidas', value: '${item?.games ?? 0}'),
              _Stat(label: 'Vitorias', value: '${item?.wins ?? 0}'),
              _Stat(label: 'Empates', value: '${item?.draws ?? 0}'),
              _Stat(label: 'Derrotas', value: '${item?.losses ?? 0}'),
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

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _PlayerEventCard extends StatelessWidget {
  final WeeklyParticipant participant;
  final WeeklyEvent event;
  final List<WeeklyMatch> matches;
  final List<WeeklyParticipant> participants;

  const _PlayerEventCard({
    required this.participant,
    required this.event,
    required this.matches,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final eventMatches = matches
        .where(
          (match) =>
              match.eventId == event.id &&
              match.isCompleted &&
              (match.playerOneId == participant.id ||
                  match.playerTwoId == participant.id),
        )
        .toList(growable: false);
    var wins = 0;
    var draws = 0;
    for (final match in eventMatches) {
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
      child: ListTile(
        leading: const Icon(Icons.event_available_outlined),
        title: Text(event.title),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(event.eventDate)}'
          '  |  Deck: ${participant.deckName}',
        ),
        trailing: Text(
          '${(wins * 3) + draws} pts',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _RankingTable extends StatelessWidget {
  final List<MonthlyRankingEntry> entries;

  const _RankingTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Jogador')),
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
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(entries[index].playerName)),
                  DataCell(Text('${entries[index].games}')),
                  DataCell(Text('${entries[index].wins}')),
                  DataCell(Text('${entries[index].draws}')),
                  DataCell(Text('${entries[index].losses}')),
                  DataCell(Text(entries[index].topDecks.join(', '))),
                  DataCell(Text('${entries[index].points}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminEventCard extends StatelessWidget {
  final WeeklyEvent event;
  final List<WeeklyParticipant> participants;
  final List<WeeklyMatch> matches;
  final List<WeeklyPlayerProfile> profiles;
  final WeeklyTournamentRepository repository;
  final Future<void> Function() onChanged;

  const _AdminEventCard({
    required this.event,
    required this.participants,
    required this.matches,
    required this.profiles,
    required this.repository,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    return Card(
      child: ExpansionTile(
        leading: Icon(
          event.status == 'open'
              ? Icons.play_circle_outline
              : Icons.check_circle_outline,
        ),
        title: Text(event.title),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(event.eventDate)}'
          '  |  ${participants.length} jogadores'
          '  |  ${matches.length} partidas',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.status == 'open'
                      ? 'Semanal aberto'
                      : 'Semanal encerrado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await repository.setEventStatus(
                    eventId: event.id,
                    status: event.status == 'open' ? 'finished' : 'open',
                  );
                  await onChanged();
                },
                icon: const Icon(Icons.sync),
                label: Text(event.status == 'open' ? 'Encerrar' : 'Reabrir'),
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
                title: Text(participant.playerName),
                subtitle: Text('Deck: ${participant.deckName}'),
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
                  '${participantsById[match.playerOneId]?.playerName ?? '?'}'
                  ' x '
                  '${participantsById[match.playerTwoId]?.playerName ?? '?'}',
                ),
                trailing: DropdownButton<String>(
                  value: match.result,
                  onChanged: (value) async {
                    if (value == null) return;
                    await repository.updateMatchResult(
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

  const _EnrollPlayerDialog({
    required this.event,
    required this.profiles,
    required this.repository,
  });

  @override
  State<_EnrollPlayerDialog> createState() => _EnrollPlayerDialogState();
}

class _EnrollPlayerDialogState extends State<_EnrollPlayerDialog> {
  final _deckController = TextEditingController();
  String? _profileId;
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
            TextField(
              controller: _deckController,
              decoration: const InputDecoration(labelText: 'Deck usado'),
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
                  final deck = _deckController.text.trim();
                  if (id == null || deck.isEmpty) return;
                  setState(() => _busy = true);
                  final profile = widget.profiles.firstWhere(
                    (item) => item.id == id,
                  );
                  await widget.repository.enrollPlayer(
                    eventId: widget.event.id,
                    profile: profile,
                    deckName: deck,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Salvar'),
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
