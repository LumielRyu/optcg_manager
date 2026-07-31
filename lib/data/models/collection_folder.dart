class CollectionFolder {
  final String id;
  final String userId;
  final String gameSlug;
  final String name;
  final DateTime createdAt;

  const CollectionFolder({
    required this.id,
    required this.userId,
    required this.gameSlug,
    required this.name,
    required this.createdAt,
  });

  factory CollectionFolder.fromJson(Map<String, dynamic> json) {
    return CollectionFolder(
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
