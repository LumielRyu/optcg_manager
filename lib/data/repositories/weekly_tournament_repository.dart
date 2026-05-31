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
      ranking: _buildRanking(participants, matches),
      profiles: supportingData[0] as List<WeeklyPlayerProfile>,
      currentGameProfile: supportingData[1] as WeeklyGameProfile?,
      leaders: supportingData[2] as List<WeeklyLeaderOption>,
    );
  }

  Future<WeeklyGameProfile?> _loadCurrentGameProfile(String gameSlug) async {
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
    List<WeeklyParticipant> participants,
    List<WeeklyMatch> matches,
  ) {
    final participantsById = {
      for (final participant in participants) participant.id: participant,
    };
    final stats = <String, _RankingAccumulator>{};

    for (final participant in participants) {
      stats
          .putIfAbsent(
            participant.userId,
            () => _RankingAccumulator(participant.playerName),
          )
          .addDeck(participant.deckName);
    }

    for (final match in matches.where((item) => item.isCompleted)) {
      final one = participantsById[match.playerOneId];
      final two = participantsById[match.playerTwoId];
      if (one == null) continue;
      final oneStats = stats[one.userId]!;
      if (match.isBye) {
        oneStats.wins++;
        continue;
      }
      if (two == null) continue;
      final twoStats = stats[two.userId]!;
      if (match.result == 'draw') {
        oneStats.draws++;
        twoStats.draws++;
      } else if (match.result == 'player_one') {
        oneStats.wins++;
        twoStats.losses++;
      } else if (match.result == 'player_two') {
        twoStats.wins++;
        oneStats.losses++;
      }
    }

    final ranking = stats.entries
        .map((entry) => entry.value.toEntry(entry.key))
        .toList();
    ranking.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byWins = b.wins.compareTo(a.wins);
      if (byWins != 0) return byWins;
      return a.playerName.compareTo(b.playerName);
    });
    return ranking;
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _RankingAccumulator {
  final String playerName;
  final Map<String, int> _deckUses = {};
  int wins = 0;
  int draws = 0;
  int losses = 0;

  _RankingAccumulator(this.playerName);

  void addDeck(String deckName) {
    _deckUses.update(deckName, (count) => count + 1, ifAbsent: () => 1);
  }

  MonthlyRankingEntry toEntry(String userId) {
    final decks = _deckUses.entries.toList()
      ..sort((a, b) {
        final byUses = b.value.compareTo(a.value);
        return byUses != 0 ? byUses : a.key.compareTo(b.key);
      });
    return MonthlyRankingEntry(
      userId: userId,
      playerName: playerName,
      games: wins + draws + losses,
      wins: wins,
      draws: draws,
      losses: losses,
      topDecks: decks.take(3).map((entry) => entry.key).toList(growable: false),
    );
  }
}
