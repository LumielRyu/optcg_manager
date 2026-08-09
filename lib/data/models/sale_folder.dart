class SaleFolder {
  final String id;
  final String userId;
  final String gameSlug;
  final String name;
  final DateTime createdAt;

  const SaleFolder({
    required this.id,
    required this.userId,
    required this.gameSlug,
    required this.name,
    required this.createdAt,
  });

  factory SaleFolder.fromJson(Map<String, dynamic> json) {
    return SaleFolder(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      gameSlug: (json['game_slug'] ?? 'one-piece').toString(),
      name: (json['name'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
