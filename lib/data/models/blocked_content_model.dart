import 'package:cloud_firestore/cloud_firestore.dart';

/// Reduces a user-entered URL or host to a bare lowercase host
/// (`https://www.YouTube.com/watch?v=1` -> `youtube.com`).
String normalizeBlockedHost(String input) {
  var host = input.trim().toLowerCase();
  host = host.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
  host = host.split(RegExp(r'[/?#]')).first;
  host = host.split('@').last; // drop user-info
  host = host.split(':').first; // drop port
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

/// Reads `blockedWebsites` from either the current shape (map keyed by
/// normalized host) or the legacy shape (array of maps).
List<BlockedWebsite> _websitesFrom(Object? raw) {
  final Iterable<Object?> items = switch (raw) {
    final List<dynamic> list => list,
    final Map<dynamic, dynamic> map => map.values,
    _ => const [],
  };
  final byHost = <String, BlockedWebsite>{};
  for (final item in items) {
    if (item is! Map) continue;
    final site = BlockedWebsite.fromMap(Map<String, dynamic>.from(item));
    final host = normalizeBlockedHost(site.url);
    if (host.isEmpty) continue;
    byHost[host] = BlockedWebsite(
      url: host,
      name: site.name,
      isActive: site.isActive,
    );
  }
  return byHost.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

class BlockedWebsite {
  final String url;
  final String name;
  final bool isActive;

  BlockedWebsite({required this.url, required this.name, this.isActive = true});

  Map<String, dynamic> toMap() {
    return {'url': url, 'name': name, 'isActive': isActive};
  }

  factory BlockedWebsite.fromMap(Map<String, dynamic> map) {
    return BlockedWebsite(
      url: map['url'] ?? '',
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }

  @override
  String toString() {
    return 'BlockedWebsite(url: $url, name: $name, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BlockedWebsite &&
        other.url == url &&
        other.name == name &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => url.hashCode ^ name.hashCode ^ isActive.hashCode;
}

class ShortFormBlock {
  final String platform; // 'youtube', 'instagram', 'snapchat', etc.
  final String feature; // 'shorts', 'reels', 'stories', etc.
  final bool isBlocked;

  ShortFormBlock({
    required this.platform,
    required this.feature,
    this.isBlocked = true,
  });

  Map<String, dynamic> toMap() {
    return {'platform': platform, 'feature': feature, 'isBlocked': isBlocked};
  }

  factory ShortFormBlock.fromMap(Map<String, dynamic> map) {
    return ShortFormBlock(
      platform: map['platform'] ?? '',
      feature: map['feature'] ?? '',
      isBlocked: map['isBlocked'] ?? true,
    );
  }

  @override
  String toString() {
    return 'ShortFormBlock(platform: $platform, feature: $feature, isBlocked: $isBlocked)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShortFormBlock &&
        other.platform == platform &&
        other.feature == feature &&
        other.isBlocked == isBlocked;
  }

  @override
  int get hashCode => platform.hashCode ^ feature.hashCode ^ isBlocked.hashCode;
}

class BlockedContentModel {
  final List<String> permanentlyBlockedApps;
  final List<BlockedWebsite> blockedWebsites;
  final Map<String, ShortFormBlock> shortFormBlocks; // Key: platform_feature
  final DateTime lastUpdated;

  BlockedContentModel({
    this.permanentlyBlockedApps = const [],
    this.blockedWebsites = const [],
    this.shortFormBlocks = const {},
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'permanentlyBlockedApps': permanentlyBlockedApps,
      // Map keyed by normalized host so single sites can be changed atomically.
      'blockedWebsites': {
        for (final website in blockedWebsites)
          if (normalizeBlockedHost(website.url).isNotEmpty)
            normalizeBlockedHost(website.url): website.toMap(),
      },
      'shortFormBlocks': shortFormBlocks.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  // Create from Firestore document
  factory BlockedContentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BlockedContentModel(
      permanentlyBlockedApps: data['permanentlyBlockedApps'] != null
          ? List<String>.from(data['permanentlyBlockedApps'])
          : [],
      blockedWebsites: _websitesFrom(data['blockedWebsites']),
      shortFormBlocks: data['shortFormBlocks'] != null
          ? (data['shortFormBlocks'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                ShortFormBlock.fromMap(value as Map<String, dynamic>),
              ),
            )
          : {},
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from Map
  factory BlockedContentModel.fromMap(Map<String, dynamic> data) {
    return BlockedContentModel(
      permanentlyBlockedApps: data['permanentlyBlockedApps'] != null
          ? List<String>.from(data['permanentlyBlockedApps'])
          : [],
      blockedWebsites: _websitesFrom(data['blockedWebsites']),
      shortFormBlocks: data['shortFormBlocks'] != null
          ? (data['shortFormBlocks'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                ShortFormBlock.fromMap(value as Map<String, dynamic>),
              ),
            )
          : {},
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : data['lastUpdated'] is DateTime
          ? data['lastUpdated']
          : DateTime.now(),
    );
  }

  // Create a copy with updated values
  BlockedContentModel copyWith({
    List<String>? permanentlyBlockedApps,
    List<BlockedWebsite>? blockedWebsites,
    Map<String, ShortFormBlock>? shortFormBlocks,
    DateTime? lastUpdated,
  }) {
    return BlockedContentModel(
      permanentlyBlockedApps:
          permanentlyBlockedApps ?? this.permanentlyBlockedApps,
      blockedWebsites: blockedWebsites ?? this.blockedWebsites,
      shortFormBlocks: shortFormBlocks ?? this.shortFormBlocks,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Helper methods
  bool isAppBlocked(String packageName) {
    return permanentlyBlockedApps.contains(packageName);
  }

  bool isWebsiteBlocked(String url) {
    final host = normalizeBlockedHost(url);
    if (host.isEmpty) return false;
    return blockedWebsites.any((website) {
      if (!website.isActive) return false;
      final blocked = normalizeBlockedHost(website.url);
      return blocked.isNotEmpty &&
          (host == blocked || host.endsWith('.$blocked'));
    });
  }

  bool isShortFormBlocked(String platform, String feature) {
    final key = '${platform}_$feature';
    return shortFormBlocks[key]?.isBlocked ?? false;
  }

  // Get all blocked app count
  int get blockedAppsCount => permanentlyBlockedApps.length;

  // Get all blocked websites count
  int get blockedWebsitesCount =>
      blockedWebsites.where((w) => w.isActive).length;

  // Get all blocked short forms count
  int get blockedShortFormsCount =>
      shortFormBlocks.values.where((b) => b.isBlocked).length;

  @override
  String toString() {
    return 'BlockedContentModel(permanentlyBlockedApps: $permanentlyBlockedApps, blockedWebsites: $blockedWebsites, shortFormBlocks: $shortFormBlocks, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BlockedContentModel &&
        other.permanentlyBlockedApps.length == permanentlyBlockedApps.length &&
        other.blockedWebsites.length == blockedWebsites.length &&
        other.shortFormBlocks.length == shortFormBlocks.length &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return permanentlyBlockedApps.hashCode ^
        blockedWebsites.hashCode ^
        shortFormBlocks.hashCode ^
        lastUpdated.hashCode;
  }
}
