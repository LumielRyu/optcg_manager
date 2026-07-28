enum TcgGame {
  onePiece('one-piece', 'One Piece'),
  pokemon('pokemon', 'Pokemon'),
  digimon('digimon', 'Digimon'),
  magic('magic', 'Magic'),
  riftbound('riftbound', 'Riftbound'),
  yugioh('yugioh', 'Yu-Gi-Oh');

  final String slug;
  final String label;

  const TcgGame(this.slug, this.label);

  static TcgGame fromSlug(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return values.firstWhere(
      (game) => game.slug == normalized,
      orElse: () => TcgGame.onePiece,
    );
  }
}
