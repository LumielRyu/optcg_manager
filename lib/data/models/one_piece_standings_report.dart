import 'dart:math' as math;

class OnePieceStandingsReport {
  final String sourceKey;
  final String sourceFileName;
  final String eventName;
  final DateTime eventDate;
  final int roundCount;
  final List<OnePieceStandingPlayer> players;

  const OnePieceStandingsReport({
    required this.sourceKey,
    required this.sourceFileName,
    required this.eventName,
    required this.eventDate,
    this.roundCount = 0,
    required this.players,
  });

  int get participantCount => players.length;
  int get highestWinPoints => players.isEmpty
      ? 0
      : players
            .map((player) => player.winPoints)
            .reduce((a, b) => a > b ? a : b);

  int get effectiveRoundCount {
    if (roundCount > 0) return roundCount;
    final roundsByParticipants = players.length <= 1
        ? 0
        : (math.log(players.length) / math.ln2).ceil();
    final roundsByPoints = (highestWinPoints / 3).ceil();
    return math.max(roundsByParticipants, roundsByPoints);
  }

  OnePieceStandingsReport copyWith({
    String? eventName,
    DateTime? eventDate,
    int? roundCount,
    List<OnePieceStandingPlayer>? players,
  }) {
    final nextName = eventName ?? this.eventName;
    final nextDate = eventDate ?? this.eventDate;
    final nextPlayers = players ?? this.players;
    return OnePieceStandingsReport(
      sourceKey: buildOnePieceStandingsSourceKey(
        eventName: nextName,
        eventDate: nextDate,
        players: nextPlayers,
      ),
      sourceFileName: sourceFileName,
      eventName: nextName,
      eventDate: nextDate,
      roundCount: roundCount ?? this.roundCount,
      players: nextPlayers,
    );
  }

  Map<String, dynamic> toJson() => {
    'source_key': sourceKey,
    'source_file_name': sourceFileName,
    'event_name': eventName,
    'event_date': _dateOnly(eventDate),
    'round_count': effectiveRoundCount,
    'players': players.map((player) => player.toJson()).toList(),
  };

  factory OnePieceStandingsReport.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    return OnePieceStandingsReport(
      sourceKey: json['source_key'].toString(),
      sourceFileName: (json['source_file_name'] ?? '').toString(),
      eventName: json['event_name'].toString(),
      eventDate: DateTime.parse(json['event_date'].toString()),
      roundCount: int.tryParse(json['round_count']?.toString() ?? '') ?? 0,
      players: rawPlayers is List
          ? rawPlayers
                .whereType<Map>()
                .map(
                  (item) => OnePieceStandingPlayer.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class OnePieceStandingPlayer {
  final int ranking;
  final String membershipNumber;
  final String userName;
  final int winPoints;
  final double omwPercentage;
  final double oomwPercentage;
  final String memo;
  final String deckUrls;
  final String leaderCode;
  final String leaderName;

  const OnePieceStandingPlayer({
    required this.ranking,
    required this.membershipNumber,
    required this.userName,
    required this.winPoints,
    required this.omwPercentage,
    required this.oomwPercentage,
    required this.memo,
    required this.deckUrls,
    this.leaderCode = '',
    this.leaderName = '',
  });

  bool get hasLeader =>
      leaderCode.trim().isNotEmpty || leaderName.trim().isNotEmpty;
  int get wins => winPoints ~/ 3;

  OnePieceStandingPlayer copyWith({String? leaderCode, String? leaderName}) =>
      OnePieceStandingPlayer(
        ranking: ranking,
        membershipNumber: membershipNumber,
        userName: userName,
        winPoints: winPoints,
        omwPercentage: omwPercentage,
        oomwPercentage: oomwPercentage,
        memo: memo,
        deckUrls: deckUrls,
        leaderCode: leaderCode ?? this.leaderCode,
        leaderName: leaderName ?? this.leaderName,
      );

  Map<String, dynamic> toJson() => {
    'ranking': ranking,
    'membership_number': membershipNumber,
    'user_name': userName,
    'win_points': winPoints,
    'omw_percentage': omwPercentage,
    'oomw_percentage': oomwPercentage,
    'memo': memo,
    'deck_urls': deckUrls,
    'leader_code': leaderCode,
    'leader_name': leaderName,
  };

  factory OnePieceStandingPlayer.fromJson(Map<String, dynamic> json) =>
      OnePieceStandingPlayer(
        ranking: int.tryParse(json['ranking']?.toString() ?? '') ?? 0,
        membershipNumber: (json['membership_number'] ?? '').toString(),
        userName: (json['user_name'] ?? '').toString(),
        winPoints: int.tryParse(json['win_points']?.toString() ?? '') ?? 0,
        omwPercentage:
            double.tryParse(json['omw_percentage']?.toString() ?? '') ?? 0,
        oomwPercentage:
            double.tryParse(json['oomw_percentage']?.toString() ?? '') ?? 0,
        memo: (json['memo'] ?? '').toString(),
        deckUrls: (json['deck_urls'] ?? '').toString(),
        leaderCode: (json['leader_code'] ?? '').toString(),
        leaderName: (json['leader_name'] ?? '').toString(),
      );
}

String buildOnePieceStandingsSourceKey({
  required String eventName,
  required DateTime eventDate,
  required List<OnePieceStandingPlayer> players,
}) {
  final normalized = eventName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final date = _dateOnly(eventDate).replaceAll('-', '');
  final fingerprint = players.fold<int>(2166136261, (hash, player) {
    for (final unit
        in '${player.ranking}|${player.membershipNumber}|${player.userName}|${player.winPoints}'
            .codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  });
  return '$date-${normalized.isEmpty ? 'semanal-one-piece' : normalized}-${fingerprint.toRadixString(16)}';
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
