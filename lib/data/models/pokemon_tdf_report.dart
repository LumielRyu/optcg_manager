class PokemonTournamentReport {
  final String sourceKey;
  final String sourceFileName;
  final String name;
  final DateTime eventDate;
  final String city;
  final String state;
  final String country;
  final String organizerName;
  final int roundTimeMinutes;
  final int finalsRoundTimeMinutes;
  final int elapsedSeconds;
  final String softwareVersion;
  final List<PokemonTournamentPlayer> players;
  final List<PokemonTournamentRound> rounds;

  const PokemonTournamentReport({
    required this.sourceKey,
    required this.sourceFileName,
    required this.name,
    required this.eventDate,
    required this.city,
    required this.state,
    required this.country,
    required this.organizerName,
    required this.roundTimeMinutes,
    required this.finalsRoundTimeMinutes,
    required this.elapsedSeconds,
    required this.softwareVersion,
    required this.players,
    required this.rounds,
  });

  int get participantCount => players.length;
  int get roundCount => rounds.length;
  int get matchCount =>
      rounds.fold(0, (total, round) => total + round.matches.length);
  int get completedMatchCount => rounds.fold(
    0,
    (total, round) =>
        total +
        round.matches.where((match) => match.outcome != 'unknown').length,
  );
  int get dropCount =>
      players.where((player) => player.droppedRound != null).length;

  Map<String, dynamic> toJson() => {
    'source_key': sourceKey,
    'source_file_name': sourceFileName,
    'name': name,
    'event_date': _dateOnly(eventDate),
    'city': city,
    'state': state,
    'country': country,
    'organizer_name': organizerName,
    'round_time_minutes': roundTimeMinutes,
    'finals_round_time_minutes': finalsRoundTimeMinutes,
    'elapsed_seconds': elapsedSeconds,
    'software_version': softwareVersion,
    'players': players.map((player) => player.toJson()).toList(),
    'rounds': rounds.map((round) => round.toJson()).toList(),
  };

  factory PokemonTournamentReport.fromJson(Map<String, dynamic> json) {
    return PokemonTournamentReport(
      sourceKey: json['source_key'].toString(),
      sourceFileName: (json['source_file_name'] ?? '').toString(),
      name: json['name'].toString(),
      eventDate: DateTime.parse(json['event_date'].toString()),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      organizerName: (json['organizer_name'] ?? '').toString(),
      roundTimeMinutes: _asInt(json['round_time_minutes']),
      finalsRoundTimeMinutes: _asInt(json['finals_round_time_minutes']),
      elapsedSeconds: _asInt(json['elapsed_seconds']),
      softwareVersion: (json['software_version'] ?? '').toString(),
      players: _mapList(json['players'], PokemonTournamentPlayer.fromJson),
      rounds: _mapList(json['rounds'], PokemonTournamentRound.fromJson),
    );
  }
}

class PokemonTournamentPlayer {
  final String playerId;
  final String name;
  final int category;
  final int? placement;
  final int? droppedRound;
  final int wins;
  final int draws;
  final int losses;
  final int byes;

  const PokemonTournamentPlayer({
    required this.playerId,
    required this.name,
    required this.category,
    required this.placement,
    required this.droppedRound,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.byes,
  });

  int get games => wins + draws + losses;
  int get matchPoints => (wins * 3) + draws;
  String get categoryLabel => pokemonCategoryLabel(category);

  Map<String, dynamic> toJson() => {
    'player_id': playerId,
    'name': name,
    'category': category,
    'placement': placement,
    'dropped_round': droppedRound,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'byes': byes,
  };

  factory PokemonTournamentPlayer.fromJson(Map<String, dynamic> json) {
    return PokemonTournamentPlayer(
      playerId: json['player_id'].toString(),
      name: json['name'].toString(),
      category: _asInt(json['category'], fallback: 2),
      placement: _asNullableInt(json['placement']),
      droppedRound: _asNullableInt(json['dropped_round']),
      wins: _asInt(json['wins']),
      draws: _asInt(json['draws']),
      losses: _asInt(json['losses']),
      byes: _asInt(json['byes']),
    );
  }
}

class PokemonTournamentRound {
  final int number;
  final DateTime? startedAt;
  final List<PokemonTournamentMatch> matches;

  const PokemonTournamentRound({
    required this.number,
    required this.startedAt,
    required this.matches,
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'started_at': startedAt?.toIso8601String(),
    'matches': matches.map((match) => match.toJson()).toList(),
  };

  factory PokemonTournamentRound.fromJson(Map<String, dynamic> json) {
    final startedAt = json['started_at']?.toString();
    return PokemonTournamentRound(
      number: _asInt(json['number']),
      startedAt: startedAt == null || startedAt.isEmpty
          ? null
          : DateTime.tryParse(startedAt),
      matches: _mapList(json['matches'], PokemonTournamentMatch.fromJson),
    );
  }
}

class PokemonTournamentMatch {
  final int? tableNumber;
  final String playerOneId;
  final String? playerTwoId;
  final String outcome;

  const PokemonTournamentMatch({
    required this.tableNumber,
    required this.playerOneId,
    required this.playerTwoId,
    required this.outcome,
  });

  bool get isBye => outcome == 'bye';

  Map<String, dynamic> toJson() => {
    'table_number': tableNumber,
    'player_one_id': playerOneId,
    'player_two_id': playerTwoId,
    'outcome': outcome,
  };

  factory PokemonTournamentMatch.fromJson(Map<String, dynamic> json) {
    return PokemonTournamentMatch(
      tableNumber: _asNullableInt(json['table_number']),
      playerOneId: json['player_one_id'].toString(),
      playerTwoId: json['player_two_id']?.toString(),
      outcome: json['outcome'].toString(),
    );
  }
}

String pokemonCategoryLabel(int category) => switch (category) {
  0 => 'Junior',
  1 => 'Senior',
  _ => 'Master',
};

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int _asInt(dynamic value, {int fallback = 0}) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;

int? _asNullableInt(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
