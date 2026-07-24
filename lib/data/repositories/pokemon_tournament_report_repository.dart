import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pokemon_tdf_report.dart';
import '../services/supabase_client_provider.dart';

final pokemonTournamentReportRepositoryProvider =
    Provider<PokemonTournamentReportRepository>(
      (ref) =>
          PokemonTournamentReportRepository(ref.watch(supabaseClientProvider)),
    );

class StoredPokemonTournamentReport {
  final String id;
  final DateTime importedAt;
  final DateTime updatedAt;
  final PokemonTournamentReport report;

  const StoredPokemonTournamentReport({
    required this.id,
    required this.importedAt,
    required this.updatedAt,
    required this.report,
  });

  factory StoredPokemonTournamentReport.fromJson(Map<String, dynamic> json) {
    final importedAt = DateTime.parse(json['created_at'].toString());
    return StoredPokemonTournamentReport(
      id: json['id'].toString(),
      importedAt: importedAt,
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          importedAt,
      report: PokemonTournamentReport.fromJson(
        Map<String, dynamic>.from(json['report_data'] as Map),
      ),
    );
  }
}

class PokemonTournamentReportAuditEntry {
  final int id;
  final String reportId;
  final String action;
  final DateTime changedAt;
  final String sourceKey;
  final PokemonTournamentReport? previousReport;
  final PokemonTournamentReport? newReport;

  const PokemonTournamentReportAuditEntry({
    required this.id,
    required this.reportId,
    required this.action,
    required this.changedAt,
    required this.sourceKey,
    required this.previousReport,
    required this.newReport,
  });

  bool get canRestore => previousReport != null;

  factory PokemonTournamentReportAuditEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    PokemonTournamentReport? reportFromSnapshot(dynamic snapshot) {
      if (snapshot is! Map) return null;
      final reportData = snapshot['report_data'];
      if (reportData is! Map) return null;
      return PokemonTournamentReport.fromJson(
        Map<String, dynamic>.from(reportData),
      );
    }

    return PokemonTournamentReportAuditEntry(
      id: int.parse(json['id'].toString()),
      reportId: json['report_id'].toString(),
      action: json['action'].toString(),
      changedAt: DateTime.parse(json['changed_at'].toString()),
      sourceKey: json['source_key'].toString(),
      previousReport: reportFromSnapshot(json['previous_data']),
      newReport: reportFromSnapshot(json['new_data']),
    );
  }
}

class PokemonTournamentReportRepository {
  final SupabaseClient _client;

  PokemonTournamentReportRepository(this._client);

  bool get isAdmin {
    final value = _client.auth.currentUser?.appMetadata['is_weekly_admin'];
    return value == true || value?.toString() == 'true';
  }

  Future<List<StoredPokemonTournamentReport>> loadReports() async {
    final rows = await _client
        .from('pokemon_tournament_reports')
        .select('id, created_at, updated_at, report_data')
        .order('event_date', ascending: false);
    return rows
        .map((row) => StoredPokemonTournamentReport.fromJson(row))
        .toList(growable: false);
  }

  Future<StoredPokemonTournamentReport?> findBySourceKey(
    String sourceKey,
  ) async {
    final row = await _client
        .from('pokemon_tournament_reports')
        .select('id, created_at, updated_at, report_data')
        .eq('source_key', sourceKey)
        .maybeSingle();
    return row == null ? null : StoredPokemonTournamentReport.fromJson(row);
  }

  Future<void> saveReport(PokemonTournamentReport report) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || !isAdmin) {
      throw Exception(
        'Apenas administradores dos semanais podem importar TDF.',
      );
    }
    await _client.from('pokemon_tournament_reports').upsert({
      'source_key': report.sourceKey,
      'source_file_name': report.sourceFileName,
      'event_name': report.name,
      'event_date': _dateOnly(report.eventDate),
      'participant_count': report.participantCount,
      'round_count': report.roundCount,
      'match_count': report.matchCount,
      'report_data': report.toJson(),
      'created_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'source_key');
  }

  Future<void> deleteReport(String id) async {
    await _client.from('pokemon_tournament_reports').delete().eq('id', id);
  }

  Future<List<PokemonTournamentReportAuditEntry>> loadAudit({
    int limit = 100,
  }) async {
    if (!isAdmin) {
      throw Exception('Apenas administradores podem consultar a auditoria.');
    }
    final rows = await _client
        .from('pokemon_tournament_report_audit')
        .select(
          'id, report_id, action, changed_at, source_key, '
          'previous_data, new_data',
        )
        .order('changed_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => PokemonTournamentReportAuditEntry.fromJson(row))
        .toList(growable: false);
  }

  Future<PokemonTournamentReportAuditEntry?> latestDeleteAudit(
    String reportId,
  ) async {
    if (!isAdmin) return null;
    final row = await _client
        .from('pokemon_tournament_report_audit')
        .select(
          'id, report_id, action, changed_at, source_key, '
          'previous_data, new_data',
        )
        .eq('report_id', reportId)
        .eq('action', 'delete')
        .order('changed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : PokemonTournamentReportAuditEntry.fromJson(row);
  }

  Future<void> restoreAudit(int auditId) async {
    if (!isAdmin) {
      throw Exception('Apenas administradores podem restaurar relatorios.');
    }
    await _client.rpc(
      'restore_pokemon_tournament_report_audit',
      params: {'audit_id': auditId},
    );
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
