import '../models/one_piece_standings_report.dart';

class OnePieceMonthlyRanking {
  final DateTime month;
  final List<OnePieceMonthlyPlayerEntry> players;
  final List<OnePieceLeaderRankingEntry> leaders;
  final int identifiedDeckEntries;
  final int totalDeckEntries;

  const OnePieceMonthlyRanking({
    required this.month,
    required this.players,
    required this.leaders,
    required this.identifiedDeckEntries,
    required this.totalDeckEntries,
  });

  double get leaderCoverage => totalDeckEntries == 0
      ? 0
      : identifiedDeckEntries * 100 / totalDeckEntries;
}

class OnePieceMonthlyPlayerEntry {
  final String playerId;
  final String name;
  final int tournaments;
  final int winPoints;
  final int wins;
  final int? bestPlacement;
  final double averageOmw;

  const OnePieceMonthlyPlayerEntry({
    required this.playerId,
    required this.name,
    required this.tournaments,
    required this.winPoints,
    required this.wins,
    required this.bestPlacement,
    required this.averageOmw,
  });
}

class OnePieceLeaderRankingEntry {
  final String leaderCode;
  final String leaderName;
  final int uses;
  final int wins;
  final int games;

  const OnePieceLeaderRankingEntry({
    required this.leaderCode,
    required this.leaderName,
    required this.uses,
    required this.wins,
    required this.games,
  });

  int get losses => games > wins ? games - wins : 0;
  double get winRate => games == 0 ? 0 : wins * 100 / games;
  String get label =>
      leaderCode.isEmpty ? leaderName : '$leaderName ($leaderCode)';
}

OnePieceMonthlyRanking buildOnePieceMonthlyRanking(
  Iterable<OnePieceStandingsReport> reports, {
  required DateTime month,
}) {
  final playerAccumulators = <String, _PlayerAccumulator>{};
  final leaderAccumulators = <String, _LeaderAccumulator>{};
  var identifiedDeckEntries = 0;
  var totalDeckEntries = 0;

  for (final report in reports.where(
    (item) =>
        item.eventDate.year == month.year &&
        item.eventDate.month == month.month,
  )) {
    for (final player in report.players) {
      totalDeckEntries++;
      final normalizedName = player.userName.trim().toLowerCase();
      final playerKey = player.membershipNumber.trim().isEmpty
          ? 'name:$normalizedName'
          : 'id:${player.membershipNumber.trim()}';
      playerAccumulators
          .putIfAbsent(
            playerKey,
            () => _PlayerAccumulator(
              playerId: player.membershipNumber.trim(),
              name: player.userName.trim(),
            ),
          )
          .add(player);

      if (!player.hasLeader) continue;
      identifiedDeckEntries++;
      final code = player.leaderCode.trim().toUpperCase();
      final name = player.leaderName.trim();
      final leaderKey = code.isNotEmpty
          ? 'code:$code'
          : 'name:${name.toLowerCase()}';
      leaderAccumulators
          .putIfAbsent(
            leaderKey,
            () => _LeaderAccumulator(leaderCode: code, leaderName: name),
          )
          .add(player, games: report.effectiveRoundCount);
    }
  }

  final players = playerAccumulators.values
      .map((item) => item.freeze())
      .toList();
  players.sort((a, b) {
    final byPoints = b.winPoints.compareTo(a.winPoints);
    if (byPoints != 0) return byPoints;
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byPlacement = (a.bestPlacement ?? 999).compareTo(
      b.bestPlacement ?? 999,
    );
    if (byPlacement != 0) return byPlacement;
    final byOmw = b.averageOmw.compareTo(a.averageOmw);
    if (byOmw != 0) return byOmw;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  final leaders = leaderAccumulators.values
      .map((item) => item.freeze())
      .toList();
  leaders.sort((a, b) {
    final byRate = b.winRate.compareTo(a.winRate);
    if (byRate != 0) return byRate;
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byUses = b.uses.compareTo(a.uses);
    if (byUses != 0) return byUses;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

  return OnePieceMonthlyRanking(
    month: DateTime(month.year, month.month),
    players: List.unmodifiable(players),
    leaders: List.unmodifiable(leaders),
    identifiedDeckEntries: identifiedDeckEntries,
    totalDeckEntries: totalDeckEntries,
  );
}

class _PlayerAccumulator {
  final String playerId;
  String name;
  int tournaments = 0;
  int winPoints = 0;
  int wins = 0;
  int? bestPlacement;
  double omwTotal = 0;

  _PlayerAccumulator({required this.playerId, required this.name});

  void add(OnePieceStandingPlayer player) {
    tournaments++;
    winPoints += player.winPoints;
    wins += player.wins;
    omwTotal += player.omwPercentage;
    name = player.userName.trim();
    if (bestPlacement == null || player.ranking < bestPlacement!) {
      bestPlacement = player.ranking;
    }
  }

  OnePieceMonthlyPlayerEntry freeze() => OnePieceMonthlyPlayerEntry(
    playerId: playerId,
    name: name,
    tournaments: tournaments,
    winPoints: winPoints,
    wins: wins,
    bestPlacement: bestPlacement,
    averageOmw: tournaments == 0 ? 0 : omwTotal / tournaments,
  );
}

class _LeaderAccumulator {
  final String leaderCode;
  String leaderName;
  int uses = 0;
  int wins = 0;
  int games = 0;

  _LeaderAccumulator({required this.leaderCode, required this.leaderName});

  void add(OnePieceStandingPlayer player, {required int games}) {
    uses++;
    wins += player.wins;
    this.games += games;
    if (player.leaderName.trim().isNotEmpty) {
      leaderName = player.leaderName.trim();
    }
  }

  OnePieceLeaderRankingEntry freeze() => OnePieceLeaderRankingEntry(
    leaderCode: leaderCode,
    leaderName: leaderName,
    uses: uses,
    wins: wins,
    games: games,
  );
}
