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

  test('leader names ignore visual variants while preserving card code', () {
    expect(normalizeWeeklyLeaderName('Enel (Alternate Art)'), 'Enel');
    expect(normalizeWeeklyLeaderName('Belo Betty (002) (SPR)'), 'Belo Betty');
    expect(
      const WeeklyLeaderOption(code: 'OP05-098', name: 'Enel').label,
      'Enel (OP05-098)',
    );
  });

  test('leader product waves sort newer releases before older releases', () {
    expect(
      weeklyLeaderReleaseOrder('OP15-001'),
      greaterThan(weeklyLeaderReleaseOrder('OP05-098')),
    );
    expect(
      weeklyLeaderReleaseOrder('ST29-001'),
      greaterThan(weeklyLeaderReleaseOrder('ST01-001')),
    );
    expect(
      weeklyLeaderReleaseOrder('EB04-001'),
      greaterThan(weeklyLeaderReleaseOrder('EB01-001')),
    );
  });
}
