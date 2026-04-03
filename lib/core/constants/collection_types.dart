class CollectionTypes {
  static const String owned = 'owned';
  static const String forSale = 'forSale';
  static const String deck = 'deck';

  static const List<String> all = [
    owned,
    forSale,
    deck,
  ];

  static String label(String type) {
    switch (type) {
      case owned:
        return 'Cartas Obtidas';
      case forSale:
        return 'Cartas à Venda';
      case deck:
        return 'Decks Montados';
      default:
        return type;
    }
  }
}