import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/pokemon_tdf_report.dart';
import 'package:optcg_manager/data/services/pokemon_report_csv.dart';
import 'package:optcg_manager/data/services/pokemon_weekly_circuit.dart';

void main() {
  test('classifies Thursday and Saturday as separate circuits', () {
    expect(
      pokemonCircuitForDate(DateTime(2026, 7, 16)),
      PokemonWeeklyCircuit.thursday,
    );
    expect(
      pokemonCircuitForDate(DateTime(2026, 7, 18)),
      PokemonWeeklyCircuit.saturday,
    );
    expect(
      pokemonCircuitForDate(DateTime(2026, 7, 17)),
      PokemonWeeklyCircuit.other,
    );
  });

  test('builds an independent accumulated ranking per report list', () {
    final ranking = buildPokemonCircuitRanking([
      _report(DateTime(2026, 7, 16), ashWins: 2, mistyWins: 1),
      _report(DateTime(2026, 7, 23), ashWins: 1, mistyWins: 3),
    ]);

    expect(ranking.first.name, 'Misty');
    expect(ranking.first.matchPoints, 12);
    expect(ranking.first.tournaments, 2);
    expect(ranking[1].matchPoints, 9);
  });

  test('points from Saturday never enter the Thursday ranking', () {
    final reports = [
      _report(DateTime(2026, 7, 16), ashWins: 2, mistyWins: 0),
      _report(DateTime(2026, 7, 18), ashWins: 20, mistyWins: 10),
    ];
    final thursdayRanking = buildPokemonCircuitRanking(
      reports.where(
        (report) => pokemonReportBelongsToCircuit(
          report,
          PokemonWeeklyCircuit.thursday,
        ),
      ),
    );

    expect(thursdayRanking.first.name, 'Ash');
    expect(thursdayRanking.first.matchPoints, 6);
    expect(thursdayRanking.first.tournaments, 1);
  });

  test('unified final standings are ordered by actual performance', () {
    final report = _report(DateTime(2026, 7, 18), ashWins: 2, mistyWins: 4);
    final sorted = sortPokemonUnifiedStandings(report.players);

    expect(sorted.first.name, 'Misty');
    expect(sorted.first.matchPoints, 12);
    expect(sorted.last.name, 'Ash');
  });

  test('exports only the supplied circuit reports', () {
    final csv = buildPokemonCircuitRankingCsv(
      circuit: PokemonWeeklyCircuit.thursday,
      reports: [_report(DateTime(2026, 7, 16), ashWins: 2, mistyWins: 1)],
    );

    expect(csv, contains('"Circuito";"Quinta-feira"'));
    expect(csv, contains('"Torneios contabilizados";"1"'));
    expect(csv, contains('"RANKING ACUMULADO"'));
    expect(
      pokemonCircuitRankingCsvFileName(PokemonWeeklyCircuit.saturday),
      'ranking_pokemon_sabado.csv',
    );
  });
}

PokemonTournamentReport _report(
  DateTime date, {
  required int ashWins,
  required int mistyWins,
}) => PokemonTournamentReport(
  sourceKey: date.toIso8601String(),
  sourceFileName: 'semanal.tdf',
  name: 'Semanal STOP TCG',
  eventDate: date,
  city: 'Belo Horizonte',
  state: 'MG',
  country: 'Brasil',
  organizerName: 'STOP TCG',
  roundTimeMinutes: 50,
  finalsRoundTimeMinutes: 75,
  elapsedSeconds: 0,
  softwareVersion: '1.0',
  players: [
    PokemonTournamentPlayer(
      playerId: 'ash',
      name: 'Ash',
      category: 2,
      placement: 1,
      droppedRound: null,
      wins: ashWins,
      draws: 0,
      losses: 0,
      byes: 0,
    ),
    PokemonTournamentPlayer(
      playerId: 'misty',
      name: 'Misty',
      category: 2,
      placement: 2,
      droppedRound: null,
      wins: mistyWins,
      draws: 0,
      losses: 0,
      byes: 0,
    ),
  ],
  rounds: const [],
);
