import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weekly_tournament.dart';
import '../services/op_api_service.dart';
import '../services/supabase_client_provider.dart';

final weeklyTournamentRepositoryProvider = Provider<WeeklyTournamentRepository>(
  (ref) => WeeklyTournamentRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(opApiServiceProvider),
  ),
);

class WeeklyTournamentRepository {
  final SupabaseClient _client;
  final OpApiService _opApiService;

  WeeklyTournamentRepository(this._client, this._opApiService);

  String get currentUserId => _client.auth.currentUser?.id ?? '';

  bool get isAdmin {
    final value = _client.auth.currentUser?.appMetadata['is_weekly_admin'];
    return value == true || value?.toString() == 'true';
  }

  Future<DateTime?> loadLatestEventMonth({required String gameSlug}) async {
    final row = await _client
        .from('weekly_events')
        .select('event_date')
        .eq('game_slug', gameSlug)
        .order('event_date', ascending: false)
        .limit(1)
        .maybeSingle();
    final date = DateTime.tryParse(row?['event_date']?.toString() ?? '');
    return date == null ? null : DateTime(date.year, date.month);
  }

  Future<WeeklyDashboardData> loadDashboard({
    required String gameSlug,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rawEvents = await _client
        .from('weekly_events')
        .select()
        .eq('game_slug', gameSlug)
        .gte('event_date', _dateOnly(start))
        .lt('event_date', _dateOnly(end))
        .order('event_date', ascending: false);
    final events = rawEvents
        .map((row) => WeeklyEvent.fromJson(row))
        .toList(growable: false);
    final eventIds = events.map((event) => event.id).toList(growable: false);
    final supportingData = await Future.wait<dynamic>([
      _loadProfilesIfAdmin(),
      _loadCurrentGameProfile(gameSlug),
      _loadLeaderOptions(gameSlug),
    ]);

    if (eventIds.isEmpty) {
      return WeeklyDashboardData(
        events: const [],
        participants: const [],
        matches: const [],
        ranking: const [],
        profiles: supportingData[0] as List<WeeklyPlayerProfile>,
        currentGameProfile: supportingData[1] as WeeklyGameProfile?,
        leaders: supportingData[2] as List<WeeklyLeaderOption>,
      );
    }

    final results = await Future.wait<dynamic>([
      _client
          .from('weekly_participants')
          .select()
          .inFilter('weekly_event_id', eventIds),
      _client
          .from('weekly_matches')
          .select()
          .inFilter('weekly_event_id', eventIds)
          .order('round_number')
          .order('table_number'),
    ]);
    final participants = (results[0] as List)
        .map((row) => WeeklyParticipant.fromJson(row))
        .toList(growable: false);
    final matches = (results[1] as List)
        .map((row) => WeeklyMatch.fromJson(row))
        .toList(growable: false);

    return WeeklyDashboardData(
      events: events,
      participants: participants,
      matches: matches,
      ranking: _buildRanking(events, participants, matches),
      profiles: supportingData[0] as List<WeeklyPlayerProfile>,
      currentGameProfile: supportingData[1] as WeeklyGameProfile?,
      leaders: supportingData[2] as List<WeeklyLeaderOption>,
    );
  }

  Future<WeeklyGameProfile?> _loadCurrentGameProfile(String gameSlug) async {
    if (currentUserId.isEmpty) {
      return null;
    }

    try {
      final row = await _client
          .from('weekly_game_profiles')
          .select()
          .eq('user_id', currentUserId)
          .eq('game_slug', gameSlug)
          .maybeSingle();
      return row == null ? null : WeeklyGameProfile.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205') return null;
      rethrow;
    }
  }

  Future<List<WeeklyLeaderOption>> _loadLeaderOptions(String gameSlug) async {
    if (gameSlug != 'one-piece') return const [];
    try {
      final cards = await _opApiService.loadAllCards();
      final leadersByCode = <String, WeeklyLeaderOption>{};
      for (final card in cards.where(
        (card) => card.type.toLowerCase() == 'leader',
      )) {
        final code = card.code.trim().toUpperCase();
        final name = normalizeWeeklyLeaderName(card.name);
        if (code.isEmpty || name.isEmpty) continue;
        leadersByCode.putIfAbsent(
          code,
          () => WeeklyLeaderOption(code: code, name: name),
        );
      }
      final leaders = leadersByCode.values.toList();
      leaders.sort((a, b) {
        final byRelease = weeklyLeaderReleaseOrder(
          b.code,
        ).compareTo(weeklyLeaderReleaseOrder(a.code));
        if (byRelease != 0) return byRelease;
        final byCode = b.code.compareTo(a.code);
        return byCode != 0 ? byCode : a.name.compareTo(b.name);
      });
      return leaders;
    } catch (_) {
      return const [];
    }
  }

  Future<List<WeeklyPlayerProfile>> _loadProfilesIfAdmin() async {
    if (!isAdmin) return const [];
    final rows = await _client
        .from('profiles')
        .select('id, name, email')
        .order('name');
    return rows
        .map((row) => WeeklyPlayerProfile.fromJson(row))
        .toList(growable: false);
  }

  Future<void> createEvent({
    required String gameSlug,
    required String title,
    required DateTime date,
  }) async {
    await _client.from('weekly_events').insert({
      'game_slug': gameSlug,
      'title': title.trim(),
      'event_date': _dateOnly(date),
      'created_by': currentUserId,
    });
  }

  Future<void> setEventStatus({
    required String eventId,
    required String status,
  }) async {
    await _client
        .from('weekly_events')
        .update({'status': status})
        .eq('id', eventId);
  }

  Future<void> resetWeeklyHistory({required String gameSlug}) async {
    await _client.from('weekly_events').delete().eq('game_slug', gameSlug);
  }

  Future<void> enrollPlayer({
    required String eventId,
    required WeeklyPlayerProfile profile,
    required String deckName,
    String leaderCode = '',
    String leaderName = '',
  }) async {
    await _client.from('weekly_participants').upsert({
      'weekly_event_id': eventId,
      'user_id': profile.id,
      'player_name': profile.name.trim().isEmpty ? profile.email : profile.name,
      'deck_name': deckName.trim(),
      'leader_code': leaderCode.trim(),
      'leader_name': leaderName.trim().isEmpty ? deckName.trim() : leaderName,
    }, onConflict: 'weekly_event_id,user_id');
  }

  Future<void> joinOpenEvent({
    required String eventId,
    required String gameSlug,
    required String nickname,
    required String bandaiCode,
    required String deckName,
    String leaderCode = '',
    String leaderName = '',
  }) async {
    if (currentUserId.isEmpty) {
      throw Exception('Entre ou cadastre-se para participar dos semanais.');
    }

    await _client.from('weekly_game_profiles').upsert({
      'user_id': currentUserId,
      'game_slug': gameSlug,
      'nickname': nickname.trim(),
      'bandai_code': bandaiCode.trim().isEmpty ? null : bandaiCode.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _client.from('weekly_participants').upsert({
      'weekly_event_id': eventId,
      'user_id': currentUserId,
      'player_name': nickname.trim(),
      'deck_name': deckName.trim(),
      'leader_code': leaderCode.trim(),
      'leader_name': leaderName.trim().isEmpty ? deckName.trim() : leaderName,
    }, onConflict: 'weekly_event_id,user_id');
  }

  Future<void> createMatch({
    required String eventId,
    required int roundNumber,
    int? tableNumber,
    required String playerOneId,
    required String playerTwoId,
    required String result,
  }) async {
    await _client.from('weekly_matches').insert({
      'weekly_event_id': eventId,
      'round_number': roundNumber,
      'table_number': tableNumber,
      'player_one_id': playerOneId,
      'player_two_id': playerTwoId,
      'match_type': 'regular',
      'result': result,
      'result_status': result == 'scheduled' ? 'scheduled' : 'confirmed',
      'created_by': currentUserId,
      if (result != 'scheduled') 'confirmed_by': currentUserId,
    });
  }

  Future<void> createBye({
    required String eventId,
    required int roundNumber,
    required String playerId,
  }) async {
    await _client.from('weekly_matches').insert({
      'weekly_event_id': eventId,
      'round_number': roundNumber,
      'player_one_id': playerId,
      'player_two_id': null,
      'match_type': 'bye',
      'result': 'bye',
      'result_status': 'confirmed',
      'created_by': currentUserId,
      'confirmed_by': currentUserId,
    });
  }

  Future<void> updateMatchResultAsAdmin({
    required String matchId,
    required String result,
  }) async {
    await _client
        .from('weekly_matches')
        .update({
          'result': result,
          'result_status': result == 'scheduled' ? 'scheduled' : 'confirmed',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', matchId);
  }

  Future<void> reportMatchResult({
    required String matchId,
    required String result,
  }) async {
    await _client
        .from('weekly_matches')
        .update({
          'result': result,
          'result_status': 'pending_confirmation',
          'reported_by': currentUserId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', matchId);
  }

  Future<void> reviewMatchResult({
    required String matchId,
    required bool confirm,
  }) async {
    await _client
        .from('weekly_matches')
        .update({
          'result_status': confirm ? 'confirmed' : 'disputed',
          if (confirm) 'confirmed_by': currentUserId,
          if (!confirm) 'disputed_by': currentUserId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', matchId);
  }

  List<MonthlyRankingEntry> _buildRanking(
    List<WeeklyEvent> events,
    List<WeeklyParticipant> participants,
    List<WeeklyMatch> matches,
  ) {
    final eventsById = {for (final event in events) event.id: event};
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final eventStats = <String, Map<String, _RankingAccumulator>>{};

    for (final participant in participants) {
      eventStats
          .putIfAbsent(
            participant.eventId,
            () => <String, _RankingAccumulator>{},
          )
          .putIfAbsent(
            participant.userId,
            () => _RankingAccumulator(
              playerDisplayName: participant.playerDisplayName,
              playerNickname: participant.playerName,
            ),
          )
          .addDeck(participant.deckName);
    }

    for (final match in matches.where((item) => item.isCompleted)) {
      final one = participantsById[match.playerOneId];
      final two = participantsById[match.playerTwoId];
      if (one == null) continue;
      final oneStats = eventStats[one.eventId]![one.userId]!;
      if (match.isBye) {
        oneStats.wins++;
        continue;
      }
      if (two == null) continue;
      final twoStats = eventStats[two.eventId]![two.userId]!;
      if (match.result == 'draw') {
        oneStats.draws++;
        twoStats.draws++;
        oneStats.addOpponentDeck(two.deckName, _MatchOutcome.draw);
        twoStats.addOpponentDeck(one.deckName, _MatchOutcome.draw);
      } else if (match.result == 'player_one') {
        oneStats.wins++;
        twoStats.losses++;
        oneStats.addOpponentDeck(two.deckName, _MatchOutcome.win);
        twoStats.addOpponentDeck(one.deckName, _MatchOutcome.loss);
      } else if (match.result == 'player_two') {
        twoStats.wins++;
        oneStats.losses++;
        twoStats.addOpponentDeck(one.deckName, _MatchOutcome.win);
        oneStats.addOpponentDeck(two.deckName, _MatchOutcome.loss);
      }
    }

    final weeklyPerformancesByUser =
        <String, Map<String, List<_WeeklyPerformance>>>{};
    final monthWeekKeys = <String>{};
    for (final eventEntry in eventStats.entries) {
      final event = eventsById[eventEntry.key];
      if (event == null) continue;
      final weekKey = _rankingWeekKey(event.eventDate);
      monthWeekKeys.add(weekKey);
      final standings = _buildEventStandings(
        eventDate: event.eventDate,
        eventStats: eventEntry.value,
      );
      for (final standing in standings) {
        weeklyPerformancesByUser
            .putIfAbsent(standing.userId, () => {})
            .putIfAbsent(weekKey, () => [])
            .add(standing);
      }
    }

    final stats = <String, _RankingAccumulator>{};
    final sortedMonthWeekKeys = monthWeekKeys.toList()..sort();
    for (final userEntry in weeklyPerformancesByUser.entries) {
      for (
        var weekIndex = 0;
        weekIndex < sortedMonthWeekKeys.length;
        weekIndex++
      ) {
        final weekKey = sortedMonthWeekKeys[weekIndex];
        final performances = userEntry.value[weekKey];
        if (performances == null || performances.isEmpty) continue;
        performances.sort((a, b) {
          final byPlacement = a.rank.compareTo(b.rank);
          if (byPlacement != 0) return byPlacement;
          return b.eventDate.compareTo(a.eventDate);
        });
        final best = performances.first;
        final playedBothWeeklies = performances.length >= 2;
        final weekScore =
            weeklyPlacementPoints(best.rank) +
            weeklyParticipantBonus(best.participantCount) +
            (playedBothWeeklies ? 5 : 0);
        stats
            .putIfAbsent(
              userEntry.key,
              () => _RankingAccumulator(
                playerDisplayName: best.stats.playerDisplayName,
                playerNickname: best.stats.playerNickname,
              ),
            )
            .applyWeeklyPerformance(
              best,
              weekScore: weekScore,
              weekIndex: weekIndex,
              isLastWeek: weekIndex == sortedMonthWeekKeys.length - 1,
            );
      }
    }

    final ranking = stats.entries
        .map((entry) => entry.value.toEntry(entry.key))
        .toList();
    ranking.sort(_compareMonthlyRankingEntries);
    return ranking;
  }

  List<_WeeklyPerformance> _buildEventStandings({
    required DateTime eventDate,
    required Map<String, _RankingAccumulator> eventStats,
  }) {
    final standings = eventStats.entries
        .map(
          (entry) => _WeeklyPerformance(
            userId: entry.key,
            stats: entry.value,
            eventDate: eventDate,
            participantCount: eventStats.length,
          ),
        )
        .toList();
    standings.sort((a, b) {
      final byPoints = b.stats.matchPoints.compareTo(a.stats.matchPoints);
      if (byPoints != 0) return byPoints;
      final byWins = b.stats.wins.compareTo(a.stats.wins);
      if (byWins != 0) return byWins;
      final byGames = b.stats.games.compareTo(a.stats.games);
      if (byGames != 0) return byGames;
      return a.stats.playerDisplayName.compareTo(b.stats.playerDisplayName);
    });
    for (var index = 0; index < standings.length; index++) {
      standings[index].rank = index + 1;
    }
    return standings;
  }

  int _compareMonthlyRankingEntries(
    MonthlyRankingEntry a,
    MonthlyRankingEntry b,
  ) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    final byFirstPlaces = b.firstPlaces.compareTo(a.firstPlaces);
    if (byFirstPlaces != 0) return byFirstPlaces;
    final bySecondPlaces = b.secondPlaces.compareTo(a.secondPlaces);
    if (bySecondPlaces != 0) return bySecondPlaces;
    final byTop4 = b.top4Finishes.compareTo(a.top4Finishes);
    if (byTop4 != 0) return byTop4;
    final aLastRank = a.lastWeeklyRank ?? 999;
    final bLastRank = b.lastWeeklyRank ?? 999;
    final byLastWeekly = aLastRank.compareTo(bLastRank);
    if (byLastWeekly != 0) return byLastWeekly;
    return a.playerDisplayName.compareTo(b.playerDisplayName);
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _rankingWeekKey(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return _dateOnly(DateTime(weekStart.year, weekStart.month, weekStart.day));
  }
}

int weeklyPlacementPoints(int placement) {
  return switch (placement) {
    1 => 100,
    2 => 80,
    3 => 65,
    4 => 55,
    5 => 45,
    6 => 38,
    7 => 32,
    8 => 27,
    9 => 23,
    10 => 20,
    _ => 15,
  };
}

int weeklyParticipantBonus(int participantCount) {
  return switch (participantCount) {
    >= 16 => 15,
    >= 12 => 10,
    >= 8 => 5,
    _ => 0,
  };
}

class _RankingAccumulator {
  final String playerDisplayName;
  final String playerNickname;
  final Map<String, int> _deckUses = {};
  final Map<String, _OpponentDeckAccumulator> _opponentDecks = {};
  final List<int> _weeklyScores = [];
  int rankingPoints = 0;
  int firstPlaces = 0;
  int secondPlaces = 0;
  int top4Finishes = 0;
  int? lastWeeklyRank;
  int wins = 0;
  int draws = 0;
  int losses = 0;

  _RankingAccumulator({
    required this.playerDisplayName,
    required this.playerNickname,
  });

  void addDeck(String deckName) {
    _deckUses.update(deckName, (count) => count + 1, ifAbsent: () => 1);
  }

  void addOpponentDeck(String deckName, _MatchOutcome outcome) {
    _opponentDecks
        .putIfAbsent(deckName, _OpponentDeckAccumulator.new)
        .add(outcome);
  }

  int get games => wins + draws + losses;
  int get matchPoints => (wins * 3) + draws;

  void applyWeeklyPerformance(
    _WeeklyPerformance performance, {
    required int weekScore,
    required int weekIndex,
    required bool isLastWeek,
  }) {
    while (_weeklyScores.length <= weekIndex) {
      _weeklyScores.add(0);
    }
    _weeklyScores[weekIndex] = weekScore;
    rankingPoints += weekScore;
    if (performance.rank == 1) firstPlaces++;
    if (performance.rank == 2) secondPlaces++;
    if (performance.rank <= 4) top4Finishes++;
    if (isLastWeek) lastWeeklyRank = performance.rank;
    mergeMatchStats(performance.stats);
  }

  void mergeMatchStats(_RankingAccumulator other) {
    wins += other.wins;
    draws += other.draws;
    losses += other.losses;
    for (final entry in other._deckUses.entries) {
      _deckUses.update(
        entry.key,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    for (final entry in other._opponentDecks.entries) {
      _opponentDecks
          .putIfAbsent(entry.key, _OpponentDeckAccumulator.new)
          .merge(entry.value);
    }
  }

  MonthlyRankingEntry toEntry(String userId) {
    final decks = _deckUses.entries.toList()
      ..sort((a, b) {
        final byUses = b.value.compareTo(a.value);
        return byUses != 0 ? byUses : a.key.compareTo(b.key);
      });
    return MonthlyRankingEntry(
      userId: userId,
      playerDisplayName: playerDisplayName,
      playerNickname: playerNickname,
      rankingPoints: rankingPoints,
      weeklyScores: List.unmodifiable(_weeklyScores),
      firstPlaces: firstPlaces,
      secondPlaces: secondPlaces,
      top4Finishes: top4Finishes,
      lastWeeklyRank: lastWeeklyRank,
      games: games,
      wins: wins,
      draws: draws,
      losses: losses,
      deckUsage: decks
          .map(
            (entry) => WeeklyDeckUsage(deckName: entry.key, games: entry.value),
          )
          .toList(growable: false),
      opponentDeckStats: _buildOpponentDeckStats(),
    );
  }

  List<WeeklyOpponentDeckStats> _buildOpponentDeckStats() {
    final entries = _opponentDecks.entries
        .map((entry) => entry.value.toStats(entry.key))
        .toList();
    entries.sort((a, b) {
      final byGames = b.games.compareTo(a.games);
      return byGames != 0 ? byGames : a.deckName.compareTo(b.deckName);
    });
    return entries;
  }
}

enum _MatchOutcome { win, draw, loss }

class _WeeklyPerformance {
  final String userId;
  final _RankingAccumulator stats;
  final DateTime eventDate;
  final int participantCount;
  int rank = 0;

  _WeeklyPerformance({
    required this.userId,
    required this.stats,
    required this.eventDate,
    required this.participantCount,
  });
}

class _OpponentDeckAccumulator {
  int wins = 0;
  int draws = 0;
  int losses = 0;

  void merge(_OpponentDeckAccumulator other) {
    wins += other.wins;
    draws += other.draws;
    losses += other.losses;
  }

  void add(_MatchOutcome outcome) {
    switch (outcome) {
      case _MatchOutcome.win:
        wins++;
      case _MatchOutcome.draw:
        draws++;
      case _MatchOutcome.loss:
        losses++;
    }
  }

  WeeklyOpponentDeckStats toStats(String deckName) {
    return WeeklyOpponentDeckStats(
      deckName: deckName,
      games: wins + draws + losses,
      wins: wins,
      draws: draws,
      losses: losses,
    );
  }
}
