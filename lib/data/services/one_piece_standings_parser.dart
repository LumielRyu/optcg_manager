import 'dart:convert';
import 'dart:typed_data';

import '../models/one_piece_standings_report.dart';

bool isOnePieceStandingsFileName(String fileName) =>
    fileName.trim().toLowerCase().endsWith('.csv');

class OnePieceStandingsParser {
  const OnePieceStandingsParser();

  OnePieceStandingsReport parseBytes(
    Uint8List bytes, {
    required String fileName,
    required DateTime eventDate,
  }) {
    final cleanBytes =
        bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF
        ? bytes.sublist(3)
        : bytes;
    String content;
    try {
      content = utf8.decode(cleanBytes);
    } on FormatException {
      content = latin1.decode(cleanBytes);
    }
    return parse(content, fileName: fileName, eventDate: eventDate);
  }

  OnePieceStandingsReport parse(
    String content, {
    required String fileName,
    required DateTime eventDate,
  }) {
    final rows = _parseCsv(
      content,
    ).where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    if (rows.length < 2) {
      throw const FormatException(
        'O CSV nao contem uma classificacao do torneio.',
      );
    }
    final headers = rows.first.map(_normalizeHeader).toList();
    const requiredHeaders = [
      'ranking',
      'membership number',
      'user name',
      'win points',
      'omw %',
      'oomw %',
    ];
    if (requiredHeaders.any((header) => !headers.contains(header))) {
      throw const FormatException(
        'O arquivo nao possui as colunas esperadas do Bandai TCG+: Ranking, Membership Number, User Name, Win Points, OMW % e OOMW %.',
      );
    }
    String cell(List<String> row, String header) {
      final index = headers.indexOf(header);
      return index >= 0 && index < row.length ? row[index].trim() : '';
    }

    final players = <OnePieceStandingPlayer>[];
    for (final row in rows.skip(1)) {
      final ranking = int.tryParse(cell(row, 'ranking'));
      final name = cell(row, 'user name');
      if (ranking == null || ranking <= 0 || name.isEmpty) continue;
      players.add(
        OnePieceStandingPlayer(
          ranking: ranking,
          membershipNumber: cell(row, 'membership number'),
          userName: name,
          winPoints: int.tryParse(cell(row, 'win points')) ?? 0,
          omwPercentage: _percentage(cell(row, 'omw %')),
          oomwPercentage: _percentage(cell(row, 'oomw %')),
          memo: _cleanOptional(cell(row, 'memo')),
          deckUrls: _cleanOptional(cell(row, 'deck urls')),
        ),
      );
    }
    if (players.isEmpty) {
      throw const FormatException(
        'Nenhum jogador valido foi encontrado no CSV.',
      );
    }
    players.sort((a, b) => a.ranking.compareTo(b.ranking));
    final eventName = _eventNameFromFile(fileName);
    return OnePieceStandingsReport(
      sourceKey: buildOnePieceStandingsSourceKey(
        eventName: eventName,
        eventDate: eventDate,
        players: players,
      ),
      sourceFileName: fileName,
      eventName: eventName,
      eventDate: eventDate,
      players: players,
    );
  }

  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        if (quoted && i + 1 < content.length && content[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell = StringBuffer();
      } else {
        cell.write(char);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  String _normalizeHeader(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  double _percentage(String value) =>
      double.tryParse(value.replaceAll('%', '').trim()) ?? 0;
  String _cleanOptional(String value) =>
      value.toLowerCase() == 'undefined' ? '' : value;
  String _eventNameFromFile(String fileName) {
    final name = fileName
        .replaceFirst(RegExp(r'\.csv$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'[_ -]*standing$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return name.isEmpty ? 'Semanal One Piece' : name;
  }
}
