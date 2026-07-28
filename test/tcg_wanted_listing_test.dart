import 'package:flutter_test/flutter_test.dart';
import 'package:optcg_manager/data/models/tcg_wanted_listing.dart';

void main() {
  group('TcgWantedListing', () {
    test('maps game and exact printing identity', () {
      final item = TcgWantedListing.fromRow({
        'id': 'wanted-1',
        'user_id': 'user-1',
        'game_slug': 'yugioh',
        'catalog_card_id': '46986414',
        'variant_id': 'LOB-001',
        'card_code': 'YUGIOH:LOB:001',
        'name': 'Blue-Eyes White Dragon',
        'quantity': 2,
        'is_public': true,
        'is_active': true,
        'contact_info': '(31) 99999-0000',
      }, seekerName: 'Duelista BH');

      expect(item.gameSlug, 'yugioh');
      expect(item.catalogCardId, '46986414');
      expect(item.variantId, 'LOB-001');
      expect(item.quantity, 2);
      expect(item.statusLabel, 'Ativa');
      expect(item.seekerName, 'Duelista BH');
      expect(item.normalizedWhatsAppNumber, '5531999990000');
    });

    test('paused item preserves privacy and status state', () {
      final item = TcgWantedListing.fromRow({
        'id': 'wanted-2',
        'is_public': false,
        'is_active': false,
      });

      expect(item.isPublic, isFalse);
      expect(item.isActive, isFalse);
      expect(item.statusLabel, 'Pausada');
      expect(item.hasWhatsAppContact, isFalse);
    });
  });
}
