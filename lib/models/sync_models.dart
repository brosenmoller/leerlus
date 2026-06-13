class SyncPeer {
  final String deviceName;
  final String host;
  final int port;

  const SyncPeer({
    required this.deviceName,
    required this.host,
    required this.port,
  });

  @override
  bool operator ==(Object other) =>
      other is SyncPeer && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$deviceName ($host:$port)';
}

class SyncEntry {
  final String id;
  final DateTime createdAt;
  final String? contentHash;

  /// Last local modification time, used by sync for last-write-wins.
  /// Nullable for backward-compat: absent when received from an older client.
  final DateTime? updatedAt;

  const SyncEntry({
    required this.id,
    required this.createdAt,
    this.contentHash,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        if (contentHash != null) 'contentHash': contentHash,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        contentHash: json['contentHash'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

/// Records a deletion for sync propagation. [entityType] is one of
/// 'folder' | 'quiz' | 'question' | 'favorite'.
class SyncTombstone {
  final String entityId;
  final String entityType;
  final DateTime deletedAt;

  const SyncTombstone({
    required this.entityId,
    required this.entityType,
    required this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        'entityType': entityType,
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory SyncTombstone.fromJson(Map<String, dynamic> json) => SyncTombstone(
        entityId: json['entityId'] as String,
        entityType: json['entityType'] as String,
        deletedAt: DateTime.parse(json['deletedAt'] as String),
      );
}

/// Parses a tombstone list defensively — absent on older clients → empty.
List<SyncTombstone> _tombstonesFromJson(dynamic raw) =>
    (raw as List?)
        ?.map((e) => SyncTombstone.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList() ??
    const [];

/// Parses a {id: isoString} map defensively.
Map<String, String> _strMapFromJson(dynamic raw) =>
    (raw as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ??
    const {};

class SyncManifest {
  final List<SyncEntry> folders;
  final List<SyncEntry> quizzes;
  final List<SyncEntry> questions;
  final List<String> srsKeys;
  final List<String> favoriteSyncIds;

  /// Deletions (content + favorites) for propagation. Empty for older clients.
  final List<SyncTombstone> tombstones;

  /// favorited quizId -> addedAt ISO string. Empty for older clients.
  final Map<String, String> favoriteAddedAt;

  const SyncManifest({
    required this.folders,
    required this.quizzes,
    required this.questions,
    required this.srsKeys,
    required this.favoriteSyncIds,
    this.tombstones = const [],
    this.favoriteAddedAt = const {},
  });

  Map<String, dynamic> toJson() => {
        'folders': folders.map((e) => e.toJson()).toList(),
        'quizzes': quizzes.map((e) => e.toJson()).toList(),
        'questions': questions.map((e) => e.toJson()).toList(),
        'srsKeys': srsKeys,
        'favoriteSyncIds': favoriteSyncIds,
        'tombstones': tombstones.map((e) => e.toJson()).toList(),
        'favoriteAddedAt': favoriteAddedAt,
      };

  factory SyncManifest.fromJson(Map<String, dynamic> json) => SyncManifest(
        folders: (json['folders'] as List)
            .map((e) => SyncEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        quizzes: (json['quizzes'] as List)
            .map((e) => SyncEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        questions: (json['questions'] as List)
            .map((e) => SyncEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        srsKeys: (json['srsKeys'] as List).map((e) => e as String).toList(),
        favoriteSyncIds:
            (json['favoriteSyncIds'] as List).map((e) => e as String).toList(),
        tombstones: _tombstonesFromJson(json['tombstones']),
        favoriteAddedAt: _strMapFromJson(json['favoriteAddedAt']),
      );
}

class SyncPayload {
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> quizzes;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> srsData;
  final List<String> favoriteSyncIds;
  final List<String> imageFilenames;
  /// Nullable for backward-compat: absent when receiving from an older client.
  final Map<String, dynamic>? streakData;
  /// Nullable for backward-compat: absent when receiving from an older client.
  final Map<String, dynamic>? statisticsData;

  /// Deletions to apply on the receiver. Empty for older clients.
  final List<SyncTombstone> tombstones;

  /// favorited quizId -> addedAt ISO string. Empty for older clients.
  final Map<String, String> favoriteAddedAt;

  const SyncPayload({
    required this.folders,
    required this.quizzes,
    required this.questions,
    required this.srsData,
    required this.favoriteSyncIds,
    required this.imageFilenames,
    this.streakData,
    this.statisticsData,
    this.tombstones = const [],
    this.favoriteAddedAt = const {},
  });

  Map<String, dynamic> toJson() => {
        'folders': folders,
        'quizzes': quizzes,
        'questions': questions,
        'srsData': srsData,
        'favoriteSyncIds': favoriteSyncIds,
        'imageFilenames': imageFilenames,
        if (streakData != null) 'streakData': streakData,
        if (statisticsData != null) 'statisticsData': statisticsData,
        'tombstones': tombstones.map((e) => e.toJson()).toList(),
        'favoriteAddedAt': favoriteAddedAt,
      };

  factory SyncPayload.fromJson(Map<String, dynamic> json) => SyncPayload(
        folders: (json['folders'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        quizzes: (json['quizzes'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        questions: (json['questions'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        srsData: (json['srsData'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        favoriteSyncIds:
            (json['favoriteSyncIds'] as List).map((e) => e as String).toList(),
        imageFilenames:
            (json['imageFilenames'] as List).map((e) => e as String).toList(),
        streakData: json['streakData'] != null
            ? Map<String, dynamic>.from(json['streakData'] as Map)
            : null,
        statisticsData: json['statisticsData'] != null
            ? Map<String, dynamic>.from(json['statisticsData'] as Map)
            : null,
        tombstones: _tombstonesFromJson(json['tombstones']),
        favoriteAddedAt: _strMapFromJson(json['favoriteAddedAt']),
      );
}

class SyncResult {
  final int foldersAdded;
  final int quizzesAdded;
  final int questionsAdded;
  final int foldersUpdated;
  final int quizzesUpdated;
  final int questionsUpdated;
  final int srsUpdated;
  final int favoritesAdded;
  final int foldersDeleted;
  final int quizzesDeleted;
  final int questionsDeleted;
  final int favoritesRemoved;
  final int imagesFailedCount;
  /// True when this result is for the hard-sync initiator. Deletions in that
  /// case happened on the remote device, not locally, so the UI suppresses them.
  final bool isHardSync;
  final bool statisticsUpdated;

  const SyncResult({
    this.foldersAdded = 0,
    this.quizzesAdded = 0,
    this.questionsAdded = 0,
    this.foldersUpdated = 0,
    this.quizzesUpdated = 0,
    this.questionsUpdated = 0,
    this.srsUpdated = 0,
    this.favoritesAdded = 0,
    this.foldersDeleted = 0,
    this.quizzesDeleted = 0,
    this.questionsDeleted = 0,
    this.favoritesRemoved = 0,
    this.imagesFailedCount = 0,
    this.isHardSync = false,
    this.statisticsUpdated = false,
  });

  SyncResult copyWith({
    int? srsUpdated,
    bool? statisticsUpdated,
    int? foldersDeleted,
    int? quizzesDeleted,
    int? questionsDeleted,
    int? favoritesRemoved,
  }) =>
      SyncResult(
        foldersAdded: foldersAdded,
        quizzesAdded: quizzesAdded,
        questionsAdded: questionsAdded,
        foldersUpdated: foldersUpdated,
        quizzesUpdated: quizzesUpdated,
        questionsUpdated: questionsUpdated,
        srsUpdated: srsUpdated ?? this.srsUpdated,
        favoritesAdded: favoritesAdded,
        foldersDeleted: foldersDeleted ?? this.foldersDeleted,
        quizzesDeleted: quizzesDeleted ?? this.quizzesDeleted,
        questionsDeleted: questionsDeleted ?? this.questionsDeleted,
        favoritesRemoved: favoritesRemoved ?? this.favoritesRemoved,
        imagesFailedCount: imagesFailedCount,
        isHardSync: isHardSync,
        statisticsUpdated: statisticsUpdated ?? this.statisticsUpdated,
      );

  SyncResult withImagesFailed(int count) => SyncResult(
    foldersAdded: foldersAdded,
    quizzesAdded: quizzesAdded,
    questionsAdded: questionsAdded,
    foldersUpdated: foldersUpdated,
    quizzesUpdated: quizzesUpdated,
    questionsUpdated: questionsUpdated,
    srsUpdated: srsUpdated,
    favoritesAdded: favoritesAdded,
    foldersDeleted: foldersDeleted,
    quizzesDeleted: quizzesDeleted,
    questionsDeleted: questionsDeleted,
    favoritesRemoved: favoritesRemoved,
    imagesFailedCount: count,
    isHardSync: isHardSync,
    statisticsUpdated: statisticsUpdated,
  );

  bool get isEmpty =>
      foldersAdded == 0 &&
      quizzesAdded == 0 &&
      questionsAdded == 0 &&
      foldersUpdated == 0 &&
      quizzesUpdated == 0 &&
      questionsUpdated == 0 &&
      srsUpdated == 0 &&
      favoritesAdded == 0 &&
      foldersDeleted == 0 &&
      quizzesDeleted == 0 &&
      questionsDeleted == 0 &&
      favoritesRemoved == 0;
}
