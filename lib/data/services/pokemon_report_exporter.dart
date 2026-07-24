import '../models/pokemon_tdf_report.dart';
import 'pokemon_report_csv.dart';
import 'pokemon_weekly_circuit.dart';
import 'pokemon_report_exporter_io.dart'
    if (dart.library.html) 'pokemon_report_exporter_web.dart';

Future<void> exportPokemonReportCsv(PokemonTournamentReport report) {
  return savePokemonReportCsv(
    fileName: pokemonReportCsvFileName(report),
    csv: buildPokemonReportCsv(report),
  );
}

Future<void> exportPokemonCircuitRankingCsv({
  required PokemonWeeklyCircuit circuit,
  required List<PokemonTournamentReport> reports,
}) {
  return savePokemonReportCsv(
    fileName: pokemonCircuitRankingCsvFileName(circuit),
    csv: buildPokemonCircuitRankingCsv(circuit: circuit, reports: reports),
  );
}
