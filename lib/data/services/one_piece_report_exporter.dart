import '../models/one_piece_standings_report.dart';
import 'one_piece_report_csv.dart';
import 'one_piece_report_exporter_io.dart'
    if (dart.library.html) 'one_piece_report_exporter_web.dart';

Future<void> exportOnePieceReportCsv(OnePieceStandingsReport report) =>
    saveOnePieceReportCsv(
      fileName: onePieceReportCsvFileName(report),
      csv: buildOnePieceReportCsv(report),
    );
