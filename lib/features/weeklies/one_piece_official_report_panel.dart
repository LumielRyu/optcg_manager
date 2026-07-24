import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_error_reporter.dart';
import '../../data/models/one_piece_standings_report.dart';
import '../../data/models/weekly_tournament.dart';
import '../../data/repositories/one_piece_tournament_report_repository.dart';
import '../../data/services/csv_file_picker.dart';
import '../../data/services/one_piece_monthly_ranking.dart';
import '../../data/services/one_piece_report_exporter.dart';
import '../../data/services/one_piece_standings_parser.dart';
import '../../data/services/op_api_service.dart';

const _gold = Color(0xFFE6A935);
const _cream = Color(0xFFF4E6C6);
const _ruby = Color(0xFFD54C3F);

enum _OnePieceReportView { ranking, metagame, files }

class OnePieceOfficialReportPanel extends ConsumerStatefulWidget {
  const OnePieceOfficialReportPanel({super.key});

  @override
  ConsumerState<OnePieceOfficialReportPanel> createState() =>
      _OnePieceOfficialReportPanelState();
}

class _OnePieceOfficialReportPanelState
    extends ConsumerState<OnePieceOfficialReportPanel> {
  static const _parser = OnePieceStandingsParser();
  late Future<List<StoredOnePieceTournamentReport>> _future;
  Future<List<WeeklyLeaderOption>>? _leadersFuture;
  Map<String, WeeklyLeaderOption> _leaderHints = const {};
  DateTime? _selectedMonth;
  _OnePieceReportView _selectedView = _OnePieceReportView.ranking;
  bool _importing = false;

  OnePieceTournamentReportRepository get _repository =>
      ref.read(onePieceTournamentReportRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _loadReports();
  }

  void _reload() {
    setState(() => _future = _loadReports());
  }

  Future<List<StoredOnePieceTournamentReport>> _loadReports() async {
    final reports = await _repository.loadReports();
    final hints = <String, WeeklyLeaderOption>{};
    for (final stored in reports) {
      for (final player in stored.report.players) {
        if (!player.hasLeader) continue;
        hints.putIfAbsent(
          _playerKey(player),
          () => WeeklyLeaderOption(
            code: player.leaderCode,
            name: player.leaderName,
          ),
        );
      }
    }
    _leaderHints = hints;
    return reports;
  }

  Future<List<WeeklyLeaderOption>> _loadLeaders() {
    return _leadersFuture ??= () async {
      try {
        final cards = await ref.read(opApiServiceProvider).loadAllCards();
        final byCode = <String, WeeklyLeaderOption>{};
        for (final card in cards.where(
          (item) => item.type.toLowerCase() == 'leader',
        )) {
          final code = card.code.trim().toUpperCase();
          final name = normalizeWeeklyLeaderName(card.name);
          if (code.isEmpty || name.isEmpty) continue;
          byCode.putIfAbsent(
            code,
            () => WeeklyLeaderOption(code: code, name: name, image: card.image),
          );
        }
        final leaders = byCode.values.toList();
        leaders.sort((a, b) {
          final byRelease = weeklyLeaderReleaseOrder(
            b.code,
          ).compareTo(weeklyLeaderReleaseOrder(a.code));
          if (byRelease != 0) return byRelease;
          return b.code.compareTo(a.code);
        });
        return leaders;
      } catch (_) {
        return const <WeeklyLeaderOption>[];
      }
    }();
  }

  Future<void> _importCsv() async {
    setState(() => _importing = true);
    try {
      final file = await pickCsvFile();
      if (!mounted || file == null) return;
      if (!isOnePieceStandingsFileName(file.name)) {
        return _message(
          'Selecione o arquivo CSV de classificacao do Bandai TCG+.',
        );
      }
      if (file.bytes.isEmpty) {
        return _message(
          'O arquivo selecionado esta vazio ou nao pode ser lido.',
        );
      }
      final initial = _parser.parseBytes(
        file.bytes,
        fileName: file.name,
        eventDate: DateTime.now(),
      );
      final leaders = await _loadLeaders();
      if (!mounted) return;
      final report = await showDialog<OnePieceStandingsReport>(
        context: context,
        builder: (context) => _ImportDetailsDialog(
          report: initial,
          leaders: leaders,
          leaderHints: _leaderHints,
        ),
      );
      if (report == null || !mounted) return;
      final existing = await _repository.findBySourceKey(report.sourceKey);
      if (!mounted) return;
      if (existing != null) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Substituir relatorio?'),
            content: Text(
              'Ja existe um resultado de ${report.eventName} nesta data. '
              'Deseja substituir os dados atuais?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Substituir'),
              ),
            ],
          ),
        );
        if (replace != true) return;
      }
      await _repository.saveReport(report);
      if (!mounted) return;
      _reload();
      _message(
        existing == null
            ? 'Semanal importado com sucesso.'
            : 'Semanal atualizado com sucesso.',
      );
    } on FormatException catch (error) {
      _message(error.message);
    } catch (error, stackTrace) {
      final reference = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'one-piece-weekly.import-csv',
      );
      _message('Nao foi possivel importar o CSV. Codigo do erro: $reference');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(StoredOnePieceTournamentReport stored) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir relatorio?'),
        content: Text(
          'O resultado de ${stored.report.eventName} sera removido do historico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteReport(stored.id);
      if (!mounted) return;
      _reload();
      _message('Relatorio excluido.');
    } catch (error, stackTrace) {
      final reference = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'one-piece-weekly.delete-report',
      );
      _message('Nao foi possivel excluir. Codigo do erro: $reference');
    }
  }

  Future<void> _export(OnePieceStandingsReport report) async {
    try {
      await exportOnePieceReportCsv(report);
      _message('Relatorio CSV exportado com sucesso.');
    } catch (error, stackTrace) {
      final reference = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'one-piece-weekly.export-csv',
      );
      _message('Nao foi possivel exportar. Codigo do erro: $reference');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openReport(OnePieceStandingsReport report) {
    final pirateTheme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: pirateTheme,
        child: _TournamentReportDialog(
          report: report,
          onExport: () => _export(report),
        ),
      ),
    );
  }

  Future<void> _openTvRanking(OnePieceStandingsReport report) async {
    final leaders = await _loadLeaders();
    if (!mounted) return;
    final leadersByCode = {
      for (final leader in leaders) leader.code.trim().toUpperCase(): leader,
    };
    await showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) =>
          _TvRankingDialog(report: report, leadersByCode: leadersByCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _repository.isAdmin;
    return FutureBuilder<List<StoredOnePieceTournamentReport>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: _ruby),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Os relatorios oficiais do One Piece nao puderam ser carregados.',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
        final reports = snapshot.data ?? const [];
        final latest = reports.firstOrNull;
        final months = _availableMonths(reports);
        final selectedMonth = _resolveMonth(months, _selectedMonth);
        final monthlyRanking = buildOnePieceMonthlyRanking(
          reports.map((stored) => stored.report),
          month: selectedMonth,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReportHero(
              reports: reports.length,
              latest: latest?.report,
              isAdmin: isAdmin,
              importing: _importing,
              onImport: _importCsv,
            ),
            if (reports.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReportViewNavigation(
                selected: _selectedView,
                onSelected: (view) => setState(() => _selectedView = view),
              ),
              const SizedBox(height: 10),
              _MonthlyRankingSection(
                ranking: monthlyRanking,
                months: months,
                view: _selectedView,
                onMonthChanged: (month) {
                  setState(() => _selectedMonth = month);
                },
                reports: reports,
                isAdmin: isAdmin,
                onView: (stored) => _openReport(stored.report),
                onTv: (stored) => _openTvRanking(stored.report),
                onDelete: _delete,
              ),
            ] else ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.flag_circle_outlined,
                        color: _gold,
                        size: 50,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Nenhum resultado oficial importado.',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAdmin
                            ? 'Importe o arquivo *_standing.csv gerado pelo Bandai TCG+.'
                            : 'O resultado aparecera aqui assim que a equipe da STOP TCG importar o CSV.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _playerKey(OnePieceStandingPlayer player) {
  final membership = player.membershipNumber.trim();
  return membership.isNotEmpty
      ? 'id:$membership'
      : 'name:${player.userName.trim().toLowerCase()}';
}

List<DateTime> _availableMonths(List<StoredOnePieceTournamentReport> reports) {
  final values = <String, DateTime>{};
  for (final stored in reports) {
    final date = stored.report.eventDate;
    values['${date.year}-${date.month}'] = DateTime(date.year, date.month);
  }
  final months = values.values.toList()..sort((a, b) => b.compareTo(a));
  return months;
}

DateTime _resolveMonth(List<DateTime> months, DateTime? selected) {
  if (selected != null) {
    for (final month in months) {
      if (month.year == selected.year && month.month == selected.month) {
        return month;
      }
    }
  }
  final now = DateTime.now();
  return months.firstOrNull ?? DateTime(now.year, now.month);
}

String _monthLabel(DateTime month) {
  const names = [
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
  return '${names[month.month - 1]} ${month.year}';
}

String _victoryLabel(int value) =>
    '$value ${value == 1 ? 'vitoria' : 'vitorias'}';

class _ReportViewNavigation extends StatelessWidget {
  final _OnePieceReportView selected;
  final ValueChanged<_OnePieceReportView> onSelected;

  const _ReportViewNavigation({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF07161C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.45)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _ReportViewButton(
            icon: Icons.leaderboard_outlined,
            label: 'Ranking mensal',
            selected: selected == _OnePieceReportView.ranking,
            onPressed: () => onSelected(_OnePieceReportView.ranking),
          ),
          _ReportViewButton(
            icon: Icons.style_outlined,
            label: 'Metagame',
            selected: selected == _OnePieceReportView.metagame,
            onPressed: () => onSelected(_OnePieceReportView.metagame),
          ),
          _ReportViewButton(
            icon: Icons.folder_copy_outlined,
            label: 'Arquivos importados',
            selected: selected == _OnePieceReportView.files,
            onPressed: () => onSelected(_OnePieceReportView.files),
          ),
        ],
      ),
    );
  }
}

class _ReportViewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ReportViewButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
            label: Text(label),
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
            label: Text(label),
          );
  }
}

class _MonthlyRankingSection extends StatelessWidget {
  final OnePieceMonthlyRanking ranking;
  final List<DateTime> months;
  final _OnePieceReportView view;
  final ValueChanged<DateTime> onMonthChanged;
  final List<StoredOnePieceTournamentReport> reports;
  final bool isAdmin;
  final ValueChanged<StoredOnePieceTournamentReport> onView;
  final ValueChanged<StoredOnePieceTournamentReport> onTv;
  final ValueChanged<StoredOnePieceTournamentReport> onDelete;

  const _MonthlyRankingSection({
    required this.ranking,
    required this.months,
    required this.view,
    required this.onMonthChanged,
    required this.reports,
    required this.isAdmin,
    required this.onView,
    required this.onTv,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = _monthLabel(ranking.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view == _OnePieceReportView.ranking)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.leaderboard_outlined, color: _gold),
                      Text(
                        'Ranking mensal dos piratas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      DropdownButton<DateTime>(
                        value: ranking.month,
                        items: [
                          for (final month in months)
                            DropdownMenuItem(
                              value: month,
                              child: Text(_monthLabel(month)),
                            ),
                        ],
                        onChanged: (month) {
                          if (month != null) onMonthChanged(month);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Os Win Points de todos os arquivos de $monthLabel sao somados automaticamente.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _cream.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (ranking.players.isEmpty)
                    const Text('Nenhum resultado importado neste mes.')
                  else
                    _PlayerRankingContent(entries: ranking.players),
                ],
              ),
            ),
          ),
        if (view == _OnePieceReportView.metagame)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.style_outlined, color: _ruby),
                      Text(
                        'Metagame da STOP TCG',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${ranking.identifiedDeckEntries}/${ranking.totalDeckEntries} decks identificados',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${ranking.leaderCoverage.toStringAsFixed(0)}% de cobertura',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'A win rate usa as vitorias registradas nos Win Points e o total de rodadas confirmado na importacao.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _cream.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (ranking.leaders.isEmpty)
                    const Text(
                      'Nenhum lider foi identificado neste mes. A informacao e opcional e pode ser preenchida nas proximas importacoes.',
                    )
                  else
                    _LeaderRankingContent(entries: ranking.leaders),
                ],
              ),
            ),
          ),
        if (view == _OnePieceReportView.files)
          _ReportHistory(
            reports: reports,
            isAdmin: isAdmin,
            onView: onView,
            onTv: onTv,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _PlayerRankingContent extends StatelessWidget {
  final List<OnePieceMonthlyPlayerEntry> entries;

  const _PlayerRankingContent({required this.entries});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (var index = 0; index < entries.length; index++)
                _PlayerRankingTile(position: index + 1, entry: entries[index]),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: DataTable(
            dataRowMinHeight: 56,
            dataRowMaxHeight: 68,
            columns: const [
              DataColumn(label: Text('Pos.')),
              DataColumn(label: Text('Jogador')),
              DataColumn(label: Text('Torneios')),
              DataColumn(label: Text('Pontos')),
              DataColumn(label: Text('Melhor resultado')),
            ],
            rows: [
              for (var index = 0; index < entries.length; index++)
                DataRow(
                  cells: [
                    DataCell(_Placement(value: index + 1)),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[index].name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_victoryLabel(entries[index].wins)} • OMW ${entries[index].averageOmw.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text('${entries[index].tournaments}')),
                    DataCell(
                      Text(
                        '${entries[index].winPoints}',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        entries[index].bestPlacement == null
                            ? '-'
                            : '${entries[index].bestPlacement}º',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerRankingTile extends StatelessWidget {
  final int position;
  final OnePieceMonthlyPlayerEntry entry;

  const _PlayerRankingTile({required this.position, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          SizedBox(width: 42, child: _Placement(value: position)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.tournaments} torneio${entry.tournaments == 1 ? '' : 's'} • ${_victoryLabel(entry.wins)} • melhor ${entry.bestPlacement == null ? '-' : '${entry.bestPlacement}º'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.winPoints}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('pontos', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderRankingContent extends StatelessWidget {
  final List<OnePieceLeaderRankingEntry> entries;

  const _LeaderRankingContent({required this.entries});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (var index = 0; index < entries.length; index++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _ruby.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 42, child: _Placement(value: index + 1)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entries[index].label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${entries[index].uses} usos • ${entries[index].wins}V / ${entries[index].losses}D',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${entries[index].winRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Pos.')),
              DataColumn(label: Text('Lider / deck')),
              DataColumn(label: Text('Usos')),
              DataColumn(label: Text('Vitorias')),
              DataColumn(label: Text('Derrotas')),
              DataColumn(label: Text('Win rate')),
            ],
            rows: [
              for (var index = 0; index < entries.length; index++)
                DataRow(
                  cells: [
                    DataCell(_Placement(value: index + 1)),
                    DataCell(
                      Text(
                        entries[index].label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text('${entries[index].uses}')),
                    DataCell(Text('${entries[index].wins}')),
                    DataCell(Text('${entries[index].losses}')),
                    DataCell(
                      Text(
                        '${entries[index].winRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportHero extends StatelessWidget {
  final int reports;
  final OnePieceStandingsReport? latest;
  final bool isAdmin;
  final bool importing;
  final VoidCallback onImport;

  const _ReportHero({
    required this.reports,
    required this.latest,
    required this.isAdmin,
    required this.importing,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _ruby.withValues(alpha: 0.33),
            const Color(0xFF0A1A20),
            _gold.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.65)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: _gold,
            foregroundColor: Color(0xFF271401),
            child: Icon(Icons.emoji_events_outlined, size: 34),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESULTADO OFICIAL • BANDAI TCG+',
                  style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  latest?.eventName ?? 'Classificacao dos semanais',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$reports torneio${reports == 1 ? '' : 's'} no historico${latest == null ? '' : ' • ${latest!.participantCount} jogadores no arquivo mais recente'}',
                ),
              ],
            ),
          ),
          if (isAdmin)
            FilledButton.icon(
              onPressed: importing ? null : onImport,
              icon: importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(importing ? 'Importando...' : 'Importar CSV'),
            ),
        ],
      ),
    );
  }
}

class _ReportHistory extends StatelessWidget {
  final List<StoredOnePieceTournamentReport> reports;
  final bool isAdmin;
  final ValueChanged<StoredOnePieceTournamentReport> onView;
  final ValueChanged<StoredOnePieceTournamentReport> onTv;
  final ValueChanged<StoredOnePieceTournamentReport> onDelete;

  const _ReportHistory({
    required this.reports,
    required this.isAdmin,
    required this.onView,
    required this.onTv,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pergaminhos da Grand Line',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _gold,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cada arquivo preserva a classificacao oficial publicada pelo Bandai TCG+.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _cream.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: reports.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final stored = reports[index];
                  final report = stored.report;
                  return InkWell(
                    onTap: () => onView(stored),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 310,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _ruby.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _gold.withValues(alpha: 0.7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            color: _gold,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.eventName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${DateFormat('dd/MM/yyyy').format(report.eventDate)} • ${report.participantCount} piratas',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  report.sourceFileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => onTv(stored),
                                      icon: const Icon(Icons.tv, size: 18),
                                      label: const Text('Modo TV'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => onView(stored),
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Detalhes'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              tooltip: 'Excluir relatorio',
                              onPressed: () => onDelete(stored),
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvRankingDialog extends StatelessWidget {
  final OnePieceStandingsReport report;
  final Map<String, WeeklyLeaderOption> leadersByCode;

  const _TvRankingDialog({required this.report, required this.leadersByCode});

  @override
  Widget build(BuildContext context) {
    final players = [...report.players]
      ..sort((a, b) => a.ranking.compareTo(b.ranking));
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF02070A),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.4,
            colors: [Color(0xFF173B46), Color(0xFF07161C), Color(0xFF02070A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFF231300),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CLASSIFICACAO FINAL • STOP TCG',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _gold,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                          ),
                          Text(
                            report.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(report.eventDate)} • ${report.participantCount} jogadores • ${report.effectiveRoundCount} rodadas',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Use F11 para preencher a TV',
                      style: TextStyle(color: _cream),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Fechar modo TV',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100 ? 2 : 1;
                      final rows = (players.length / columns).ceil();
                      final available =
                          constraints.maxHeight - ((rows - 1) * 10);
                      final tileHeight = (available / rows).clamp(76.0, 126.0);
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 10,
                          mainAxisExtent: tileHeight,
                        ),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          final leader =
                              leadersByCode[player.leaderCode
                                  .trim()
                                  .toUpperCase()];
                          return _TvPlayerTile(player: player, leader: leader);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvPlayerTile extends StatelessWidget {
  final OnePieceStandingPlayer player;
  final WeeklyLeaderOption? leader;

  const _TvPlayerTile({required this.player, required this.leader});

  @override
  Widget build(BuildContext context) {
    final accent = switch (player.ranking) {
      1 => _gold,
      2 => const Color(0xFFC7CDD4),
      3 => const Color(0xFFB87333),
      _ => _cream.withValues(alpha: 0.7),
    };
    final leaderName = leader?.name.trim().isNotEmpty == true
        ? leader!.name
        : player.leaderName.trim();
    final leaderCode = leader?.code.trim().isNotEmpty == true
        ? leader!.code
        : player.leaderCode.trim();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xE6102027),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            alignment: Alignment.center,
            color: accent.withValues(alpha: 0.12),
            child: Text(
              '${player.ranking}º',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  leaderName.isEmpty
                      ? 'Lider nao informado'
                      : '$leaderName${leaderCode.isEmpty ? '' : ' • $leaderCode'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: leaderName.isEmpty
                        ? _cream.withValues(alpha: 0.5)
                        : _cream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.winPoints}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('PONTOS', style: TextStyle(letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 66,
            child: _LeaderArtwork(imageUrl: leader?.image ?? '', compact: true),
          ),
        ],
      ),
    );
  }
}

class _LeaderArtwork extends StatelessWidget {
  final String imageUrl;
  final bool compact;

  const _LeaderArtwork({required this.imageUrl, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Colors.black.withValues(alpha: 0.24),
      child: Center(
        child: Icon(
          Icons.style_outlined,
          color: _gold.withValues(alpha: 0.65),
          size: compact ? 25 : 38,
        ),
      ),
    );
    if (imageUrl.trim().isEmpty) return fallback;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

class _TournamentReportDialog extends StatelessWidget {
  final OnePieceStandingsReport report;
  final VoidCallback onExport;

  const _TournamentReportDialog({required this.report, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1220),
        child: SizedBox(
          width: size.width * 0.94,
          height: size.height * 0.9,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _ruby.withValues(alpha: 0.42),
                      const Color(0xFF0A1A20),
                      _gold.withValues(alpha: 0.18),
                    ],
                  ),
                  border: const Border(
                    bottom: BorderSide(color: _gold, width: 2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, color: _gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERGAMINHO OFICIAL • BANDAI TCG+',
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            report.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar pergaminho',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: _StandingsReport(report: report, onExport: onExport),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingsReport extends StatelessWidget {
  final OnePieceStandingsReport report;
  final VoidCallback onExport;

  const _StandingsReport({required this.report, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final players = [...report.players]
      ..sort((a, b) => a.ranking.compareTo(b.ranking));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Classificacao final',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Chip(
                  label: Text(
                    DateFormat('dd/MM/yyyy').format(report.eventDate),
                  ),
                ),
                Chip(label: Text('${report.participantCount} jogadores')),
                Chip(
                  avatar: const Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                  ),
                  label: Text('${report.highestWinPoints} pontos do lider'),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar relatorio'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Pos.')),
                  DataColumn(label: Text('Jogador')),
                  DataColumn(label: Text('Bandai ID')),
                  DataColumn(label: Text('Pontos')),
                  DataColumn(label: Text('OMW %')),
                  DataColumn(label: Text('OOMW %')),
                ],
                rows: [
                  for (final player in players)
                    DataRow(
                      cells: [
                        DataCell(_Placement(value: player.ranking)),
                        DataCell(
                          Text(
                            player.userName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        DataCell(SelectableText(player.membershipNumber)),
                        DataCell(Text('${player.winPoints}')),
                        DataCell(
                          Text('${player.omwPercentage.toStringAsFixed(1)}%'),
                        ),
                        DataCell(
                          Text('${player.oomwPercentage.toStringAsFixed(1)}%'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fonte: ${report.sourceFileName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _cream.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placement extends StatelessWidget {
  final int value;
  const _Placement({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      1 => _gold,
      2 => const Color(0xFFC7CDD4),
      3 => const Color(0xFFB87333),
      _ => _cream,
    };
    return Text(
      '$valueº',
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}

class _ImportDetailsDialog extends StatefulWidget {
  final OnePieceStandingsReport report;
  final List<WeeklyLeaderOption> leaders;
  final Map<String, WeeklyLeaderOption> leaderHints;

  const _ImportDetailsDialog({
    required this.report,
    required this.leaders,
    required this.leaderHints,
  });

  @override
  State<_ImportDetailsDialog> createState() => _ImportDetailsDialogState();
}

class _ImportDetailsDialogState extends State<_ImportDetailsDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _roundController;
  late final Map<String, WeeklyLeaderOption> _selectedLeaders;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.report.eventName);
    _roundController = TextEditingController(
      text: '${widget.report.effectiveRoundCount}',
    );
    _selectedLeaders = {};
    for (final player in widget.report.players) {
      final hint = widget.leaderHints[_playerKey(player)];
      if (hint != null) _selectedLeaders[_playerKey(player)] = hint;
    }
    _date = widget.report.eventDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar semanal One Piece'),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.report.participantCount} jogadores encontrados no CSV.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do torneio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roundController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade de rodadas',
                helperText:
                    'Valor inferido pelo arquivo. Corrija se o torneio teve outra quantidade.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _date = date);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                'Data do torneio: ${DateFormat('dd/MM/yyyy').format(_date)}',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'O CSV nao informa a data do evento; confirme-a antes de salvar.',
            ),
            const SizedBox(height: 18),
            Text(
              'Lider usado por jogador (opcional)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'O ultimo lider identificado para o mesmo Bandai ID e sugerido automaticamente.',
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: ListView.separated(
                itemCount: widget.report.players.length,
                separatorBuilder: (_, _) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final player = widget.report.players[index];
                  final key = _playerKey(player);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${player.ranking}º  ${player.userName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LeaderSelectionField(
                          leaders: widget.leaders,
                          initial: _selectedLeaders[key],
                          onChanged: (leader) {
                            if (leader == null) {
                              _selectedLeaders.remove(key);
                            } else {
                              _selectedLeaders[key] = leader;
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final rounds = int.tryParse(_roundController.text.trim());
            if (name.isEmpty || rounds == null || rounds <= 0) return;
            final players = widget.report.players
                .map((player) {
                  final leader = _selectedLeaders[_playerKey(player)];
                  return player.copyWith(
                    leaderCode: leader?.code ?? '',
                    leaderName: leader?.name ?? '',
                  );
                })
                .toList(growable: false);
            Navigator.pop(
              context,
              widget.report.copyWith(
                eventName: name,
                eventDate: _date,
                roundCount: rounds,
                players: players,
              ),
            );
          },
          child: const Text('Importar'),
        ),
      ],
    );
  }
}

class _LeaderSelectionField extends StatefulWidget {
  final List<WeeklyLeaderOption> leaders;
  final WeeklyLeaderOption? initial;
  final ValueChanged<WeeklyLeaderOption?> onChanged;

  const _LeaderSelectionField({
    required this.leaders,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_LeaderSelectionField> createState() => _LeaderSelectionFieldState();
}

class _LeaderSelectionFieldState extends State<_LeaderSelectionField> {
  WeeklyLeaderOption? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selected = widget.leaders
          .where(
            (leader) => leader.code.toUpperCase() == initial.code.toUpperCase(),
          )
          .firstOrNull;
      _selected ??= initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _LeaderArtwork(imageUrl: selected?.image ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected?.name ?? 'Nenhum lider selecionado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  selected?.code ?? 'Escolha pela imagem e pelo codigo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (selected != null)
            IconButton(
              tooltip: 'Remover lider',
              onPressed: () {
                setState(() => _selected = null);
                widget.onChanged(null);
              },
              icon: const Icon(Icons.close),
            ),
          FilledButton.tonalIcon(
            onPressed: widget.leaders.isEmpty ? null : _openPicker,
            icon: const Icon(Icons.style_outlined),
            label: const Text('Escolher'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPicker() async {
    final selected = await showDialog<WeeklyLeaderOption>(
      context: context,
      builder: (context) =>
          _LeaderPickerDialog(leaders: widget.leaders, selected: _selected),
    );
    if (selected == null || !mounted) return;
    setState(() => _selected = selected);
    widget.onChanged(selected);
  }
}

class _LeaderPickerDialog extends StatefulWidget {
  final List<WeeklyLeaderOption> leaders;
  final WeeklyLeaderOption? selected;

  const _LeaderPickerDialog({required this.leaders, required this.selected});

  @override
  State<_LeaderPickerDialog> createState() => _LeaderPickerDialogState();
}

class _LeaderPickerDialogState extends State<_LeaderPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.leaders
        : widget.leaders
              .where(
                (leader) =>
                    leader.name.toLowerCase().contains(query) ||
                    leader.code.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width.clamp(320, 1080),
        height: size.height * 0.9,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A20),
                border: Border(
                  bottom: BorderSide(color: _gold.withValues(alpha: 0.55)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.style_outlined, color: _gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escolher lider',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          'Confira a imagem e o codigo para evitar lideres com nomes iguais.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: 'Pesquisar por nome ou codigo',
                  prefixIcon: const Icon(Icons.search),
                  suffixText: '${filtered.length} lideres',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhum lider encontrado.'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisExtent: 292,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final leader = filtered[index];
                        final isSelected = widget.selected?.code == leader.code;
                        return InkWell(
                          onTap: () => Navigator.pop(context, leader),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _gold.withValues(alpha: 0.13)
                                  : Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? _gold
                                    : _gold.withValues(alpha: 0.28),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: _LeaderArtwork(
                                      imageUrl: leader.image,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  leader.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  leader.code,
                                  style: const TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
