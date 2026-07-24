import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/services/pokemon_tdf_parser.dart';

void main() {
  const parser = PokemonTdfParser();

  test('parses TDF metadata, standings, drops and match outcomes', () {
    final report = parser.parse(_tdfFixture, fileName: 'semanal.tdf');

    expect(report.name, 'Semanal STOP TCG');
    expect(report.eventDate, DateTime(2026, 5, 2));
    expect(report.organizerName, 'Professor Oak');
    expect(report.participantCount, 3);
    expect(report.roundCount, 2);
    expect(report.matchCount, 4);
    expect(report.dropCount, 1);

    final ash = report.players.singleWhere((player) => player.playerId == '1');
    expect(ash.name, 'Ash Ketchum');
    expect(ash.placement, 1);
    expect(ash.categoryLabel, 'Master');
    expect(ash.wins, 2);
    expect(ash.byes, 1);

    final misty = report.players.singleWhere(
      (player) => player.playerId == '2',
    );
    expect(misty.draws, 1);
    expect(misty.losses, 1);
    expect(misty.droppedRound, 2);
  });

  test('does not include birth dates in serialized report', () {
    final report = parser.parse(_tdfFixture, fileName: 'semanal.tdf');
    expect(report.toJson().toString(), isNot(contains('birthdate')));
    expect(report.toJson().toString(), isNot(contains('02/27/2000')));
  });

  test('rejects XML that is not a tournament TDF', () {
    expect(
      () => parser.parse('<document />', fileName: 'invalid.tdf'),
      throwsFormatException,
    );
  });

  test('recognizes TDF extension without relying on the browser filter', () {
    expect(isPokemonTdfFileName('semanal.tdf'), isTrue);
    expect(isPokemonTdfFileName('SEMANAL.TDF'), isTrue);
    expect(isPokemonTdfFileName('semanal.xml'), isFalse);
    expect(isPokemonTdfFileName('semanal.tdf.txt'), isFalse);
  });
}

const _tdfFixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<tournament type="2" stage="5" version="1.82" gametype="TRADING_CARD_GAME" mode="CUSTOM">
  <data>
    <name>Semanal STOP TCG</name>
    <city>Belo Horizonte</city>
    <state>MG</state>
    <country>Brasil</country>
    <roundtime>50</roundtime>
    <finalsroundtime>75</finalsroundtime>
    <organizer popid="99" name="Professor Oak" />
    <startdate>05/02/2026</startdate>
  </data>
  <timeelapsed>7200</timeelapsed>
  <players>
    <player userid="1">
      <firstname>Ash</firstname><lastname>Ketchum</lastname>
      <birthdate>02/27/2000</birthdate>
    </player>
    <player userid="2">
      <firstname>Misty</firstname><lastname>Waterflower</lastname>
      <dropped><status>1</status><round>2</round></dropped>
    </player>
    <player userid="3">
      <firstname>Brock</firstname><lastname>Harrison</lastname>
    </player>
  </players>
  <pods>
    <pod category="10" stage="0">
      <rounds>
        <round number="1">
          <starttime>05/02/2026 10:00:00</starttime>
          <matches>
            <match outcome="1"><player1 userid="1"/><player2 userid="2"/><tablenumber>1</tablenumber></match>
            <match outcome="5"><player userid="3"/><tablenumber>0</tablenumber></match>
          </matches>
        </round>
        <round number="2">
          <matches>
            <match outcome="3"><player1 userid="2"/><player2 userid="3"/><tablenumber>1</tablenumber></match>
            <match outcome="5"><player userid="1"/><tablenumber>0</tablenumber></match>
          </matches>
        </round>
      </rounds>
    </pod>
  </pods>
  <standings>
    <pod category="2" type="finished">
      <player id="1" place="1"/><player id="3" place="2"/><player id="2" place="3"/>
    </pod>
  </standings>
</tournament>
''';
