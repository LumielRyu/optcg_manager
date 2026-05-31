import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/weekly_tournament.dart';
import 'package:optcg_manager/features/weeklies/weekly_dashboard_screen.dart';

void main() {
  test('weekly month label does not require intl locale initialization', () {
    expect(weeklyMonthLabel(DateTime(2026, 5)), 'maio 2026');
    expect(weeklyMonthLabel(DateTime(2027, 12)), 'dezembro 2027');
  });

  test('bye match is a confirmed automatic win without opponent', () {
    final match = WeeklyMatch.fromJson({
      'id': 'match-1',
      'weekly_event_id': 'event-1',
      'round_number': 2,
      'table_number': null,
      'player_one_id': 'participant-1',
      'player_two_id': null,
      'match_type': 'bye',
      'result': 'bye',
      'result_status': 'confirmed',
    });

    expect(match.isBye, isTrue);
    expect(match.isCompleted, isTrue);
    expect(match.playerTwoId, isNull);
  });
}
