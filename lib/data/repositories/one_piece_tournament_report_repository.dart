import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/one_piece_standings_report.dart';
import '../services/supabase_client_provider.dart';

final onePieceTournamentReportRepositoryProvider =
    Provider<OnePieceTournamentReportRepository>(
      (ref) =>
          OnePieceTournamentReportRepository(ref.watch(supabaseClientProvider)),
    );

class StoredOnePieceTournamentReport {
  final String id;
  final DateTime importedAt;
  final OnePieceStandingsReport report;

  const StoredOnePieceTournamentReport({
    required this.id,
    required this.importedAt,
    required this.report,
  });

  factory StoredOnePieceTournamentReport.fromJson(Map<String, dynamic> json) =>
      StoredOnePieceTournamentReport(
        id: json['id'].toString(),
        importedAt: DateTime.parse(json['created_at'].toString()),
        report: OnePieceStandingsReport.fromJson(
          Map<String, dynamic>.from(json['report_data'] as Map),
        ),
      );
}

class OnePieceTournamentReportRepository {
  final SupabaseClient _client;

  OnePieceTournamentReportRepository(this._client);

  bool get isAdmin {
    final value = _client.auth.currentUser?.appMetadata['is_weekly_admin'];
    return value == true || value?.toString() == 'true';
  }

  Future<List<StoredOnePieceTournamentReport>> loadReports() async {
    final rows = await _client
        .from('one_piece_tournament_reports')
        .select('id, created_at, report_data')
        .order('event_date', ascending: false);
    return rows
        .map((row) => StoredOnePieceTournamentReport.fromJson(row))
        .toList(growable: false);
  }

  Future<StoredOnePieceTournamentReport?> findBySourceKey(
    String sourceKey,
  ) async {
    final row = await _client
        .from('one_piece_tournament_reports')
        .select('id, created_at, report_data')
        .eq('source_key', sourceKey)
        .maybeSingle();
    return row == null ? null : StoredOnePieceTournamentReport.fromJson(row);
  }

  Future<void> saveReport(OnePieceStandingsReport report) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || !isAdmin) {
      throw Exception(
        'Apenas administradores dos semanais podem importar resultados.',
      );
    }
    await _client.from('one_piece_tournament_reports').upsert({
      'source_key': report.sourceKey,
      'source_file_name': report.sourceFileName,
      'event_name': report.eventName,
      'event_date': _dateOnly(report.eventDate),
      'participant_count': report.participantCount,
      'report_data': report.toJson(),
      'created_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'source_key');
  }

  Future<void> deleteReport(String id) async {
    if (!isAdmin) {
      throw Exception('Apenas administradores podem excluir relatorios.');
    }
    await _client.from('one_piece_tournament_reports').delete().eq('id', id);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
