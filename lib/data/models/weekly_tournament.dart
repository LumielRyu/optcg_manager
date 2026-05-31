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
  final String deckName;

  const WeeklyParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.playerName,
    required this.deckName,
  });

  factory WeeklyParticipant.fromJson(Map<String, dynamic> json) {
    return WeeklyParticipant(
      id: json['id'].toString(),
      eventId: json['weekly_event_id'].toString(),
      userId: json['user_id'].toString(),
      playerName: json['player_name'].toString(),
      deckName: json['deck_name'].toString(),
    );
  }
}

class WeeklyMatch {
  final String id;
  final String eventId;
  final int roundNumber;
  final int? tableNumber;
  final String playerOneId;
  final String playerTwoId;
  final String result;

  const WeeklyMatch({
    required this.id,
    required this.eventId,
    required this.roundNumber,
    required this.tableNumber,
    required this.playerOneId,
    required this.playerTwoId,
    required this.result,
  });

  bool get isCompleted => result != 'scheduled';

  factory WeeklyMatch.fromJson(Map<String, dynamic> json) {
    return WeeklyMatch(
      id: json['id'].toString(),
      eventId: json['weekly_event_id'].toString(),
      roundNumber: json['round_number'] as int,
      tableNumber: json['table_number'] as int?,
      playerOneId: json['player_one_id'].toString(),
      playerTwoId: json['player_two_id'].toString(),
      result: json['result'].toString(),
    );
  }
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
  final String playerName;
  final int games;
  final int wins;
  final int draws;
  final int losses;
  final List<String> topDecks;

  const MonthlyRankingEntry({
    required this.userId,
    required this.playerName,
    required this.games,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.topDecks,
  });

  int get points => (wins * 3) + draws;
}

class WeeklyDashboardData {
  final List<WeeklyEvent> events;
  final List<WeeklyParticipant> participants;
  final List<WeeklyMatch> matches;
  final List<MonthlyRankingEntry> ranking;
  final List<WeeklyPlayerProfile> profiles;

  const WeeklyDashboardData({
    required this.events,
    required this.participants,
    required this.matches,
    required this.ranking,
    required this.profiles,
  });
}
