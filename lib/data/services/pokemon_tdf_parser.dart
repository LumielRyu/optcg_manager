import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../models/pokemon_tdf_report.dart';

bool isPokemonTdfFileName(String fileName) =>
    fileName.trim().toLowerCase().endsWith('.tdf');

class PokemonTdfParser {
  const PokemonTdfParser();

  PokemonTournamentReport parseBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final content = _decode(bytes);
    return parse(content, fileName: fileName);
  }

  PokemonTournamentReport parse(String content, {required String fileName}) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlParserException catch (error) {
      throw FormatException('O arquivo TDF nao contem um XML valido: $error');
    }

    final tournament = document.rootElement;
    if (tournament.name.local != 'tournament') {
      throw const FormatException(
        'O arquivo nao e um torneio TDF reconhecido.',
      );
    }

    final data = tournament.getElement('data');
    final name = _text(data, 'name');
    final eventDate = _parseUsDate(_text(data, 'startdate'));
    if (name.isEmpty || eventDate == null) {
      throw const FormatException(
        'O TDF precisa conter o nome e a data inicial do torneio.',
      );
    }

    final rawPlayers = <String, _MutablePlayer>{};
    final playersElement = tournament.getElement('players');
    for (final player in _children(playersElement, 'player')) {
      final id = player.getAttribute('userid')?.trim() ?? '';
      if (id.isEmpty) continue;
      final fullName = [
        _text(player, 'firstname'),
        _text(player, 'lastname'),
      ].where((part) => part.isNotEmpty).join(' ').trim();
      rawPlayers[id] = _MutablePlayer(
        playerId: id,
        name: fullName.isEmpty ? 'Jogador $id' : fullName,
        droppedRound: _intText(player.getElement('dropped'), 'round'),
      );
    }

    final rounds = <PokemonTournamentRound>[];
    final seenRounds = <String>{};
    for (final round in tournament.findAllElements('round')) {
      if (round.parentElement?.name.local != 'rounds') continue;
      final number = int.tryParse(round.getAttribute('number') ?? '') ?? 0;
      if (number <= 0) continue;
      final pod = round.parentElement?.parentElement;
      final roundKey = '${pod?.getAttribute('category') ?? ''}:$number';
      if (!seenRounds.add(roundKey)) continue;

      final matches = <PokemonTournamentMatch>[];
      for (final match in _children(round.getElement('matches'), 'match')) {
        final rawOutcome = match.getAttribute('outcome') ?? '';
        final byePlayer = match.getElement('player')?.getAttribute('userid');
        final playerOne =
            match.getElement('player1')?.getAttribute('userid') ??
            byePlayer ??
            '';
        final playerTwo = match.getElement('player2')?.getAttribute('userid');
        if (playerOne.isEmpty) continue;
        final outcome = _outcome(rawOutcome, playerTwo == null);
        final parsed = PokemonTournamentMatch(
          tableNumber: _intText(match, 'tablenumber'),
          playerOneId: playerOne,
          playerTwoId: playerTwo,
          outcome: outcome,
        );
        matches.add(parsed);
        _applyResult(rawPlayers, parsed);
      }
      rounds.add(
        PokemonTournamentRound(
          number: number,
          startedAt: _parseUsDateTime(_text(round, 'starttime')),
          matches: matches,
        ),
      );
    }
    rounds.sort((a, b) => a.number.compareTo(b.number));

    final standings = tournament.getElement('standings');
    for (final pod in _children(standings, 'pod')) {
      final category = int.tryParse(pod.getAttribute('category') ?? '') ?? 2;
      final isFinished = pod.getAttribute('type') == 'finished';
      for (final standing in _children(pod, 'player')) {
        final id = standing.getAttribute('id') ?? '';
        final player = rawPlayers[id];
        if (player == null) continue;
        player.category = category;
        if (isFinished) {
          player.placement = int.tryParse(standing.getAttribute('place') ?? '');
        }
      }
    }

    final players = rawPlayers.values.map((player) => player.freeze()).toList()
      ..sort((a, b) {
        final byCategory = b.category.compareTo(a.category);
        if (byCategory != 0) return byCategory;
        final byPlacement = (a.placement ?? 999).compareTo(b.placement ?? 999);
        return byPlacement != 0 ? byPlacement : a.name.compareTo(b.name);
      });

    final sourceKey = _sourceKey(name, eventDate, players.length);
    return PokemonTournamentReport(
      sourceKey: sourceKey,
      sourceFileName: fileName,
      name: name,
      eventDate: eventDate,
      city: _text(data, 'city'),
      state: _text(data, 'state'),
      country: _text(data, 'country'),
      organizerName: data?.getElement('organizer')?.getAttribute('name') ?? '',
      roundTimeMinutes: _intText(data, 'roundtime') ?? 0,
      finalsRoundTimeMinutes: _intText(data, 'finalsroundtime') ?? 0,
      elapsedSeconds: _intText(tournament, 'timeelapsed') ?? 0,
      softwareVersion: tournament.getAttribute('version') ?? '',
      players: players,
      rounds: rounds,
    );
  }

  String _decode(Uint8List bytes) {
    final cleanBytes =
        bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF
        ? bytes.sublist(3)
        : bytes;
    try {
      return utf8.decode(cleanBytes);
    } on FormatException {
      return latin1.decode(cleanBytes);
    }
  }

  String _text(XmlElement? parent, String name) =>
      parent?.getElement(name)?.innerText.trim() ?? '';

  int? _intText(XmlElement? parent, String name) =>
      int.tryParse(_text(parent, name));

  Iterable<XmlElement> _children(XmlElement? parent, String name) =>
      parent?.childElements.where((element) => element.name.local == name) ??
      const <XmlElement>[];

  DateTime? _parseUsDate(String raw) {
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  DateTime? _parseUsDateTime(String raw) {
    final parts = raw.split(' ');
    final date = _parseUsDate(parts.firstOrNull ?? '');
    if (date == null || parts.length < 2) return date;
    final time = parts[1].split(':');
    if (time.length < 2) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(time[0]) ?? 0,
      int.tryParse(time[1]) ?? 0,
      time.length > 2 ? int.tryParse(time[2]) ?? 0 : 0,
    );
  }

  String _outcome(String raw, bool isBye) {
    if (isBye || raw == '5') return 'bye';
    return switch (raw) {
      '1' => 'player_one',
      '2' => 'player_two',
      '3' => 'draw',
      _ => 'unknown',
    };
  }

  void _applyResult(
    Map<String, _MutablePlayer> players,
    PokemonTournamentMatch match,
  ) {
    final one = players[match.playerOneId];
    final two = players[match.playerTwoId];
    switch (match.outcome) {
      case 'bye':
        one?.wins++;
        one?.byes++;
      case 'player_one':
        one?.wins++;
        two?.losses++;
      case 'player_two':
        two?.wins++;
        one?.losses++;
      case 'draw':
        one?.draws++;
        two?.draws++;
    }
  }

  String _sourceKey(String name, DateTime date, int playerCount) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    return '$dateKey-$normalized-$playerCount';
  }
}

class _MutablePlayer {
  final String playerId;
  final String name;
  final int? droppedRound;
  int category = 2;
  int? placement;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int byes = 0;

  _MutablePlayer({
    required this.playerId,
    required this.name,
    required this.droppedRound,
  });

  PokemonTournamentPlayer freeze() => PokemonTournamentPlayer(
    playerId: playerId,
    name: name,
    category: category,
    placement: placement,
    droppedRound: droppedRound,
    wins: wins,
    draws: draws,
    losses: losses,
    byes: byes,
  );
}
