import 'package:hive/hive.dart';

class FavoritesService {
  static const String _boxName = 'favoritesBox';
  static const String _tombstoneBoxName = 'favoriteTombstones';

  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  // _box: quizId -> addedAt ISO string. Legacy rows stored the quizId as the
  // value; those parse to null and are treated as epoch 0 (see [favoriteAddedAt]).
  late Box<String> _box;
  // _tombstoneBox: quizId -> deletedAt ISO string. Records unfavorites so they
  // propagate during sync instead of being re-added from a peer.
  late Box<String> _tombstoneBox;
  bool _initialized = false;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (_initialized) return;
    _box = await _open(_boxName);
    _tombstoneBox = await _open(_tombstoneBoxName);
    _initialized = true;
  }

  Future<Box<String>> _open(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<String>(name);
    }
  }

  /// IDs of all favorited quizzes.
  List<String> get allFavorites => _box.keys.cast<String>().toList();
  bool isFavorite(String quizId) => _box.containsKey(quizId);

  Future<void> addFavorite(String quizId) async {
    await _box.put(quizId, DateTime.now().toIso8601String());
    await _tombstoneBox.delete(quizId); // re-favoriting clears the tombstone
  }

  Future<void> removeFavorite(String quizId) async {
    await _box.delete(quizId);
    await _tombstoneBox.put(quizId, DateTime.now().toIso8601String());
  }

  /// Returns UUID ids of all favorited quizzes.
  List<String> getAllFavoriteIds() => _box.keys.cast<String>().toList();

  /// When the favorite was added. Legacy entries (value == id, pre-timestamp)
  /// return epoch 0 so an unfavorite tombstone wins and a genuine re-favorite
  /// (which writes now()) supersedes it.
  DateTime favoriteAddedAt(String quizId) {
    final v = _box.get(quizId);
    return (v != null ? DateTime.tryParse(v) : null) ?? _epoch;
  }

  /// All unfavorite tombstones (quizId -> deletedAt) for sync exchange.
  Map<String, DateTime> getFavoriteTombstones() {
    final out = <String, DateTime>{};
    for (final key in _tombstoneBox.keys.cast<String>()) {
      final v = _tombstoneBox.get(key);
      final ts = v != null ? DateTime.tryParse(v) : null;
      if (ts != null) out[key] = ts;
    }
    return out;
  }

  /// Sync-apply: add an incoming favorite at [addedAt] unless a newer local
  /// unfavorite tombstone overrides it. Clears an older local tombstone.
  Future<void> applyFavoriteAdd(String quizId, DateTime addedAt) async {
    final t = _tombstoneBox.get(quizId);
    final tts = t != null ? DateTime.tryParse(t) : null;
    if (tts != null && tts.isAfter(addedAt)) return; // unfavorite wins
    if (tts != null) await _tombstoneBox.delete(quizId);
    // Keep the latest addedAt if we already have it.
    if (isFavorite(quizId) && favoriteAddedAt(quizId).isAfter(addedAt)) return;
    await _box.put(quizId, addedAt.toIso8601String());
  }

  /// Sync-apply: record an incoming unfavorite tombstone at [deletedAt],
  /// removing the favorite if it isn't newer than the deletion.
  Future<void> applyFavoriteTombstone(String quizId, DateTime deletedAt) async {
    final existing = _tombstoneBox.get(quizId);
    final ex = existing != null ? DateTime.tryParse(existing) : null;
    if (ex == null || deletedAt.isAfter(ex)) {
      await _tombstoneBox.put(quizId, deletedAt.toIso8601String());
    }
    if (isFavorite(quizId) && !favoriteAddedAt(quizId).isAfter(deletedAt)) {
      await _box.delete(quizId);
    }
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _tombstoneBox.clear();
  }
}
