import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_error_reporter.dart';
import '../../core/widgets/async_load_error_view.dart';
import '../../data/models/pokemon_tdf_report.dart';
import '../../data/repositories/pokemon_tournament_report_repository.dart';
import '../../data/services/pokemon_report_exporter.dart';
import '../../data/services/pokemon_tdf_parser.dart';
import '../../data/services/pokemon_tdf_validator.dart';
import '../../data/services/pokemon_weekly_circuit.dart';
import '../../data/services/tdf_file_picker.dart';

const _pokemonBlue = Color(0xFF2A75BB);
const _pokemonDeepBlue = Color(0xFF163B73);
const _pokemonYellow = Color(0xFFFFCB05);
const _pokemonRed = Color(0xFFE3350D);
const _pokemonInk = Color(0xFF071426);
const _pokemonPanel = Color(0xFF102A49);
const _pokemonCream = Color(0xFFFFF7D6);

Color _circuitAccent(PokemonWeeklyCircuit circuit) => switch (circuit) {
  PokemonWeeklyCircuit.thursday => const Color(0xFF35A7FF),
  PokemonWeeklyCircuit.saturday => _pokemonRed,
  PokemonWeeklyCircuit.metaNaoPode => const Color(0xFF77C043),
  PokemonWeeklyCircuit.glc => const Color(0xFFFF9F1C),
  PokemonWeeklyCircuit.other => const Color(0xFF9B7EDE),
};

IconData _circuitIcon(PokemonWeeklyCircuit circuit) => switch (circuit) {
  PokemonWeeklyCircuit.thursday => Icons.calendar_view_week,
  PokemonWeeklyCircuit.saturday => Icons.weekend_outlined,
  PokemonWeeklyCircuit.metaNaoPode => Icons.block_outlined,
  PokemonWeeklyCircuit.glc => Icons.shield_outlined,
  PokemonWeeklyCircuit.other => Icons.event_repeat_outlined,
};

ThemeData _pokemonWeeklyTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: _pokemonInk,
    colorScheme: const ColorScheme.dark(
      primary: _pokemonYellow,
      onPrimary: Color(0xFF211A00),
      secondary: _pokemonBlue,
      onSecondary: Colors.white,
      tertiary: _pokemonRed,
      surface: _pokemonPanel,
      onSurface: _pokemonCream,
      surfaceContainerHighest: Color(0xFF17395F),
      onSurfaceVariant: Color(0xFFD5E7FF),
      outline: Color(0xFF5279A6),
      error: Color(0xFFFF8A80),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF071426),
      foregroundColor: _pokemonCream,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: _pokemonPanel.withValues(alpha: 0.95),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _pokemonBlue.withValues(alpha: 0.6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _pokemonYellow,
        foregroundColor: const Color(0xFF211A00),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: _pokemonDeepBlue,
      labelStyle: const TextStyle(color: _pokemonCream),
      side: BorderSide(color: _pokemonBlue.withValues(alpha: 0.7)),
    ),
  );
}

class PokemonWeeklyReportScreen extends ConsumerStatefulWidget {
  const PokemonWeeklyReportScreen({super.key});

  @override
  ConsumerState<PokemonWeeklyReportScreen> createState() =>
      _PokemonWeeklyReportScreenState();
}

class _PokemonWeeklyReportScreenState
    extends ConsumerState<PokemonWeeklyReportScreen> {
  static const _parser = PokemonTdfParser();
  static const _validator = PokemonTdfValidator();
  late Future<List<StoredPokemonTournamentReport>> _future;
  String? _importStatus;
  PokemonWeeklyCircuit? _selectedCircuit;

  bool get _importing => _importStatus != null;

  PokemonTournamentReportRepository get _repository =>
      ref.read(pokemonTournamentReportRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _loadReports();
  }

  Future<List<StoredPokemonTournamentReport>> _loadReports() async {
    try {
      return await _repository.loadReports();
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.load-reports',
      );
      throw _PokemonWeeklyLoadException(referenceId);
    }
  }

  void _reload() {
    setState(() => _future = _loadReports());
  }

  Future<void> _importTdf() async {
    setState(() => _importStatus = 'Abrindo arquivo...');
    try {
      final file = await pickTdfFile();
      if (!mounted) return;
      if (file == null) {
        _showMessage('Nenhum arquivo foi selecionado.');
        return;
      }

      if (!isPokemonTdfFileName(file.name)) {
        _showMessage('Selecione um arquivo de torneio com extensao .tdf.');
        return;
      }
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        _showMessage('Nao foi possivel ler o conteudo do arquivo selecionado.');
        return;
      }

      setState(() => _importStatus = 'Lendo TDF...');
      final report = _parser.parseBytes(bytes, fileName: file.name);
      if (!mounted) return;
      setState(() => _importStatus = 'Validando torneio...');
      final validation = _validator.validate(report);
      final existing = await _repository.findBySourceKey(report.sourceKey);
      if (!mounted) return;
      final selectedCircuit = await showDialog<PokemonWeeklyCircuit>(
        context: context,
        builder: (context) => _ImportConfirmationDialog(
          report: report,
          validation: validation,
          existing: existing,
        ),
      );
      if (selectedCircuit == null) return;
      setState(
        () => _importStatus = existing == null
            ? 'Salvando relatorio...'
            : 'Substituindo relatorio...',
      );
      await _repository.saveReport(report, circuit: selectedCircuit);
      if (!mounted) return;
      setState(() {
        _selectedCircuit = selectedCircuit;
        _future = _loadReports();
      });
      _showMessage(
        existing == null
            ? 'Relatorio importado com sucesso.'
            : 'Relatorio existente substituido com sucesso.',
      );
      _openReport(report, circuit: selectedCircuit);
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.import-tdf',
      );
      _showMessage(
        'Nao foi possivel importar o TDF. Codigo do erro: $referenceId',
      );
    } finally {
      if (mounted) setState(() => _importStatus = null);
    }
  }

  Future<void> _delete(StoredPokemonTournamentReport stored) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir relatorio?'),
        content: Text(
          'O relatorio de ${stored.report.name} sera removido do historico.',
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
      final audit = await _repository.latestDeleteAudit(stored.id);
      if (!mounted) return;
      _reload();
      if (audit == null) {
        _showMessage('Relatorio excluido.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Relatorio excluido.'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () => _restoreAudit(audit.id),
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.delete-report',
      );
      _showMessage(
        'Nao foi possivel excluir o relatorio. Codigo do erro: $referenceId',
      );
    }
  }

  Future<void> _restoreAudit(int auditId) async {
    try {
      await _repository.restoreAudit(auditId);
      if (!mounted) return;
      _reload();
      _showMessage('Versao restaurada com sucesso.');
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.restore-audit',
      );
      _showMessage(
        'Nao foi possivel restaurar a versao. Codigo do erro: $referenceId',
      );
    }
  }

  Future<void> _openAudit() async {
    final restored = await showDialog<bool>(
      context: context,
      builder: (context) => _PokemonReportAuditDialog(repository: _repository),
    );
    if (restored == true && mounted) {
      _reload();
      _showMessage('Versao restaurada com sucesso.');
    }
  }

  Future<void> _exportReport(PokemonTournamentReport report) async {
    try {
      await exportPokemonReportCsv(report);
      if (!mounted) return;
      _showMessage('Relatorio CSV gerado com sucesso.');
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.export-csv',
      );
      _showMessage(
        'Nao foi possivel exportar o CSV. Codigo do erro: $referenceId',
      );
    }
  }

  Future<void> _exportCircuit(
    PokemonWeeklyCircuit circuit,
    List<StoredPokemonTournamentReport> reports,
  ) async {
    try {
      await exportPokemonCircuitRankingCsv(
        circuit: circuit,
        reports: reports.map((item) => item.report).toList(growable: false),
      );
      if (!mounted) return;
      _showMessage('Ranking de ${circuit.label} exportado com sucesso.');
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.export-circuit-ranking',
      );
      _showMessage(
        'Nao foi possivel exportar o ranking. Codigo do erro: $referenceId',
      );
    }
  }

  void _openReport(
    PokemonTournamentReport report, {
    required PokemonWeeklyCircuit circuit,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: _pokemonWeeklyTheme(),
        child: _TournamentReportDialog(
          circuit: circuit,
          report: report,
          onExport: () => _exportReport(report),
        ),
      ),
    );
  }

  void _openTvRanking(
    PokemonTournamentReport report, {
    required PokemonWeeklyCircuit circuit,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Theme(
        data: _pokemonWeeklyTheme(),
        child: _PokemonTvRankingDialog(circuit: circuit, report: report),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _repository.isAdmin;
    return Theme(
      data: _pokemonWeeklyTheme(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar aos semanais',
            onPressed: () => context.go('/weeklies'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.catching_pokemon, color: _pokemonYellow),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  MediaQuery.sizeOf(context).width < 600
                      ? 'Semanal Pokemon'
                      : 'STOP TCG - Semanal Pokemon',
                ),
              ),
            ],
          ),
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Auditoria dos relatorios',
                onPressed: _openAudit,
                icon: const Icon(Icons.history),
              ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _importing ? null : _importTdf,
                  icon: _importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_importStatus ?? 'Importar TDF'),
                ),
              ),
          ],
        ),
        body: _PokemonBackdrop(
          child: FutureBuilder<List<StoredPokemonTournamentReport>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return AsyncLoadErrorView(
                  title: 'Nao foi possivel carregar os relatorios',
                  message:
                      'Verifique sua conexao e tente novamente. Se o problema '
                      'continuar, informe o codigo abaixo ao suporte.',
                  referenceId: error is _PokemonWeeklyLoadException
                      ? error.referenceId
                      : null,
                  onRetry: _reload,
                );
              }
              final storedReports = snapshot.data ?? const [];
              final reportsByCircuit = {
                for (final value in PokemonWeeklyCircuit.values)
                  value: storedReports
                      .where((item) => item.circuit == value)
                      .toList(growable: false),
              };
              final hasThursday =
                  reportsByCircuit[PokemonWeeklyCircuit.thursday]!.isNotEmpty;
              final hasSaturday =
                  reportsByCircuit[PokemonWeeklyCircuit.saturday]!.isNotEmpty;
              final hasMetaNaoPode =
                  reportsByCircuit[PokemonWeeklyCircuit.metaNaoPode]!
                      .isNotEmpty;
              final hasGlc =
                  reportsByCircuit[PokemonWeeklyCircuit.glc]!.isNotEmpty;
              final hasOther =
                  reportsByCircuit[PokemonWeeklyCircuit.other]!.isNotEmpty;
              final circuit =
                  _selectedCircuit ??
                  (hasThursday
                      ? PokemonWeeklyCircuit.thursday
                      : hasSaturday
                      ? PokemonWeeklyCircuit.saturday
                      : hasMetaNaoPode
                      ? PokemonWeeklyCircuit.metaNaoPode
                      : hasGlc
                      ? PokemonWeeklyCircuit.glc
                      : hasOther
                      ? PokemonWeeklyCircuit.other
                      : PokemonWeeklyCircuit.thursday);
              final circuitReports = reportsByCircuit[circuit]!;
              final latestReport = circuitReports.firstOrNull?.report;
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PokemonHero(
                              reportCount: circuitReports.length,
                              latestReport: latestReport,
                              circuit: circuit,
                              canImport: isAdmin,
                              onImport: _importing ? null : _importTdf,
                            ),
                            const SizedBox(height: 18),
                            _CircuitSelector(
                              selected: circuit,
                              showOther: hasOther,
                              counts: {
                                for (final entry in reportsByCircuit.entries)
                                  entry.key: entry.value.length,
                              },
                              onSelected: (value) => setState(() {
                                _selectedCircuit = value;
                              }),
                            ),
                            if (circuitReports.isNotEmpty)
                              const SizedBox(height: 18),
                            if (circuitReports.isNotEmpty)
                              _ReportHistory(
                                circuit: circuit,
                                reports: circuitReports,
                                isAdmin: isAdmin,
                                onView: (item) =>
                                    _openReport(item.report, circuit: circuit),
                                onTv: (item) => _openTvRanking(
                                  item.report,
                                  circuit: circuit,
                                ),
                                onDelete: _delete,
                              ),
                            if (circuitReports.isNotEmpty)
                              const SizedBox(height: 18),
                            if (circuitReports.isNotEmpty)
                              _CircuitRankingPanel(
                                circuit: circuit,
                                reports: circuitReports,
                                onExport: () =>
                                    _exportCircuit(circuit, circuitReports),
                              ),
                            if (circuitReports.isEmpty)
                              _EmptyReport(
                                circuit: circuit,
                                canImport: isAdmin,
                                onImport: _importTdf,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PokemonBackdrop extends StatelessWidget {
  final Widget child;

  const _PokemonBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.8),
          radius: 1.4,
          colors: [Color(0xFF24558A), _pokemonInk, Color(0xFF030914)],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PokemonGridPainter())),
          child,
        ],
      ),
    );
  }
}

class _PokemonGridPainter extends CustomPainter {
  const _PokemonGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pokemonYellow.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 64.0;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 15, paint);
        canvas.drawLine(Offset(x - 15, y), Offset(x + 15, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PokemonHero extends StatelessWidget {
  final int reportCount;
  final PokemonTournamentReport? latestReport;
  final PokemonWeeklyCircuit circuit;
  final bool canImport;
  final VoidCallback? onImport;

  const _PokemonHero({
    required this.reportCount,
    required this.latestReport,
    required this.circuit,
    required this.canImport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _circuitAccent(circuit);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _pokemonDeepBlue.withValues(alpha: 0.96),
            accent.withValues(alpha: 0.48),
            accent.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _pokemonYellow.withValues(alpha: 0.72),
          width: 2,
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _pokemonYellow, width: 5),
            ),
            child: const Icon(
              Icons.catching_pokemon,
              color: _pokemonRed,
              size: 58,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIGA INDEPENDENTE • ${circuit.label.toUpperCase()}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _pokemonYellow,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Semanal de ${circuit.label}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Historico, ranking, classificacao final e pontuacao exclusivos deste semanal.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _pokemonCream,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('$reportCount torneios no historico')),
                    Chip(
                      avatar: Icon(_circuitIcon(circuit), size: 18),
                      label: const Text('Pontuacao independente'),
                    ),
                    if (latestReport != null)
                      Chip(
                        label: Text(
                          '${latestReport!.participantCount} jogadores no ultimo',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canImport)
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Importar resultado'),
            ),
        ],
      ),
    );
  }
}

class _CircuitSelector extends StatelessWidget {
  final PokemonWeeklyCircuit selected;
  final bool showOther;
  final Map<PokemonWeeklyCircuit, int> counts;
  final ValueChanged<PokemonWeeklyCircuit> onSelected;

  const _CircuitSelector({
    required this.selected,
    required this.showOther,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quatro semanais, quatro ligas separadas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _pokemonYellow,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Quinta, sábado, MetaNãoPode e GLC possuem rankings próprios. Mesmo os dois eventos de domingo nunca misturam resultados ou pontos.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final circuit in const [
                      PokemonWeeklyCircuit.thursday,
                      PokemonWeeklyCircuit.saturday,
                      PokemonWeeklyCircuit.metaNaoPode,
                      PokemonWeeklyCircuit.glc,
                    ])
                      SizedBox(
                        width: cardWidth,
                        child: _CircuitLeagueCard(
                          circuit: circuit,
                          tournamentCount: counts[circuit] ?? 0,
                          selected: selected == circuit,
                          onTap: () => onSelected(circuit),
                        ),
                      ),
                    if (showOther)
                      ActionChip(
                        avatar: Icon(_circuitIcon(PokemonWeeklyCircuit.other)),
                        label: Text(
                          'Eventos especiais • ${counts[PokemonWeeklyCircuit.other] ?? 0} torneios',
                        ),
                        onPressed: () => onSelected(PokemonWeeklyCircuit.other),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CircuitLeagueCard extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final int tournamentCount;
  final bool selected;
  final VoidCallback onTap;

  const _CircuitLeagueCard({
    required this.circuit,
    required this.tournamentCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _circuitAccent(circuit);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: selected ? 0.42 : 0.17),
                _pokemonDeepBlue.withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _pokemonYellow : accent,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: accent,
                foregroundColor: Colors.white,
                child: Icon(_circuitIcon(circuit), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LIGA DE ${circuit.label.toUpperCase()}',
                      style: TextStyle(
                        color: selected ? _pokemonYellow : accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$tournamentCount torneios',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(circuit.schedule),
                    const SizedBox(height: 4),
                    const Text('Ranking • classificacao • exportacao proprios'),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.arrow_forward_ios_rounded,
                color: selected ? _pokemonYellow : accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircuitRankingPanel extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final List<StoredPokemonTournamentReport> reports;
  final VoidCallback onExport;

  const _CircuitRankingPanel({
    required this.circuit,
    required this.reports,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _circuitAccent(circuit);
    final ranking = buildPokemonCircuitRanking(
      reports.map((item) => item.report),
    );
    return Card(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranking exclusivo • Liga de ${circuit.label}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${reports.length} torneios contabilizados. '
                        'Cada vitoria vale 3 pontos e cada empate vale 1 ponto. '
                        'Nenhum resultado do outro semanal entra neste ranking.',
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: Text('Exportar ranking de ${circuit.label}'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CircuitRankingTable(entries: ranking),
          ],
        ),
      ),
    );
  }
}

class _CircuitRankingTable extends StatelessWidget {
  final List<PokemonCircuitRankingEntry> entries;

  const _CircuitRankingTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Pos.')),
          DataColumn(label: Text('Jogador')),
          DataColumn(label: Text('Torneios')),
          DataColumn(label: Text('V')),
          DataColumn(label: Text('E')),
          DataColumn(label: Text('D')),
          DataColumn(label: Text('Pts.')),
          DataColumn(label: Text('Melhor')),
        ],
        rows: [
          for (final indexed in entries.indexed)
            DataRow(
              cells: [
                DataCell(Text('${indexed.$1 + 1}º')),
                DataCell(
                  _PlayerNameWithCategory(
                    name: indexed.$2.name,
                    category: indexed.$2.category,
                  ),
                ),
                DataCell(Text('${indexed.$2.tournaments}')),
                DataCell(Text('${indexed.$2.wins}')),
                DataCell(Text('${indexed.$2.draws}')),
                DataCell(Text('${indexed.$2.losses}')),
                DataCell(
                  Text(
                    '${indexed.$2.matchPoints}',
                    style: const TextStyle(
                      color: _pokemonYellow,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    indexed.$2.bestPlacement == null
                        ? '-'
                        : '${indexed.$2.bestPlacement}º',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReportHistory extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final List<StoredPokemonTournamentReport> reports;
  final bool isAdmin;
  final ValueChanged<StoredPokemonTournamentReport> onView;
  final ValueChanged<StoredPokemonTournamentReport> onTv;
  final ValueChanged<StoredPokemonTournamentReport> onDelete;

  const _ReportHistory({
    required this.circuit,
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
              'Historico exclusivo • Liga de ${circuit.label}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _pokemonYellow,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: reports.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = reports[index];
                  return InkWell(
                    onTap: () => onView(item),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _circuitAccent(circuit)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.catching_pokemon,
                            color: _pokemonYellow,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.report.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${_date(item.report.eventDate)} • ${item.report.participantCount} jogadores',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Arquivo: ${item.report.sourceFileName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Atualizado ${_dateTime(item.updatedAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => onTv(item),
                                      icon: const Icon(
                                        Icons.tv_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Modo TV'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => onView(item),
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
                              onPressed: () => onDelete(item),
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

class _PokemonTvRankingDialog extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentReport report;

  const _PokemonTvRankingDialog({required this.circuit, required this.report});

  @override
  Widget build(BuildContext context) {
    final players = sortPokemonUnifiedStandings(report.players);
    final accent = _circuitAccent(circuit);
    return Dialog.fullscreen(
      backgroundColor: _pokemonInk,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.75, -0.8),
            radius: 1.45,
            colors: [
              accent.withValues(alpha: 0.26),
              _pokemonDeepBlue,
              _pokemonInk,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PokemonTvHeader(
                  circuit: circuit,
                  report: report,
                  accent: accent,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: players.isEmpty
                      ? const Center(
                          child: Text('Nenhum jogador neste semanal.'),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = switch ((
                              constraints.maxWidth,
                              players.length,
                            )) {
                              (>= 1700, > 36) => 4,
                              (>= 1700, > 24) => 3,
                              (>= 1100, _) => 2,
                              _ => 1,
                            };
                            final rows = (players.length / columns).ceil();
                            final available =
                                constraints.maxHeight - ((rows - 1) * 10);
                            final tileHeight = (available / rows).clamp(
                              64.0,
                              126.0,
                            );
                            return GridView.builder(
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 10,
                                    mainAxisExtent: tileHeight,
                                  ),
                              itemCount: players.length,
                              itemBuilder: (context, index) =>
                                  _PokemonTvPlayerTile(
                                    circuit: circuit,
                                    player: players[index],
                                    ranking: index + 1,
                                  ),
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

class _PokemonTvHeader extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentReport report;
  final Color accent;

  const _PokemonTvHeader({
    required this.circuit,
    required this.report,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: _pokemonYellow,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: const Icon(
            Icons.catching_pokemon,
            color: _pokemonRed,
            size: 38,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLASSIFICACAO FINAL • LIGA DE ${circuit.label.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                report.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${_date(report.eventDate)} • ${report.participantCount} jogadores • ${report.roundCount} rodadas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (MediaQuery.sizeOf(context).width >= 900)
          const Text(
            'Use F11 para preencher a TV',
            style: TextStyle(color: _pokemonCream),
          ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Fechar modo TV Pokemon',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _PokemonTvPlayerTile extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentPlayer player;
  final int ranking;

  const _PokemonTvPlayerTile({
    required this.circuit,
    required this.player,
    required this.ranking,
  });

  @override
  Widget build(BuildContext context) {
    final accent = switch (ranking) {
      1 => _pokemonYellow,
      2 => const Color(0xFFC7CDD4),
      3 => const Color(0xFFCD7F32),
      _ => _circuitAccent(circuit),
    };
    final categoryColor = switch (player.category) {
      0 => const Color(0xFF30D67A),
      1 => _pokemonYellow,
      _ => const Color(0xFF75B8FF),
    };
    final bye = player.byes == 0 ? '' : ' • ${player.byes} BYE';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _pokemonPanel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: ranking <= 3 ? 0.12 : 0.05),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            alignment: Alignment.center,
            color: accent.withValues(alpha: 0.13),
            child: Text(
              '$rankingº',
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
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.72),
                        ),
                      ),
                      child: Text(
                        player.categoryLabel,
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '${player.wins}V • ${player.draws}E • ${player.losses}D$bye',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pokemonCream.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
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
                '${player.matchPoints}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _pokemonYellow,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('PONTOS', style: TextStyle(letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _TournamentReportDialog extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentReport report;
  final VoidCallback onExport;

  const _TournamentReportDialog({
    required this.circuit,
    required this.report,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final accent = _circuitAccent(circuit);
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
                    colors: [accent.withValues(alpha: 0.42), _pokemonDeepBlue],
                  ),
                  border: Border(bottom: BorderSide(color: accent, width: 2)),
                ),
                child: Row(
                  children: [
                    Icon(_circuitIcon(circuit), color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARQUIVO DO SEMANAL • ${circuit.label.toUpperCase()}',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            report.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar arquivo',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: _TournamentReportView(
                    circuit: circuit,
                    report: report,
                    onExport: onExport,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TournamentReportView extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentReport report;
  final VoidCallback onExport;

  const _TournamentReportView({
    required this.circuit,
    required this.report,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = sortPokemonUnifiedStandings(report.players);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportHeader(circuit: circuit, report: report, onExport: onExport),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(
              label: 'Jogadores',
              value: '${report.participantCount}',
              icon: Icons.groups_outlined,
            ),
            _Metric(
              label: 'Rodadas',
              value: '${report.roundCount}',
              icon: Icons.repeat_rounded,
            ),
            _Metric(
              label: 'Partidas',
              value: '${report.matchCount}',
              icon: Icons.sports_esports_outlined,
            ),
            _Metric(
              label: 'Drops',
              value: '${report.dropCount}',
              icon: Icons.person_remove_outlined,
            ),
            _Metric(
              label: 'Tempo de rodada',
              value: '${report.roundTimeMinutes} min',
              icon: Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _StandingsTable(circuit: circuit, players: sortedPlayers),
        const SizedBox(height: 14),
        _RoundsPanel(report: report),
        const SizedBox(height: 12),
        Text(
          'Privacidade: datas de nascimento existentes no TDF nao sao importadas nem exibidas.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _pokemonCream.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _ReportHeader extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final PokemonTournamentReport report;
  final VoidCallback onExport;

  const _ReportHeader({
    required this.circuit,
    required this.report,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _circuitAccent(circuit);
    final location = [
      report.city,
      report.state.toUpperCase(),
    ].where((part) => part.isNotEmpty).join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 30,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESULTADO EXCLUSIVO • LIGA DE ${circuit.label.toUpperCase()}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      _date(report.eventDate),
                      if (location.isNotEmpty) location,
                      if (report.organizerName.isNotEmpty)
                        'Organizador: ${report.organizerName}',
                    ].join('  •  '),
                  ),
                ],
              ),
            ),
            Chip(label: Text('TDF ${report.softwareVersion}')),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar CSV'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 158),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: _pokemonDeepBlue.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _pokemonBlue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _pokemonYellow),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final List<PokemonTournamentPlayer> players;

  const _StandingsTable({required this.circuit, required this.players});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classificacao final • ${circuit.label}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _pokemonYellow,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Este resultado pertence somente a Liga de ${circuit.label}; nao altera o outro semanal.',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  _circuitAccent(circuit).withValues(alpha: 0.3),
                ),
                columns: const [
                  DataColumn(label: Text('Pos.')),
                  DataColumn(label: Text('Jogador')),
                  DataColumn(label: Text('V')),
                  DataColumn(label: Text('E')),
                  DataColumn(label: Text('D')),
                  DataColumn(label: Text('BYE')),
                  DataColumn(label: Text('Pts.')),
                  DataColumn(label: Text('Status')),
                ],
                rows: players.indexed
                    .map((indexed) {
                      final player = indexed.$2;
                      return DataRow(
                        cells: [
                          DataCell(Text('${indexed.$1 + 1}º')),
                          DataCell(
                            _PlayerNameWithCategory(
                              name: player.name,
                              category: player.category,
                            ),
                          ),
                          DataCell(Text('${player.wins}')),
                          DataCell(Text('${player.draws}')),
                          DataCell(Text('${player.losses}')),
                          DataCell(Text('${player.byes}')),
                          DataCell(Text('${player.matchPoints}')),
                          DataCell(
                            Text(
                              player.droppedRound == null
                                  ? 'Finalizou'
                                  : 'Drop R${player.droppedRound}',
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final int category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      0 => const Color(0xFF30D67A),
      1 => _pokemonYellow,
      _ => const Color(0xFF75B8FF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        pokemonCategoryLabel(category),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PlayerNameWithCategory extends StatelessWidget {
  final String name;
  final int category;

  const _PlayerNameWithCategory({required this.name, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CategoryBadge(category: category),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _RoundsPanel extends StatelessWidget {
  final PokemonTournamentReport report;

  const _RoundsPanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final names = {
      for (final player in report.players) player.playerId: player.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rodadas e confrontos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _pokemonYellow,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final round in report.rounds)
              ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: _pokemonRed,
                  foregroundColor: Colors.white,
                  child: Text('${round.number}'),
                ),
                title: Text(
                  'Rodada ${round.number}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('${round.matches.length} confrontos'),
                children: [
                  for (final match in round.matches)
                    ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 38,
                        child: Text(
                          match.tableNumber == null || match.tableNumber == 0
                              ? 'BYE'
                              : 'M${match.tableNumber}',
                        ),
                      ),
                      title: Text(_matchLabel(match, names)),
                      trailing: Text(
                        _outcomeLabel(match, names),
                        style: const TextStyle(
                          color: _pokemonYellow,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final PokemonWeeklyCircuit circuit;
  final bool canImport;
  final VoidCallback onImport;

  const _EmptyReport({
    required this.circuit,
    required this.canImport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            const Icon(Icons.catching_pokemon, color: _pokemonYellow, size: 64),
            const SizedBox(height: 14),
            Text(
              'Nenhum relatorio de ${circuit.label} importado',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              canImport
                  ? 'Selecione o arquivo .tdf deste circuito. A data do torneio determina automaticamente onde ele sera exibido.'
                  : 'Assim que a equipe da STOP TCG importar um TDF de ${circuit.label}, o resultado aparecera aqui.',
              textAlign: TextAlign.center,
            ),
            if (canImport) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Selecionar TDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportConfirmationDialog extends StatefulWidget {
  final PokemonTournamentReport report;
  final PokemonTdfValidationResult validation;
  final StoredPokemonTournamentReport? existing;

  const _ImportConfirmationDialog({
    required this.report,
    required this.validation,
    required this.existing,
  });

  @override
  State<_ImportConfirmationDialog> createState() =>
      _ImportConfirmationDialogState();
}

class _ImportConfirmationDialogState extends State<_ImportConfirmationDialog> {
  PokemonWeeklyCircuit? _circuit;

  PokemonTournamentReport get report => widget.report;
  PokemonTdfValidationResult get validation => widget.validation;
  StoredPokemonTournamentReport? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final inferred = pokemonCircuitForReport(report);
    _circuit =
        existing?.circuit ??
        (report.eventDate.weekday == DateTime.sunday &&
                inferred == PokemonWeeklyCircuit.other
            ? null
            : inferred);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        !validation.canImport
            ? 'TDF precisa de correcoes'
            : existing == null
            ? 'Confirmar relatorio TDF'
            : 'Substituir relatorio existente?',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text('Arquivo: ${report.sourceFileName}'),
              Text('Data: ${_date(report.eventDate)}'),
              const SizedBox(height: 14),
              DropdownButtonFormField<PokemonWeeklyCircuit>(
                initialValue: _circuit,
                decoration: const InputDecoration(
                  labelText: 'Ranking deste evento',
                  helperText:
                      'Confirme com atenção: MetaNãoPode e GLC acontecem no domingo.',
                  border: OutlineInputBorder(),
                ),
                items: PokemonWeeklyCircuit.values
                    .map(
                      (circuit) => DropdownMenuItem(
                        value: circuit,
                        child: Text('${circuit.label} • ${circuit.schedule}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() => _circuit = value);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${report.participantCount} jogadores')),
                  Chip(label: Text('${report.roundCount} rodadas')),
                  Chip(label: Text('${report.matchCount} partidas')),
                  Chip(label: Text('${report.completedMatchCount} concluidas')),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: 14),
                _ImportNotice(
                  icon: Icons.content_copy_outlined,
                  color: _pokemonYellow,
                  text:
                      'Este torneio ja esta no historico. A versao importada em '
                      '${_dateTime(existing!.importedAt)} sera substituida.',
                ),
              ],
              if (validation.issues.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final issue in validation.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ImportNotice(
                      icon: issue.severity == PokemonTdfIssueSeverity.error
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      color: issue.severity == PokemonTdfIssueSeverity.error
                          ? Theme.of(context).colorScheme.error
                          : _pokemonYellow,
                      text: issue.message,
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 14),
                const _ImportNotice(
                  icon: Icons.check_circle_outline,
                  color: Color(0xFF30D67A),
                  text: 'Nenhuma inconsistencia foi encontrada no arquivo.',
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'O nome, Player ID, classificacao, drops e resultados serao salvos. Datas de nascimento serao descartadas.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (validation.canImport)
          FilledButton(
            onPressed: _circuit == null
                ? null
                : () => Navigator.pop(context, _circuit),
            child: Text(existing == null ? 'Importar' : 'Substituir'),
          ),
      ],
    );
  }
}

class _ImportNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ImportNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PokemonWeeklyLoadException implements Exception {
  final String referenceId;

  const _PokemonWeeklyLoadException(this.referenceId);
}

class _PokemonReportAuditDialog extends StatefulWidget {
  final PokemonTournamentReportRepository repository;

  const _PokemonReportAuditDialog({required this.repository});

  @override
  State<_PokemonReportAuditDialog> createState() =>
      _PokemonReportAuditDialogState();
}

class _PokemonReportAuditDialogState extends State<_PokemonReportAuditDialog> {
  late Future<List<PokemonTournamentReportAuditEntry>> _future;
  int? _restoringId;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadAudit();
  }

  Future<void> _restore(PokemonTournamentReportAuditEntry entry) async {
    final report = entry.previousReport;
    if (report == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar esta versao?'),
        content: Text(
          'O relatorio "${report.name}" voltara ao estado registrado em '
          '${_dateTime(entry.changedAt)}. A versao atual sera preservada na '
          'auditoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _restoringId = entry.id);
    try {
      await widget.repository.restoreAudit(entry.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      final referenceId = AppErrorReporter.report(
        error,
        stackTrace,
        context: 'pokemon-weekly.audit-dialog-restore',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao restaurar. Codigo do erro: $referenceId'),
        ),
      );
      setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Auditoria dos relatorios Pokemon'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: FutureBuilder<List<PokemonTournamentReportAuditEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Nao foi possivel carregar a auditoria.'),
              );
            }
            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return const Center(
                child: Text('Nenhuma alteracao registrada ainda.'),
              );
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final report = entry.newReport ?? entry.previousReport;
                return ListTile(
                  leading: Icon(
                    _auditIcon(entry.action),
                    color: _pokemonYellow,
                  ),
                  title: Text(
                    report?.name ?? entry.sourceKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_auditActionLabel(entry.action)} em '
                    '${_dateTime(entry.changedAt)}\n'
                    '${report?.sourceFileName ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: entry.canRestore
                      ? IconButton(
                          tooltip: 'Restaurar esta versao',
                          onPressed: _restoringId == null
                              ? () => _restore(entry)
                              : null,
                          icon: _restoringId == entry.id
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore),
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

IconData _auditIcon(String action) => switch (action) {
  'insert' => Icons.add_circle_outline,
  'delete' => Icons.delete_outline,
  _ => Icons.edit_outlined,
};

String _auditActionLabel(String action) => switch (action) {
  'insert' => 'Importado',
  'delete' => 'Excluido',
  _ => 'Substituido',
};

String _date(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String _dateTime(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());

String _matchLabel(PokemonTournamentMatch match, Map<String, String> names) {
  final one = names[match.playerOneId] ?? match.playerOneId;
  if (match.isBye) return '$one recebeu BYE';
  final two = names[match.playerTwoId] ?? match.playerTwoId ?? '-';
  return '$one × $two';
}

String _outcomeLabel(PokemonTournamentMatch match, Map<String, String> names) {
  return switch (match.outcome) {
    'player_one' => 'Venceu ${names[match.playerOneId] ?? match.playerOneId}',
    'player_two' => 'Venceu ${names[match.playerTwoId] ?? match.playerTwoId}',
    'draw' => 'Empate',
    'bye' => 'Vitoria automatica',
    _ => 'Sem resultado',
  };
}
