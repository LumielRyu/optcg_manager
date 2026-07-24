import '../models/pokemon_tdf_report.dart';

enum PokemonWeeklyCircuit { thursday, saturday, other }

extension PokemonWeeklyCircuitLabel on PokemonWeeklyCircuit {
  String get label => switch (this) {
    PokemonWeeklyCircuit.thursday => 'Quinta-feira',
    PokemonWeeklyCircuit.saturday => 'Sabado',
    PokemonWeeklyCircuit.other => 'Outras datas',
  };

  String get slug => switch (this) {
    PokemonWeeklyCircuit.thursday => 'quinta',
    PokemonWeeklyCircuit.saturday => 'sabado',
    PokemonWeeklyCircuit.other => 'outras-datas',
  };
}

PokemonWeeklyCircuit pokemonCircuitForDate(DateTime date) =>
    switch (date.weekday) {
      DateTime.thursday => PokemonWeeklyCircuit.thursday,
      DateTime.saturday => PokemonWeeklyCircuit.saturday,
      _ => PokemonWeeklyCircuit.other,
    };

bool pokemonReportBelongsToCircuit(
  PokemonTournamentReport report,
  PokemonWeeklyCircuit circuit,
) => pokemonCircuitForDate(report.eventDate) == circuit;

List<PokemonTournamentPlayer> sortPokemonUnifiedStandings(
  Iterable<PokemonTournamentPlayer> players,
) {
  final sorted = players.toList(growable: false);
  sorted.sort((a, b) {
    final points = b.matchPoints.compareTo(a.matchPoints);
    if (points != 0) return points;
    final wins = b.wins.compareTo(a.wins);
    if (wins != 0) return wins;
    final draws = b.draws.compareTo(a.draws);
    if (draws != 0) return draws;
    final losses = a.losses.compareTo(b.losses);
    if (losses != 0) return losses;
    final placement = (a.placement ?? 999).compareTo(b.placement ?? 999);
    if (placement != 0) return placement;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

class PokemonCircuitRankingEntry {
  final String playerId;
  final String name;
  final int category;
  final int tournaments;
  final int wins;
  final int draws;
  final int losses;
  final int byes;
  final int matchPoints;
  final int? bestPlacement;

  const PokemonCircuitRankingEntry({
    required this.playerId,
    required this.name,
    required this.category,
    required this.tournaments,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.byes,
    required this.matchPoints,
    required this.bestPlacement,
  });
}

List<PokemonCircuitRankingEntry> buildPokemonCircuitRanking(
  Iterable<PokemonTournamentReport> reports,
) {
  final accumulators = <String, _RankingAccumulator>{};
  for (final report in reports) {
    for (final player in report.players) {
      final normalizedName = player.name.trim().toLowerCase();
      final key = player.playerId.trim().isEmpty
          ? 'name:$normalizedName'
          : 'id:${player.playerId.trim()}';
      accumulators
          .putIfAbsent(
            key,
            () => _RankingAccumulator(
              playerId: player.playerId,
              name: player.name,
              category: player.category,
            ),
          )
          .add(player);
    }
  }

  final ranking = accumulators.values.map((item) => item.freeze()).toList();
  ranking.sort((a, b) {
    final points = b.matchPoints.compareTo(a.matchPoints);
    if (points != 0) return points;
    final wins = b.wins.compareTo(a.wins);
    if (wins != 0) return wins;
    final placement = (a.bestPlacement ?? 999).compareTo(
      b.bestPlacement ?? 999,
    );
    if (placement != 0) return placement;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return ranking;
}

class _RankingAccumulator {
  final String playerId;
  String name;
  int category;
  int tournaments = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int byes = 0;
  int? bestPlacement;

  _RankingAccumulator({
    required this.playerId,
    required this.name,
    required this.category,
  });

  void add(PokemonTournamentPlayer player) {
    tournaments++;
    wins += player.wins;
    draws += player.draws;
    losses += player.losses;
    byes += player.byes;
    name = player.name;
    category = player.category;
    final placement = player.placement;
    if (placement != null &&
        (bestPlacement == null || placement < bestPlacement!)) {
      bestPlacement = placement;
    }
  }

  PokemonCircuitRankingEntry freeze() => PokemonCircuitRankingEntry(
    playerId: playerId,
    name: name,
    category: category,
    tournaments: tournaments,
    wins: wins,
    draws: draws,
    losses: losses,
    byes: byes,
    matchPoints: (wins * 3) + draws,
    bestPlacement: bestPlacement,
  );
}
