class RiftboundCard {
  final String id;
  final String name;
  final String riftboundId;
  final int collectorNumber;
  final String imageUrl;
  final String setName;
  final String rarity;
  final String type;
  final String supertype;
  final List<String> domains;
  final List<String> tags;
  final String rulesText;
  final String flavorText;
  final int? energy;
  final int? might;
  final int? power;

  RiftboundCard({
    required this.id,
    required this.name,
    required this.riftboundId,
    required this.collectorNumber,
    required this.imageUrl,
    required this.setName,
    required this.rarity,
    required this.type,
    required this.supertype,
    required this.domains,
    required this.tags,
    required this.rulesText,
    required this.flavorText,
    required this.energy,
    required this.might,
    required this.power,
  });

  factory RiftboundCard.fromJson(Map<String, dynamic> json) {
    final attributes =
        (json['attributes'] as Map<String, dynamic>? ?? const {});
    final classification =
        (json['classification'] as Map<String, dynamic>? ?? const {});
    final text = (json['text'] as Map<String, dynamic>? ?? const {});
    final set = (json['set'] as Map<String, dynamic>? ?? const {});
    final media = (json['media'] as Map<String, dynamic>? ?? const {});

    return RiftboundCard(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      riftboundId: (json['riftbound_id'] ?? '').toString().trim(),
      collectorNumber: (json['collector_number'] as num?)?.toInt() ?? 0,
      imageUrl: (media['image_url'] ?? '').toString().trim(),
      setName: (set['label'] ?? '').toString().trim(),
      rarity: (classification['rarity'] ?? '').toString().trim(),
      type: (classification['type'] ?? '').toString().trim(),
      supertype: (classification['supertype'] ?? '').toString().trim(),
      domains: (classification['domain'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      rulesText: (text['plain'] ?? '').toString().trim(),
      flavorText: (text['flavour'] ?? '').toString().trim(),
      energy: (attributes['energy'] as num?)?.toInt(),
      might: (attributes['might'] as num?)?.toInt(),
      power: (attributes['power'] as num?)?.toInt(),
    );
  }
}
