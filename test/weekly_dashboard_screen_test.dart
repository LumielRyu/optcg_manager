import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/features/weeklies/weekly_dashboard_screen.dart';

void main() {
  test('weekly month label does not require intl locale initialization', () {
    expect(weeklyMonthLabel(DateTime(2026, 5)), 'maio 2026');
    expect(weeklyMonthLabel(DateTime(2027, 12)), 'dezembro 2027');
  });
}
