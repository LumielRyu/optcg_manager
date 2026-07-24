import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/services/one_piece_standings_parser.dart';

void main() {
  const sample =
      '''Ranking, Membership Number, User Name, Win Points, OMW %, OOMW %, Memo, Deck URLs
1,0000245208,Raia,12,58.3%,59.3%,undefined,
2,0000304877,"Nando, Gray",9,54%,63.6%,undefined,https://example.com/deck
''';

  test('parses Bandai TCG+ final standings and preserves leading zeroes', () {
    final report = const OnePieceStandingsParser().parse(
      sample,
      fileName: 'Instant Event_STOP TCG_standing.csv',
      eventDate: DateTime(2026, 7, 14),
    );

    expect(report.eventName, 'Instant Event STOP TCG');
    expect(report.participantCount, 2);
    expect(report.players.first.membershipNumber, '0000245208');
    expect(report.players.first.omwPercentage, 58.3);
    expect(report.players[1].userName, 'Nando, Gray');
    expect(report.players[1].deckUrls, 'https://example.com/deck');
  });

  test('rejects unrelated CSV files', () {
    expect(
      () => const OnePieceStandingsParser().parse(
        'nome,pontos\nLuffy,12',
        fileName: 'qualquer.csv',
        eventDate: DateTime(2026, 7, 14),
      ),
      throwsFormatException,
    );
  });
}
