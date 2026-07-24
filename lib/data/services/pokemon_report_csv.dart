import '../models/pokemon_tdf_report.dart';
import 'pokemon_weekly_circuit.dart';

String buildPokemonReportCsv(PokemonTournamentReport report) {
  final rows = <List<Object?>>[
    ['Relatorio Pokemon TCG - STOP TCG'],
    ['Torneio', report.name],
    ['Data', _dateOnly(report.eventDate)],
    [
      'Local',
      [report.city, report.state].where((v) => v.isNotEmpty).join(' - '),
    ],
    ['Organizador', report.organizerName],
    ['Arquivo TDF', report.sourceFileName],
    ['Participantes', report.participantCount],
    ['Rodadas', report.roundCount],
    ['Partidas', report.matchCount],
    [],
    ['CLASSIFICACAO'],
    [
      'Posicao',
      'Jogador',
      'Player ID',
      'Categoria',
      'Vitorias',
      'Empates',
      'Derrotas',
      'Byes',
      'Pontos',
      'Status',
    ],
    for (final indexed in _sortedPlayers(report.players).indexed)
      [
        indexed.$1 + 1,
        indexed.$2.name,
        indexed.$2.playerId,
        indexed.$2.categoryLabel,
        indexed.$2.wins,
        indexed.$2.draws,
        indexed.$2.losses,
        indexed.$2.byes,
        indexed.$2.matchPoints,
        indexed.$2.droppedRound == null
            ? 'Finalizou'
            : 'Drop R${indexed.$2.droppedRound}',
      ],
    [],
    ['RODADAS'],
    ['Rodada', 'Mesa', 'Jogador 1', 'Jogador 2', 'Resultado'],
    for (final round in report.rounds)
      for (final match in round.matches)
        [
          round.number,
          match.tableNumber == null || match.tableNumber == 0
              ? 'BYE'
              : match.tableNumber,
          _playerName(report, match.playerOneId),
          match.playerTwoId == null
              ? ''
              : _playerName(report, match.playerTwoId!),
          _outcomeLabel(match, report),
        ],
  ];

  return '\uFEFF${rows.map(_csvRow).join('\r\n')}\r\n';
}

String pokemonReportCsvFileName(PokemonTournamentReport report) {
  final base = report.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final date = _dateOnly(report.eventDate).replaceAll('-', '');
  return '${date}_${base.isEmpty ? 'torneio-pokemon' : base}.csv';
}

String buildPokemonCircuitRankingCsv({
  required PokemonWeeklyCircuit circuit,
  required List<PokemonTournamentReport> reports,
}) {
  final ranking = buildPokemonCircuitRanking(reports);
  final rows = <List<Object?>>[
    ['Ranking Pokemon TCG - STOP TCG'],
    ['Circuito', circuit.label],
    ['Torneios contabilizados', reports.length],
    ['Periodo', _circuitPeriod(reports)],
    [],
    ['RANKING ACUMULADO'],
    [
      'Posicao',
      'Jogador',
      'Player ID',
      'Categoria',
      'Torneios',
      'Vitorias',
      'Empates',
      'Derrotas',
      'Byes',
      'Pontos',
      'Melhor colocacao',
    ],
    for (final indexed in ranking.indexed)
      [
        indexed.$1 + 1,
        indexed.$2.name,
        indexed.$2.playerId,
        pokemonCategoryLabel(indexed.$2.category),
        indexed.$2.tournaments,
        indexed.$2.wins,
        indexed.$2.draws,
        indexed.$2.losses,
        indexed.$2.byes,
        indexed.$2.matchPoints,
        indexed.$2.bestPlacement,
      ],
    [],
    ['TORNEIOS INCLUIDOS'],
    ['Data', 'Torneio', 'Participantes', 'Arquivo TDF'],
    for (final report in reports)
      [
        _dateOnly(report.eventDate),
        report.name,
        report.participantCount,
        report.sourceFileName,
      ],
  ];
  return '\uFEFF${rows.map(_csvRow).join('\r\n')}\r\n';
}

String pokemonCircuitRankingCsvFileName(PokemonWeeklyCircuit circuit) =>
    'ranking_pokemon_${circuit.slug}.csv';

List<PokemonTournamentPlayer> _sortedPlayers(
  List<PokemonTournamentPlayer> players,
) => sortPokemonUnifiedStandings(players);

String _playerName(PokemonTournamentReport report, String id) =>
    report.players
        .where((player) => player.playerId == id)
        .map((player) => player.name)
        .firstOrNull ??
    id;

String _outcomeLabel(
  PokemonTournamentMatch match,
  PokemonTournamentReport report,
) => switch (match.outcome) {
  'player_one' => 'Venceu ${_playerName(report, match.playerOneId)}',
  'player_two' => 'Venceu ${_playerName(report, match.playerTwoId ?? '')}',
  'draw' => 'Empate',
  'bye' => 'Vitoria automatica',
  _ => 'Sem resultado',
};

String _csvRow(List<Object?> values) => values.map(_csvCell).join(';');

String _csvCell(Object? value) {
  var text = value?.toString() ?? '';
  if (text.startsWith(RegExp(r'[=+\-@]'))) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _circuitPeriod(List<PokemonTournamentReport> reports) {
  if (reports.isEmpty) return '';
  final dates = reports.map((report) => report.eventDate).toList()..sort();
  return '${_dateOnly(dates.first)} a ${_dateOnly(dates.last)}';
}
