import '../models/pokemon_tdf_report.dart';

enum PokemonTdfIssueSeverity { warning, error }

class PokemonTdfValidationIssue {
  final String code;
  final String message;
  final PokemonTdfIssueSeverity severity;

  const PokemonTdfValidationIssue({
    required this.code,
    required this.message,
    required this.severity,
  });
}

class PokemonTdfValidationResult {
  final List<PokemonTdfValidationIssue> issues;

  const PokemonTdfValidationResult(this.issues);

  List<PokemonTdfValidationIssue> get errors => issues
      .where((issue) => issue.severity == PokemonTdfIssueSeverity.error)
      .toList(growable: false);

  List<PokemonTdfValidationIssue> get warnings => issues
      .where((issue) => issue.severity == PokemonTdfIssueSeverity.warning)
      .toList(growable: false);

  bool get canImport => errors.isEmpty;
}

class PokemonTdfValidator {
  const PokemonTdfValidator();

  PokemonTdfValidationResult validate(
    PokemonTournamentReport report, {
    DateTime? now,
  }) {
    final issues = <PokemonTdfValidationIssue>[];

    void add(String code, String message, PokemonTdfIssueSeverity severity) {
      issues.add(
        PokemonTdfValidationIssue(
          code: code,
          message: message,
          severity: severity,
        ),
      );
    }

    if (report.players.isEmpty) {
      add(
        'no-players',
        'O arquivo não contém jogadores válidos.',
        PokemonTdfIssueSeverity.error,
      );
    }
    if (report.rounds.isEmpty || report.matchCount == 0) {
      add(
        'no-matches',
        'O arquivo não contém rodadas com confrontos.',
        PokemonTdfIssueSeverity.error,
      );
    }

    final playerIds = report.players.map((player) => player.playerId).toSet();
    var unknownPlayers = 0;
    var repeatedPlayers = 0;
    var selfMatches = 0;
    var emptyRounds = 0;
    for (final round in report.rounds) {
      if (round.matches.isEmpty) emptyRounds++;
      final playersInRound = <String>{};
      for (final match in round.matches) {
        if (!playerIds.contains(match.playerOneId) ||
            (match.playerTwoId != null &&
                !playerIds.contains(match.playerTwoId))) {
          unknownPlayers++;
        }
        if (match.playerTwoId != null &&
            match.playerOneId == match.playerTwoId) {
          selfMatches++;
        }
        if (!playersInRound.add(match.playerOneId)) repeatedPlayers++;
        final playerTwoId = match.playerTwoId;
        if (playerTwoId != null && !playersInRound.add(playerTwoId)) {
          repeatedPlayers++;
        }
      }
    }

    if (unknownPlayers > 0) {
      add(
        'unknown-player',
        '$unknownPlayers confronto(s) referenciam jogadores ausentes.',
        PokemonTdfIssueSeverity.error,
      );
    }
    if (selfMatches > 0) {
      add(
        'self-match',
        '$selfMatches confronto(s) possuem o mesmo jogador nos dois lados.',
        PokemonTdfIssueSeverity.error,
      );
    }
    if (repeatedPlayers > 0) {
      add(
        'repeated-player-in-round',
        '$repeatedPlayers ocorrência(s) de jogador repetido na mesma rodada.',
        PokemonTdfIssueSeverity.error,
      );
    }
    if (emptyRounds > 0) {
      add(
        'empty-rounds',
        '$emptyRounds rodada(s) não possuem confrontos.',
        PokemonTdfIssueSeverity.warning,
      );
    }

    final unknownResults = report.matchCount - report.completedMatchCount;
    if (unknownResults > 0) {
      add(
        'unknown-results',
        '$unknownResults confronto(s) ainda estão sem resultado reconhecido.',
        PokemonTdfIssueSeverity.warning,
      );
    }

    final missingPlacements = report.players
        .where((player) => player.placement == null)
        .length;
    if (missingPlacements > 0) {
      add(
        'missing-placements',
        '$missingPlacements jogador(es) não possuem classificação final.',
        PokemonTdfIssueSeverity.warning,
      );
    }

    final today = now ?? DateTime.now();
    final tomorrow = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));
    if (report.eventDate.isAfter(tomorrow)) {
      add(
        'future-date',
        'A data do torneio está no futuro. Confirme a data no TDF.',
        PokemonTdfIssueSeverity.warning,
      );
    }

    return PokemonTdfValidationResult(List.unmodifiable(issues));
  }
}
