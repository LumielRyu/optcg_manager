import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/pokemon_tdf_report.dart';
import 'package:optcg_manager/data/services/pokemon_tdf_validator.dart';

void main() {
  const validator = PokemonTdfValidator();

  test('accepts a complete tournament without warnings', () {
    final result = validator.validate(_report(), now: DateTime(2026, 5, 3));

    expect(result.canImport, isTrue);
    expect(result.issues, isEmpty);
  });

  test('blocks a report without players and matches', () {
    final result = validator.validate(
      _report(players: const [], rounds: const []),
      now: DateTime(2026, 5, 3),
    );

    expect(result.canImport, isFalse);
    expect(
      result.errors.map((issue) => issue.code),
      containsAll(['no-players', 'no-matches']),
    );
  });

  test('warns about incomplete standings and unknown results', () {
    final result = validator.validate(
      _report(
        players: const [
          PokemonTournamentPlayer(
            playerId: '1',
            name: 'Ash',
            category: 2,
            placement: null,
            droppedRound: null,
            wins: 0,
            draws: 0,
            losses: 0,
            byes: 0,
          ),
          PokemonTournamentPlayer(
            playerId: '2',
            name: 'Misty',
            category: 2,
            placement: 1,
            droppedRound: null,
            wins: 0,
            draws: 0,
            losses: 0,
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
                outcome: 'unknown',
              ),
            ],
          ),
        ],
      ),
      now: DateTime(2026, 5, 3),
    );

    expect(result.canImport, isTrue);
    expect(
      result.warnings.map((issue) => issue.code),
      containsAll(['unknown-results', 'missing-placements']),
    );
  });
}

PokemonTournamentReport _report({
  List<PokemonTournamentPlayer>? players,
  List<PokemonTournamentRound>? rounds,
}) {
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
    players:
        players ??
        const [
          PokemonTournamentPlayer(
            playerId: '1',
            name: 'Ash',
            category: 2,
            placement: 1,
            droppedRound: null,
            wins: 1,
            draws: 0,
            losses: 0,
            byes: 0,
          ),
          PokemonTournamentPlayer(
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
    rounds:
        rounds ??
        const [
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
