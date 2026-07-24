import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/pokemon_tdf_report.dart';
import 'package:optcg_manager/data/services/pokemon_report_csv.dart';

void main() {
  test('exports tournament metadata, standings and rounds', () {
    final csv = buildPokemonReportCsv(_report());

    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('"Torneio";"Semanal STOP TCG"'));
    expect(csv, contains('"CLASSIFICACAO"'));
    expect(csv, contains('"RODADAS"'));
    expect(csv, contains('"Ash ""Red"""'));
    expect(csv.toLowerCase(), isNot(contains('birthdate')));
  });

  test('protects spreadsheet cells from formula injection', () {
    final csv = buildPokemonReportCsv(_report(playerName: '=HYPERLINK("bad")'));

    expect(csv, contains('"\'=HYPERLINK(""bad"")"'));
  });

  test('creates a stable CSV filename', () {
    expect(
      pokemonReportCsvFileName(_report()),
      '20260502_semanal-stop-tcg.csv',
    );
  });
}

PokemonTournamentReport _report({String playerName = 'Ash "Red"'}) {
  return PokemonTournamentReport(
    sourceKey: '20260502-semanal-2',
    sourceFileName: 'semanal.tdf',
    name: 'Semanal STOP TCG',
    eventDate: DateTime(2026, 5, 2),
    city: 'Belo Horizonte',
    state: 'MG',
    country: 'Brasil',
    organizerName: 'Professor Oak',
    roundTimeMinutes: 50,
    finalsRoundTimeMinutes: 75,
    elapsedSeconds: 3600,
    softwareVersion: '1.82',
    players: [
      PokemonTournamentPlayer(
        playerId: '1',
        name: playerName,
        category: 2,
        placement: 1,
        droppedRound: null,
        wins: 1,
        draws: 0,
        losses: 0,
        byes: 0,
      ),
      const PokemonTournamentPlayer(
        playerId: '2',
        name: 'Misty',
        category: 2,
        placement: 2,
        droppedRound: null,
        wins: 0,
        draws: 0,
        losses: 1,
        byes: 0,
      ),
    ],
    rounds: const [
      PokemonTournamentRound(
        number: 1,
        startedAt: null,
        matches: [
          PokemonTournamentMatch(
            tableNumber: 1,
            playerOneId: '1',
            playerTwoId: '2',
            outcome: 'player_one',
          ),
        ],
      ),
    ],
  );
}
