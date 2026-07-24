import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/one_piece_standings_report.dart';
import 'package:optcg_manager/data/services/one_piece_monthly_ranking.dart';

void main() {
  OnePieceStandingPlayer player({
    required int ranking,
    required String id,
    required String name,
    required int points,
    String leaderCode = '',
    String leaderName = '',
  }) => OnePieceStandingPlayer(
    ranking: ranking,
    membershipNumber: id,
    userName: name,
    winPoints: points,
    omwPercentage: 55,
    oomwPercentage: 50,
    memo: '',
    deckUrls: '',
    leaderCode: leaderCode,
    leaderName: leaderName,
  );

  OnePieceStandingsReport report(
    DateTime date,
    List<OnePieceStandingPlayer> players,
  ) => OnePieceStandingsReport(
    sourceKey: date.toIso8601String(),
    sourceFileName: 'standing.csv',
    eventName: 'Semanal',
    eventDate: date,
    roundCount: 4,
    players: players,
  );

  test('monthly ranking sums only reports from the selected month', () {
    final ranking = buildOnePieceMonthlyRanking([
      report(DateTime(2026, 7, 3), [
        player(ranking: 1, id: '001', name: 'Luffy', points: 12),
        player(ranking: 2, id: '002', name: 'Nami', points: 9),
      ]),
      report(DateTime(2026, 7, 10), [
        player(ranking: 2, id: '001', name: 'Luffy', points: 9),
        player(ranking: 1, id: '002', name: 'Nami', points: 12),
      ]),
      report(DateTime(2026, 6, 26), [
        player(ranking: 1, id: '003', name: 'Zoro', points: 12),
      ]),
    ], month: DateTime(2026, 7));

    expect(ranking.players.map((item) => item.name), ['Luffy', 'Nami']);
    expect(ranking.players.first.winPoints, 21);
    expect(ranking.players.first.tournaments, 2);
    expect(ranking.players.first.bestPlacement, 1);
  });

  test(
    'leader ranking calculates usage and win rate from imported standings',
    () {
      final ranking = buildOnePieceMonthlyRanking([
        report(DateTime(2026, 7, 3), [
          player(
            ranking: 1,
            id: '001',
            name: 'Luffy',
            points: 12,
            leaderCode: 'OP05-060',
            leaderName: 'Monkey.D.Luffy',
          ),
          player(
            ranking: 2,
            id: '002',
            name: 'Nami',
            points: 6,
            leaderCode: 'OP05-060',
            leaderName: 'Monkey.D.Luffy',
          ),
        ]),
      ], month: DateTime(2026, 7));

      expect(ranking.leaders, hasLength(1));
      expect(ranking.leaders.first.uses, 2);
      expect(ranking.leaders.first.wins, 6);
      expect(ranking.leaders.first.games, 8);
      expect(ranking.leaders.first.winRate, 75);
      expect(ranking.leaderCoverage, 100);
    },
  );

  test(
    'old reports infer rounds and remain compatible without leader fields',
    () {
      final parsed = OnePieceStandingsReport.fromJson({
        'source_key': 'legacy',
        'source_file_name': 'legacy.csv',
        'event_name': 'Legacy',
        'event_date': '2026-07-01',
        'players': [
          {
            'ranking': 1,
            'membership_number': '001',
            'user_name': 'Luffy',
            'win_points': 12,
            'omw_percentage': 50,
            'oomw_percentage': 50,
            'memo': '',
            'deck_urls': '',
          },
        ],
      });

      expect(parsed.effectiveRoundCount, 4);
      expect(parsed.players.first.hasLeader, isFalse);
    },
  );
}
