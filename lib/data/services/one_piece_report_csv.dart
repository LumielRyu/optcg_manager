import '../models/one_piece_standings_report.dart';

String buildOnePieceReportCsv(OnePieceStandingsReport report) {
  final rows = <List<Object?>>[
    ['Relatorio One Piece Card Game - STOP TCG'],
    ['Torneio', report.eventName],
    ['Data', _dateOnly(report.eventDate)],
    ['Arquivo de origem', report.sourceFileName],
    ['Participantes', report.participantCount],
    ['Rodadas', report.effectiveRoundCount],
    [],
    ['CLASSIFICACAO FINAL'],
    [
      'Posicao',
      'Jogador',
      'Bandai ID',
      'Pontos',
      'OMW %',
      'OOMW %',
      'Memo',
      'Deck URL',
      'Lider',
      'Codigo do lider',
    ],
    for (final player in report.players)
      [
        player.ranking,
        player.userName,
        player.membershipNumber,
        player.winPoints,
        player.omwPercentage,
        player.oomwPercentage,
        player.memo,
        player.deckUrls,
        player.leaderName,
        player.leaderCode,
      ],
  ];
  return '\uFEFF${rows.map(_csvRow).join('\r\n')}\r\n';
}

String onePieceReportCsvFileName(OnePieceStandingsReport report) {
  final name = report.eventName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return '${_dateOnly(report.eventDate).replaceAll('-', '')}_${name.isEmpty ? 'semanal-one-piece' : name}.csv';
}

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
