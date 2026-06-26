class WeeklyEvent {
  final String id;
  final String gameSlug;
  final String title;
  final DateTime eventDate;
  final String status;

  const WeeklyEvent({
    required this.id,
    required this.gameSlug,
    required this.title,
    required this.eventDate,
    required this.status,
  });

  factory WeeklyEvent.fromJson(Map<String, dynamic> json) {
    return WeeklyEvent(
      id: json['id'].toString(),
      gameSlug: json['game_slug'].toString(),
      title: json['title'].toString(),
      eventDate: DateTime.parse(json['event_date'].toString()),
      status: json['status'].toString(),
    );
  }
}

class WeeklyParticipant {
  final String id;
  final String eventId;
  final String userId;
  final String playerName;
  final String playerDisplayName;
  final String deckName;
  final String leaderCode;
  final String leaderName;

  const WeeklyParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.playerName,
    required this.playerDisplayName,
    required this.deckName,
    required this.leaderCode,
    required this.leaderName,
  });

  factory WeeklyParticipant.fromJson(Map<String, dynamic> json) {
    return WeeklyParticipant(
      id: json['id'].toString(),
      eventId: json['weekly_event_id'].toString(),
      userId: json['user_id'].toString(),
      playerName: json['player_name'].toString(),
      playerDisplayName: (json['player_display_name'] ?? json['player_name'])
          .toString(),
      deckName: json['deck_name'].toString(),
      leaderCode: (json['leader_code'] ?? '').toString(),
      leaderName: (json['leader_name'] ?? json['deck_name'] ?? '').toString(),
    );
  }
}

class WeeklyMatch {
  final String id;
  final String eventId;
  final int roundNumber;
  final int? tableNumber;
  final String playerOneId;
  final String? playerTwoId;
  final String result;
  final String matchType;
  final String resultStatus;
  final String? reportedBy;

  const WeeklyMatch({
    required this.id,
    required this.eventId,
    required this.roundNumber,
    required this.tableNumber,
    required this.playerOneId,
    required this.playerTwoId,
    required this.result,
    required this.matchType,
    required this.resultStatus,
    required this.reportedBy,
  });

  bool get isCompleted => resultStatus == 'confirmed';
  bool get isBye => matchType == 'bye';

  factory WeeklyMatch.fromJson(Map<String, dynamic> json) {
    return WeeklyMatch(
      id: json['id'].toString(),
      eventId: json['weekly_event_id'].toString(),
      roundNumber: json['round_number'] as int,
      tableNumber: json['table_number'] as int?,
      playerOneId: json['player_one_id'].toString(),
      playerTwoId: json['player_two_id']?.toString(),
      result: json['result'].toString(),
      matchType: (json['match_type'] ?? 'regular').toString(),
      resultStatus: (json['result_status'] ?? 'confirmed').toString(),
      reportedBy: json['reported_by']?.toString(),
    );
  }
}

class WeeklyGameProfile {
  final String userId;
  final String gameSlug;
  final String nickname;
  final String bandaiCode;

  const WeeklyGameProfile({
    required this.userId,
    required this.gameSlug,
    required this.nickname,
    required this.bandaiCode,
  });

  factory WeeklyGameProfile.fromJson(Map<String, dynamic> json) {
    return WeeklyGameProfile(
      userId: json['user_id'].toString(),
      gameSlug: json['game_slug'].toString(),
      nickname: json['nickname'].toString(),
      bandaiCode: (json['bandai_code'] ?? '').toString(),
    );
  }
}

class WeeklyLeaderOption {
  final String code;
  final String name;

  const WeeklyLeaderOption({required this.code, required this.name});

  String get label => code.isEmpty ? name : '$name ($code)';
}

String normalizeWeeklyLeaderName(String rawName) {
  return rawName
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'\s+-\s+[A-Z]{2,}\d{2}-\d{3}\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int weeklyLeaderReleaseOrder(String code) {
  final match = RegExp(r'^([A-Z]+)(\d+)-').firstMatch(code.toUpperCase());
  if (match == null) return 0;
  final series = match.group(1)!;
  final number = int.tryParse(match.group(2)!) ?? 0;

  return switch (series) {
    'OP' => number * 100,
    'EB' => switch (number) {
      1 => 650,
      2 => 950,
      3 => 1450,
      4 => 1550,
      _ => number * 100,
    },
    'PRB' => switch (number) {
      1 => 850,
      _ => number * 100,
    },
    'ST' => switch (number) {
      >= 29 => 1525 + number,
      >= 21 => 1000 + number,
      >= 15 => 800 + number,
      _ => number * 100,
    },
    _ => number,
  };
}

class WeeklyPlayerProfile {
  final String id;
  final String name;
  final String email;

  const WeeklyPlayerProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  factory WeeklyPlayerProfile.fromJson(Map<String, dynamic> json) {
    return WeeklyPlayerProfile(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}

class MonthlyRankingEntry {
  final String userId;
  final String playerDisplayName;
  final String playerNickname;
  final int rankingPoints;
  final List<int> weeklyScores;
  final int firstPlaces;
  final int secondPlaces;
  final int top4Finishes;
  final int? lastWeeklyRank;
  final int games;
  final int wins;
  final int draws;
  final int losses;
  final List<WeeklyDeckUsage> deckUsage;
  final List<WeeklyOpponentDeckStats> opponentDeckStats;

  const MonthlyRankingEntry({
    required this.userId,
    required this.playerDisplayName,
    required this.playerNickname,
    required this.rankingPoints,
    required this.weeklyScores,
    required this.firstPlaces,
    required this.secondPlaces,
    required this.top4Finishes,
    required this.lastWeeklyRank,
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.deckUsage,
    required this.opponentDeckStats,
  });

  int get points => rankingPoints;
  int get validWeeks => weeklyScores.where((score) => score > 0).length;
  List<String> get topDecks => deckUsage
      .take(3)
      .map((item) => '${item.deckName} (${item.games})')
      .toList(growable: false);
}

class WeeklyDeckUsage {
  final String deckName;
  final int games;

  const WeeklyDeckUsage({required this.deckName, required this.games});
}

class WeeklyOpponentDeckStats {
  final String deckName;
  final int games;
  final int wins;
  final int draws;
  final int losses;

  const WeeklyOpponentDeckStats({
    required this.deckName,
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
  });
}

class WeeklyDashboardData {
  final List<WeeklyEvent> events;
  final List<WeeklyParticipant> participants;
  final List<WeeklyMatch> matches;
  final List<MonthlyRankingEntry> ranking;
  final List<WeeklyPlayerProfile> profiles;
  final WeeklyGameProfile? currentGameProfile;
  final List<WeeklyLeaderOption> leaders;

  const WeeklyDashboardData({
    required this.events,
    required this.participants,
    required this.matches,
    required this.ranking,
    required this.profiles,
    required this.currentGameProfile,
    required this.leaders,
  });
}
