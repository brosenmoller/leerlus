import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/models/sync_models.dart';
import 'package:leerlus/models/user_question_data.dart';
import 'package:leerlus/services/favorites_service.dart';
import 'package:leerlus/services/question_service.dart';
import 'package:leerlus/services/srs_service.dart';
import 'package:leerlus/services/statistics_service.dart';
import 'package:leerlus/services/streak_service.dart';
import 'package:leerlus/services/sync_discovery_service.dart';
import 'package:drift/drift.dart' show Value;

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  AppDatabase? _db;
  HttpServer? _server;
  int _httpPort = 0;
  bool _initialized = false;
  String _myDeviceName = '';

  Completer<bool>? _pendingAccept;
  SyncResult? _acceptorResult; // set by _handlePush, consumed by _handleSyncDone
  Timer? _acceptorFallbackTimer;

  // Tracks peers we've already sent a reverse-advertisement to this session so
  // we don't spam the request on every peers-stream tick.
  final _advertisedPeers = <String>{};
  StreamSubscription<List<SyncPeer>>? _advertiseSub;

  final _incomingRequestController = StreamController<String>.broadcast();
  final _syncProgressController = StreamController<String>.broadcast();
  final _acceptorDoneController = StreamController<SyncResult>.broadcast();

  /// Emits the requesting device name when an incoming sync request arrives.
  Stream<String> get incomingRequests => _incomingRequestController.stream;

  /// Emits progress messages during an active sync (initiator side).
  Stream<String> get syncProgress => _syncProgressController.stream;

  /// Emits once when the initiator signals completion (acceptor side).
  Stream<SyncResult> get acceptorSyncComplete => _acceptorDoneController.stream;

  final SyncDiscoveryService discovery = SyncDiscoveryService();

  Future<void> init(AppDatabase db) async {
    if (_initialized) return;
    _db = db;
    await _startServer();
    _initialized = true;
  }

  /// Stop the HTTP server and reset so [init] can be called again next time
  /// the sync screen is opened.
  Future<void> shutdown() async {
    await _advertiseSub?.cancel();
    _advertiseSub = null;
    _advertisedPeers.clear();
    await discovery.stop();
    await _server?.close(force: true);
    _server = null;
    _httpPort = 0;
    _initialized = false;
    _myDeviceName = '';
    _pendingAccept?.complete(false);
    _pendingAccept = null;
    _acceptorFallbackTimer?.cancel();
    _acceptorFallbackTimer = null;
    _acceptorResult = null;
  }

  Future<void> _startServer() async {
    final router = Router();
    router.get('/ping', _handlePing);
    router.post('/sync/request', _handleSyncRequest);
    router.get('/sync/manifest', _handleManifest);
    router.post('/sync/push', _handlePush);
    router.post('/sync/pull', _handlePull);
    router.get('/sync/image', _handleImage);
    router.post('/sync/hard-delete', _handleHardDelete);
    router.post('/sync/done', _handleSyncDone);
    router.post('/sync/advertise', _handleAdvertise);

    _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, 0);
    _httpPort = _server!.port;
  }

  int get httpPort => _httpPort;

  Future<void> startDiscovery(String deviceName) async {
    _myDeviceName = deviceName;
    _advertisedPeers.clear();
    await discovery.start(deviceName: deviceName, httpPort: _httpPort);
    // When we discover a new peer via UDP, immediately send them an HTTP
    // advertisement so they can register us — this fixes one-way UDP scenarios
    // (e.g. Windows Firewall blocks inbound UDP from Android).
    _advertiseSub = discovery.peersStream.listen(_onPeersForAdvertise);
  }

  void _onPeersForAdvertise(List<SyncPeer> peers) {
    for (final peer in peers) {
      if (_advertisedPeers.contains(peer.host)) continue;
      _advertisedPeers.add(peer.host);
      _sendReverseAdvertise(peer);
    }
  }

  void _sendReverseAdvertise(SyncPeer peer) {
    final base = 'http://${peer.host}:${peer.port}';
    http
        .post(
          Uri.parse('$base/sync/advertise'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'deviceName': _deviceName, 'httpPort': _httpPort}),
        )
        .timeout(const Duration(seconds: 5))
        .ignore(); // best-effort; failure is silent
  }

  Future<void> stopDiscovery() async {
    await _advertiseSub?.cancel();
    _advertiseSub = null;
    _advertisedPeers.clear();
    await discovery.stop();
  }

  // ── Server handlers ──────────────────────────────────────────

  Response _handlePing(Request req) => Response.ok(
        jsonEncode({'deviceName': _deviceName, 'version': '1'}),
        headers: {'content-type': 'application/json'},
      );

  Future<Response> _handleSyncRequest(Request req) async {
    final body = Map<String, dynamic>.from(
        jsonDecode(await req.readAsString()) as Map);
    final requesterName = body['deviceName'] as String? ?? 'Unknown Device';

    // Register the requester as a discovered peer so the acceptor can initiate
    // sync back even when UDP discovery is blocked (e.g. Windows Firewall).
    final requesterHttpPort = body['httpPort'] as int?;
    final connInfo =
        req.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final requesterIp = connInfo?.remoteAddress.address;
    if (requesterIp != null && requesterHttpPort != null) {
      discovery.registerPeer(SyncPeer(
        deviceName: requesterName,
        host: requesterIp,
        port: requesterHttpPort,
      ));
    }

    if (_pendingAccept != null) {
      return Response(503,
          body: jsonEncode({'accepted': false, 'reason': 'busy'}),
          headers: {'content-type': 'application/json'});
    }

    _pendingAccept = Completer<bool>();
    _incomingRequestController.add(requesterName);

    final accepted = await _pendingAccept!.future
        .timeout(const Duration(seconds: 60), onTimeout: () => false);
    _pendingAccept = null;

    return Response.ok(
      jsonEncode({'accepted': accepted}),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Called by the UI to accept or reject an incoming sync request.
  void respondToRequest(bool accepted) => _pendingAccept?.complete(accepted);

  Future<Response> _handleManifest(Request req) async {
    final manifest = await _buildManifest();
    return Response.ok(
      jsonEncode(manifest.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }

  // Limit applies to JSON metadata only — images are fetched separately via
  // /sync/image and are not subject to this cap.
  static const _maxPayloadBytes = 500 * 1024 * 1024; // 500 MB

  Future<String?> _readBodyWithLimit(Request req, [int maxBytes = _maxPayloadBytes]) async {
    final lengthHeader = req.headers['content-length'];
    if (lengthHeader != null) {
      final declared = int.tryParse(lengthHeader);
      if (declared != null && declared > maxBytes) return null;
    }
    final chunks = <int>[];
    await for (final chunk in req.read()) {
      chunks.addAll(chunk);
      if (chunks.length > maxBytes) return null;
    }
    return utf8.decode(chunks);
  }

  Future<Response> _handlePush(Request req) async {
    try {
      final bodyStr = await _readBodyWithLimit(req);
      if (bodyStr == null) {
        return Response(413,
            body: jsonEncode({'ok': false, 'error': 'Payload too large'}),
            headers: {'content-type': 'application/json'});
      }
      final data = Map<String, dynamic>.from(jsonDecode(bodyStr) as Map);
      final senderPort = data['senderPort'] as int?;
      // Hard sync: the initiator forces its state onto us, so overwrite our
      // streak / statistics / SRS instead of merging.
      final hardSync = data['hardSync'] as bool? ?? false;
      final connInfo =
          req.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final senderIp = connInfo?.remoteAddress.address;

      final payload = SyncPayload.fromJson(data);

      // Fetch images from sender before importing
      int imagesFailed = 0;
      if (senderIp != null && senderPort != null) {
        final senderBase = 'http://$senderIp:$senderPort';
        for (final imgName in payload.imageFilenames) {
          if (!await _fetchImage(senderBase, imgName)) imagesFailed++;
        }
      }

      _acceptorResult = (await _importPayload(payload, overwriteState: hardSync))
          .withImagesFailed(imagesFailed);
      _scheduleAcceptorFallback();
      await QuestionService().refresh();
      // Return our (post-merge) non-content state so the initiator can merge it
      // back in normal mode. Ignored by the initiator during a hard sync.
      return Response.ok(
        jsonEncode({
          'ok': true,
          'streakData': _buildStreakData(),
          'statisticsData': StatisticsService().exportForSync(),
          'srsData': _buildSrsData(),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'ok': false, 'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handlePull(Request req) async {
    try {
      final bodyStr = await _readBodyWithLimit(req);
      if (bodyStr == null) {
        return Response(413,
            body: jsonEncode({'error': 'Payload too large'}),
            headers: {'content-type': 'application/json'});
      }
      final data = Map<String, dynamic>.from(jsonDecode(bodyStr) as Map);
      final folderIds =
          (data['folderIds'] as List).map((e) => e as String).toList();
      final quizIds =
          (data['quizIds'] as List).map((e) => e as String).toList();
      final questionIds =
          (data['questionIds'] as List).map((e) => e as String).toList();

      final payload = await _buildPayload(
        folderIds: folderIds,
        quizIds: quizIds,
        questionIds: questionIds,
      );
      return Response.ok(
        jsonEncode(payload.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleImage(Request req) async {
    final name = req.url.queryParameters['name'];
    if (name == null || name.isEmpty) return Response.badRequest();
    // Sanitize: only allow basenames, no path traversal
    final safeName = p.basename(name);
    if (safeName.isEmpty || safeName.contains('..')) return Response.badRequest();

    final imgDir = await _getImagesDir();
    final file = File(p.join(imgDir, safeName));

    late final Uint8List bytes;
    if (await file.exists()) {
      bytes = await file.readAsBytes();
    } else {
      // Content pack images are Flutter bundled assets — try the asset bundle
      // when the file doesn't exist on disk (e.g. release builds on Windows).
      try {
        final data = await rootBundle.load('assets/images/$safeName');
        bytes = data.buffer.asUint8List();
      } catch (_) {
        return Response.notFound('Image not found');
      }
    }

    final ext = p.extension(safeName).toLowerCase();
    final contentType = switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'application/octet-stream',
    };
    return Response.ok(bytes, headers: {'content-type': contentType});
  }

  Future<Response> _handleHardDelete(Request req) async {
    try {
      final bodyStr = await _readBodyWithLimit(req);
      if (bodyStr == null) {
        return Response(413,
            body: jsonEncode({'ok': false, 'error': 'Payload too large'}),
            headers: {'content-type': 'application/json'});
      }
      final data = Map<String, dynamic>.from(jsonDecode(bodyStr) as Map);
      final folderIds =
          (data['folderIds'] as List).map((e) => e as String).toList();
      final quizIds =
          (data['quizIds'] as List).map((e) => e as String).toList();
      final questionIds =
          (data['questionIds'] as List).map((e) => e as String).toList();

      int qsDel = 0, qzDel = 0, fDel = 0;
      final deletedQuestionIds = <String>[];

      // All DB deletions in a single transaction so a crash mid-way doesn't
      // leave the database in a partially-deleted state.
      await _db!.transaction(() async {
        // 1. Questions first — avoids re-deletion by deleteQuiz's orphan cleanup
        for (final id in questionIds) {
          if (await _db!.getQuestionById(id) != null) {
            await _db!.deleteQuestion(id);
            deletedQuestionIds.add(id);
            qsDel++;
          }
        }
        // 2. Quizzes — questions already gone, orphan-cleanup is a no-op
        for (final id in quizIds) {
          if (await _db!.getQuizById(id) != null) {
            await _db!.deleteQuiz(id);
            qzDel++;
          }
        }
        // 3. Folder rows only — quiz contents already handled above
        for (final id in folderIds) {
          await _db!.deleteFolderRow(id);
          fDel++;
        }
      });

      // SRS cleanup is Hive — runs outside the Drift transaction
      for (final id in deletedQuestionIds) {
        await SrsService().deleteUserData(id);
      }

      await QuestionService().refresh();

      // Merge delete counts into the push result so the acceptor's done-screen
      // reflects both what was added and what was removed.
      _acceptorResult = SyncResult(
        foldersAdded:       _acceptorResult?.foldersAdded       ?? 0,
        quizzesAdded:       _acceptorResult?.quizzesAdded       ?? 0,
        questionsAdded:     _acceptorResult?.questionsAdded     ?? 0,
        srsUpdated:         _acceptorResult?.srsUpdated         ?? 0,
        favoritesAdded:     _acceptorResult?.favoritesAdded     ?? 0,
        imagesFailedCount:  _acceptorResult?.imagesFailedCount  ?? 0,
        statisticsUpdated:  _acceptorResult?.statisticsUpdated  ?? false,
        foldersDeleted:    fDel,
        quizzesDeleted:    qzDel,
        questionsDeleted:  qsDel,
      );
      _scheduleAcceptorFallback();

      return Response.ok(
        jsonEncode({
          'ok': true,
          'foldersDeleted':   fDel,
          'quizzesDeleted':   qzDel,
          'questionsDeleted': qsDel,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'ok': false, 'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleAdvertise(Request req) async {
    try {
      final body = Map<String, dynamic>.from(
          jsonDecode(await req.readAsString()) as Map);
      final deviceName = body['deviceName'] as String? ?? 'Unknown Device';
      final httpPort = body['httpPort'] as int?;
      final connInfo =
          req.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final ip = connInfo?.remoteAddress.address;
      if (ip != null && httpPort != null) {
        discovery.registerPeer(SyncPeer(
          deviceName: deviceName,
          host: ip,
          port: httpPort,
        ));
      }
      return Response.ok(
        jsonEncode({'ok': true}),
        headers: {'content-type': 'application/json'},
      );
    } catch (_) {
      return Response.ok(
        jsonEncode({'ok': false}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _handleSyncDone(Request req) async {
    _acceptorFallbackTimer?.cancel();
    _acceptorFallbackTimer = null;
    final result = _acceptorResult ?? const SyncResult();
    _acceptorResult = null;
    if (!_acceptorDoneController.isClosed) {
      _acceptorDoneController.add(result);
    }
    return Response.ok(
      jsonEncode({'ok': true}),
      headers: {'content-type': 'application/json'},
    );
  }

  // Starts (or restarts) a fallback timer so the acceptor UI is never left
  // waiting if the initiator's /sync/done signal fails to arrive.
  void _scheduleAcceptorFallback() {
    _acceptorFallbackTimer?.cancel();
    _acceptorFallbackTimer = Timer(const Duration(seconds: 30), () {
      final result = _acceptorResult ?? const SyncResult();
      _acceptorResult = null;
      _acceptorFallbackTimer = null;
      if (!_acceptorDoneController.isClosed) {
        _acceptorDoneController.add(result);
      }
    });
  }

  // ── Initiator: full bidirectional sync ───────────────────────

  Future<SyncResult> syncWith(SyncPeer peer, {bool hardSync = false}) async {
    final base = 'http://${peer.host}:${peer.port}';

    _progress('Connecting to ${peer.deviceName}…');
    final reqResp = await http
        .post(
          Uri.parse('$base/sync/request'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'deviceName': _deviceName, 'httpPort': _httpPort}),
        )
        .timeout(const Duration(seconds: 65));

    final reqData =
        Map<String, dynamic>.from(jsonDecode(reqResp.body) as Map);
    if (reqData['accepted'] != true) {
      throw SyncException(reqData['reason'] as String? ?? 'Sync rejected');
    }

    _progress('Reading remote inventory…');
    final manifestResp = await http
        .get(Uri.parse('$base/sync/manifest'))
        .timeout(const Duration(seconds: 30));
    if (manifestResp.statusCode != 200) {
      throw SyncException('Failed to read remote inventory (${manifestResp.statusCode})');
    }
    final remoteManifest = SyncManifest.fromJson(
        Map<String, dynamic>.from(jsonDecode(manifestResp.body) as Map));

    final localManifest = await _buildManifest();

    // Delta for content
    final localFolderIds =
        localManifest.folders.map((e) => e.id).toSet();
    final localQuizIds =
        localManifest.quizzes.map((e) => e.id).toSet();
    final localQuestionIds =
        localManifest.questions.map((e) => e.id).toSet();
    final remoteFolderIds =
        remoteManifest.folders.map((e) => e.id).toSet();
    final remoteQuizIds =
        remoteManifest.quizzes.map((e) => e.id).toSet();
    final remoteQuestionIds =
        remoteManifest.questions.map((e) => e.id).toSet();

    // Items present on both sides but with different content hashes need
    // reconciling. We resolve the direction by last-write-wins: the side whose
    // copy was modified most recently wins.
    final remoteHashById = {
      for (final e in remoteManifest.folders) e.id: e.contentHash,
      for (final e in remoteManifest.quizzes) e.id: e.contentHash,
      for (final e in remoteManifest.questions) e.id: e.contentHash,
    };
    final localHashById = {
      for (final e in localManifest.folders) e.id: e.contentHash,
      for (final e in localManifest.quizzes) e.id: e.contentHash,
      for (final e in localManifest.questions) e.id: e.contentHash,
    };
    final remoteUpdatedById = {
      for (final e in remoteManifest.folders) e.id: e.updatedAt,
      for (final e in remoteManifest.quizzes) e.id: e.updatedAt,
      for (final e in remoteManifest.questions) e.id: e.updatedAt,
    };
    final localUpdatedById = {
      for (final e in localManifest.folders) e.id: e.updatedAt,
      for (final e in localManifest.quizzes) e.id: e.updatedAt,
      for (final e in localManifest.questions) e.id: e.updatedAt,
    };

    // For shared-but-differing items: remote strictly newer → pull; otherwise
    // (local newer, tie, or either timestamp missing) → push. The fallback
    // preserves the legacy "initiator wins" behavior for ambiguous cases and
    // for peers running an older client that omits updatedAt.
    ({List<String> push, List<String> pull}) classifyChanged(
        Set<String> both) {
      final push = <String>[];
      final pull = <String>[];
      for (final id in both) {
        final localHash = localHashById[id];
        final remoteHash = remoteHashById[id];
        if (localHash == null || remoteHash == null || localHash == remoteHash) {
          continue;
        }
        final localTs = localUpdatedById[id];
        final remoteTs = remoteUpdatedById[id];
        if (localTs != null && remoteTs != null && remoteTs.isAfter(localTs)) {
          pull.add(id);
        } else {
          push.add(id);
        }
      }
      return (push: push, pull: pull);
    }

    final folderChanged =
        classifyChanged(localFolderIds.intersection(remoteFolderIds));
    final quizChanged =
        classifyChanged(localQuizIds.intersection(remoteQuizIds));
    final questionChanged =
        classifyChanged(localQuestionIds.intersection(remoteQuestionIds));

    final toSendFolderIds = [
      ...localFolderIds.difference(remoteFolderIds),
      ...folderChanged.push,
    ];
    final toSendQuizIds = [
      ...localQuizIds.difference(remoteQuizIds),
      ...quizChanged.push,
    ];
    final toSendQuestionIds = [
      ...localQuestionIds.difference(remoteQuestionIds),
      ...questionChanged.push,
    ];

    // Items the initiator lacks entirely. Used verbatim by the hard-delete
    // path, which must only remove remote-only content — never shared items
    // that merely happen to be newer on the remote.
    final remoteOnlyFolderIds =
        remoteFolderIds.difference(localFolderIds).toList();
    final remoteOnlyQuizIds = remoteQuizIds.difference(localQuizIds).toList();
    final remoteOnlyQuestionIds =
        remoteQuestionIds.difference(localQuestionIds).toList();

    // Normal-mode pull set: remote-only items plus shared items the remote
    // changed more recently.
    final toFetchFolderIds = [...remoteOnlyFolderIds, ...folderChanged.pull];
    final toFetchQuizIds = [...remoteOnlyQuizIds, ...quizChanged.pull];
    final toFetchQuestionIds = [
      ...remoteOnlyQuestionIds,
      ...questionChanged.pull,
    ];

    // Favorites delta (additive union)
    final remoteFavIds = remoteManifest.favoriteSyncIds.toSet();
    final localFavIds = localManifest.favoriteSyncIds.toSet();
    final toFetchFavIds =
        remoteFavIds.difference(localFavIds).toList();

    // Push to remote — always, even with no content delta, so streak /
    // statistics / SRS round-trip in every mode. The response carries the
    // acceptor's (post-merge) state for us to merge back in normal mode.
    final hasContentToSend = toSendFolderIds.isNotEmpty ||
        toSendQuizIds.isNotEmpty ||
        toSendQuestionIds.isNotEmpty;
    _progress(hasContentToSend ? 'Sending local content…' : 'Syncing…');
    final pushPayload = await _buildPayload(
      folderIds: toSendFolderIds,
      quizIds: toSendQuizIds,
      questionIds: toSendQuestionIds,
      includeSrs: true,
      includeFavorites: true,
    );
    final pushBody = pushPayload.toJson();
    pushBody['senderPort'] = _httpPort; // Tell remote where to fetch images
    pushBody['hardSync'] = hardSync; // Acceptor overwrites instead of merging
    final pushResp = await http.post(
      Uri.parse('$base/sync/push'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(pushBody),
    ).timeout(const Duration(seconds: 120));
    if (pushResp.statusCode != 200) {
      throw SyncException('Remote failed to import content (${pushResp.statusCode})');
    }

    // Merge the acceptor's non-content state back into us (normal mode only).
    // Hard sync is one-directional: we keep our own state.
    int srsMergedBack = 0;
    bool statsMergedBack = false;
    if (!hardSync) {
      try {
        final respData =
            Map<String, dynamic>.from(jsonDecode(pushResp.body) as Map);
        final streakBack = respData['streakData'] != null
            ? Map<String, dynamic>.from(respData['streakData'] as Map)
            : null;
        final statsBack = respData['statisticsData'] != null
            ? Map<String, dynamic>.from(respData['statisticsData'] as Map)
            : null;
        final srsBack = (respData['srsData'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const <Map<String, dynamic>>[];
        await _applyStreak(streakBack, overwrite: false);
        statsMergedBack = await _applyStatistics(statsBack, overwrite: false);
        srsMergedBack = await _applySrs(srsBack, overwrite: false);
      } catch (_) {} // Non-fatal — content sync already succeeded.
    }

    // Pull remote content (or hard-delete it in override mode)
    SyncResult result = hardSync ? const SyncResult(isHardSync: true) : const SyncResult();
    if (hardSync) {
      if (remoteOnlyFolderIds.isNotEmpty ||
          remoteOnlyQuizIds.isNotEmpty ||
          remoteOnlyQuestionIds.isNotEmpty) {
        _progress('Removing content from ${peer.deviceName}…');
        final hdResp = await http.post(
          Uri.parse('$base/sync/hard-delete'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'folderIds': remoteOnlyFolderIds,
            'quizIds': remoteOnlyQuizIds,
            'questionIds': remoteOnlyQuestionIds,
          }),
        ).timeout(const Duration(seconds: 120));
        if (hdResp.statusCode != 200) {
          throw SyncException(
              'Hard delete failed (${hdResp.statusCode})');
        }
        final hdData =
            Map<String, dynamic>.from(jsonDecode(hdResp.body) as Map);
        result = SyncResult(
          isHardSync: true,
          foldersDeleted:
              (hdData['foldersDeleted'] as num?)?.toInt() ?? 0,
          quizzesDeleted:
              (hdData['quizzesDeleted'] as num?)?.toInt() ?? 0,
          questionsDeleted:
              (hdData['questionsDeleted'] as num?)?.toInt() ?? 0,
        );
      }
      // Favorites: skip pull in hard-sync mode (our favorites were already pushed)
    } else {
      if (toFetchFolderIds.isNotEmpty ||
          toFetchQuizIds.isNotEmpty ||
          toFetchQuestionIds.isNotEmpty ||
          toFetchFavIds.isNotEmpty) {
        _progress('Fetching remote content…');
        final pullResp = await http.post(
          Uri.parse('$base/sync/pull'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'folderIds': toFetchFolderIds,
            'quizIds': toFetchQuizIds,
            'questionIds': toFetchQuestionIds,
          }),
        ).timeout(const Duration(seconds: 120));
        if (pullResp.statusCode != 200) {
          throw SyncException(
              'Failed to fetch remote content (${pullResp.statusCode})');
        }
        final fetchedPayload = SyncPayload.fromJson(
            Map<String, dynamic>.from(jsonDecode(pullResp.body) as Map));

        _progress('Downloading images…');
        int imagesFailed = 0;
        for (final imgName in fetchedPayload.imageFilenames) {
          if (!await _fetchImage(base, imgName)) imagesFailed++;
        }

        _progress('Importing content…');
        // Non-content state already round-tripped via the push response above.
        result = (await _importPayload(fetchedPayload,
                applyNonContentState: false))
            .withImagesFailed(imagesFailed);

        // Also apply remote favorites we don't have yet
        for (final favId in toFetchFavIds) {
          await FavoritesService().addFavorite(favId);
        }
      }
    }

    // Reflect the non-content state merged back from the acceptor (normal mode).
    if (srsMergedBack > 0 || statsMergedBack) {
      result = result.copyWith(
        srsUpdated: result.srsUpdated + srsMergedBack,
        statisticsUpdated: result.statisticsUpdated || statsMergedBack,
      );
    }

    await QuestionService().refresh();
    _progress('Sync complete!');

    // Signal to the acceptor that the initiator is done so it can show its result.
    try {
      await http
          .post(Uri.parse('$base/sync/done'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({}))
          .timeout(const Duration(seconds: 5));
    } catch (_) {} // Non-fatal — acceptor will time out gracefully if this fails.

    return result;
  }

  // ── Manifest ─────────────────────────────────────────────────

  Future<SyncManifest> _buildManifest() async {
    final foldersRows = await _db!.getAllFolders();
    final quizzesRows = await _db!.getAllQuizzes();
    final questionsRows = await _db!.getAllQuestions();

    // SRS keys are UUID question IDs directly — no bridge conversion needed
    final srsKeys = SrsService().getAllUserData().map((d) => d.questionId).toList();

    final favIds = FavoritesService().getAllFavoriteIds();

    // Quiz hashes include their ordered question membership so that adding,
    // removing, or reordering questions in a shared quiz is detected as a
    // change (the quiz's own columns are otherwise untouched by those edits).
    final quizEntries = <SyncEntry>[];
    for (final q in quizzesRows) {
      final memberIds =
          (await _db!.getQuestionsForQuiz(q.id)).map((e) => e.id).join(',');
      quizEntries.add(SyncEntry(
        id: q.id,
        createdAt: q.createdAt,
        updatedAt: q.updatedAt,
        contentHash:
            '${q.title}|${q.folderId ?? ''}|${q.imagePath ?? ''}|${q.languageCode ?? ''}|$memberIds',
      ));
    }

    return SyncManifest(
      folders: foldersRows
          .map((f) => SyncEntry(
                id: f.id,
                createdAt: f.createdAt,
                updatedAt: f.updatedAt,
                contentHash:
                    '${f.title}|${f.parentFolderId ?? ''}|${f.imagePath ?? ''}',
              ))
          .toList(),
      quizzes: quizEntries,
      questions: questionsRows
          .map((q) => SyncEntry(
                id: q.id,
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                updatedAt: q.updatedAt,
                contentHash: [
                  q.questionText,
                  q.questionVariants ?? '',
                  q.answerType,
                  q.answerConfig,
                  q.explanation ?? '',
                  q.imagePath ?? '',
                  q.imagePathVariants ?? '',
                  q.occlusionConfig ?? '',
                ].join('|'),
              ))
          .toList(),
      srsKeys: srsKeys,
      favoriteSyncIds: favIds,
    );
  }

  // ── Payload building ─────────────────────────────────────────

  Future<SyncPayload> _buildPayload({
    required List<String> folderIds,
    required List<String> quizIds,
    required List<String> questionIds,
    bool includeSrs = false,
    bool includeFavorites = false,
  }) async {
    final foldersJson = <Map<String, dynamic>>[];
    for (final id in folderIds) {
      final f = await _db!.getFolderById(id);
      if (f == null) continue;
      foldersJson.add({
        'id': f.id,
        'parentId': f.parentFolderId,
        'title': f.title,
        'imageName':
            f.imagePath != null ? p.basename(f.imagePath!) : null,
        'updatedAt': f.updatedAt.toIso8601String(),
      });
    }

    final quizzesJson = <Map<String, dynamic>>[];
    for (final id in quizIds) {
      final quiz = await _db!.getQuizById(id);
      if (quiz == null) continue;
      final questionsInQuiz = await _db!.getQuestionsForQuiz(quiz.id);
      quizzesJson.add({
        'id': quiz.id,
        'folderId': quiz.folderId,
        'title': quiz.title,
        'imageName':
            quiz.imagePath != null ? p.basename(quiz.imagePath!) : null,
        'languageCode': quiz.languageCode,
        'questionIds': questionsInQuiz.map((q) => q.id).toList(),
        'updatedAt': quiz.updatedAt.toIso8601String(),
      });
    }

    final questionsJson = <Map<String, dynamic>>[];
    final imageFilenames = <String>{};

    for (final id in questionIds) {
      final q = await _db!.getQuestionById(id);
      if (q == null) continue;
      final config =
          Map<String, dynamic>.from(jsonDecode(q.answerConfig) as Map);

      // Replace full paths with basenames in flashcard config
      final syncConfig = _normalizeConfigImagePaths(config, q.answerType, imageFilenames);

      if (q.imagePath != null) imageFilenames.add(p.basename(q.imagePath!));

      // Collect all image variant basenames
      List<String>? imageVariants;
      if (q.imagePathVariants != null) {
        final paths = List<String>.from(
            jsonDecode(q.imagePathVariants!) as List);
        imageVariants = paths.map((path) {
          final name = p.basename(path);
          imageFilenames.add(name);
          return name;
        }).toList();
      }

      // Normalize occlusionConfig path keys to basenames
      final normalizedOcclusion = _normalizeOcclusionConfig(
          q.occlusionConfig, q.answerType, imageFilenames);

      questionsJson.add({
        'id': q.id,
        'questionText': q.questionText,
        'questionVariants': q.questionVariants != null
            ? jsonDecode(q.questionVariants!)
            : null,
        'answerType': q.answerType,
        'answerConfig': syncConfig,
        'explanation': q.explanation,
        'imageName':
            q.imagePath != null ? p.basename(q.imagePath!) : null,
        // if-elements (not the `?x` null-aware form) so build_runner's older
        // bundled analyzer can parse this file during code generation.
        // ignore: use_null_aware_elements
        if (imageVariants != null) 'imageVariants': imageVariants,
        // ignore: use_null_aware_elements
        if (normalizedOcclusion != null) 'occlusionConfig': normalizedOcclusion,
        'updatedAt': q.updatedAt.toIso8601String(),
      });
    }

    // Collect folder + quiz image names
    for (final fj in foldersJson) {
      if (fj['imageName'] != null) imageFilenames.add(fj['imageName'] as String);
    }
    for (final qj in quizzesJson) {
      if (qj['imageName'] != null) imageFilenames.add(qj['imageName'] as String);
    }

    // SRS data — question IDs are UUID strings directly
    final srsDataJson = includeSrs ? _buildSrsData() : <Map<String, dynamic>>[];

    // Favorites
    final favIds = includeFavorites
        ? FavoritesService().getAllFavoriteIds()
        : <String>[];

    return SyncPayload(
      folders: foldersJson,
      quizzes: quizzesJson,
      questions: questionsJson,
      srsData: srsDataJson,
      favoriteSyncIds: favIds,
      imageFilenames: imageFilenames.toList(),
      // Streak — always included so peers can merge/overwrite. Per-device
      // settings (notifs, enabled toggle) are intentionally excluded.
      streakData: _buildStreakData(),
      statisticsData: StatisticsService().exportForSync(),
    );
  }

  /// Serializes the local streak state for a sync payload / push response.
  Map<String, dynamic> _buildStreakData() {
    final streak = StreakService();
    return {
      'streakCount': streak.currentStreak,
      'highestStreak': streak.highestStreak,
      'lastActivityDate': streak.lastActivityDate,
      'freezesUsedThisWeek': streak.freezesUsedThisWeek,
      'weekAnchor': streak.weekAnchor,
    };
  }

  /// Serializes all local SRS entries for a sync payload / push response.
  List<Map<String, dynamic>> _buildSrsData() {
    final out = <Map<String, dynamic>>[];
    for (final data in SrsService().getAllUserData()) {
      out.add({
        'questionId': data.questionId,
        'streak': data.streak,
        'easeFactor': data.easeFactor,
        'intervalSeconds': data.intervalSeconds,
        'lastReviewed': data.lastReviewed.toIso8601String(),
        'nextReview': data.nextReview.toIso8601String(),
        'spacedRepetitionEnabled': data.spacedRepetitionEnabled,
      });
    }
    return out;
  }

  Map<String, dynamic> _normalizeConfigImagePaths(
    Map<String, dynamic> config,
    String answerType,
    Set<String> imageFilenames,
  ) {
    if (answerType != 'flashcard') return config;
    final result = Map<String, dynamic>.from(config);
    if (result['frontImagePath'] != null) {
      final name = p.basename(result['frontImagePath'] as String);
      imageFilenames.add(name);
      result['frontImagePath'] = name;
    }
    if (result['backImagePath'] != null) {
      final name = p.basename(result['backImagePath'] as String);
      imageFilenames.add(name);
      result['backImagePath'] = name;
    }
    return result;
  }

  /// Normalizes occlusionConfig path keys to basenames for network transfer.
  /// For flashcard questions the keys are 'front'/'back' (not paths) — skip them.
  Map<String, dynamic>? _normalizeOcclusionConfig(
    String? occlusionConfigJson,
    String answerType,
    Set<String> imageFilenames,
  ) {
    if (occlusionConfigJson == null) return null;
    final config =
        Map<String, dynamic>.from(jsonDecode(occlusionConfigJson) as Map);
    if (config['v'] != 2) return config;
    final perImage =
        Map<String, dynamic>.from(config['perImage'] as Map);
    if (answerType == 'flashcard') return config;
    final normalized = <String, dynamic>{};
    for (final entry in perImage.entries) {
      final name = p.basename(entry.key);
      imageFilenames.add(name);
      normalized[name] = entry.value;
    }
    return {'v': 2, 'perImage': normalized};
  }

  /// Localizes occlusionConfig basename keys back to full paths after receiving.
  Map<String, dynamic>? _localizeOcclusionConfig(
    dynamic occlusionConfigRaw,
    String answerType,
    String imgDir,
  ) {
    if (occlusionConfigRaw == null) return null;
    final config =
        Map<String, dynamic>.from(occlusionConfigRaw as Map);
    if (config['v'] != 2) return config;
    final perImage =
        Map<String, dynamic>.from(config['perImage'] as Map);
    if (answerType == 'flashcard') return config;
    final localized = <String, dynamic>{};
    for (final entry in perImage.entries) {
      localized[p.join(imgDir, entry.key)] = entry.value;
    }
    return {'v': 2, 'perImage': localized};
  }

  // ── Import ───────────────────────────────────────────────────

  /// Parses an ISO-8601 `updatedAt` value from a payload map; null when absent
  /// (older client) or unparseable.
  static DateTime? _parseTs(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Imports content (+ favorites) from [payload].
  ///
  /// When [applyNonContentState] is true, also applies streak / statistics /
  /// SRS — in merge mode (highest/newer wins) by default, or in overwrite mode
  /// (mirror the sender) when [overwriteState] is true. The pull path passes
  /// false because that state round-trips via the push response instead.
  Future<SyncResult> _importPayload(
    SyncPayload payload, {
    bool applyNonContentState = true,
    bool overwriteState = false,
  }) async {
    int foldersAdded = 0, quizzesAdded = 0, questionsAdded = 0;
    int foldersUpdated = 0, quizzesUpdated = 0, questionsUpdated = 0;
    int srsUpdated = 0, favoritesAdded = 0;

    final imgDir = await _getImagesDir();
    final folderIdMap = <String, String>{};
    final questionIdMap = <String, String>{};

    await _db!.transaction(() async {
      // 1. Questions (no dependencies)
      for (final qJson in payload.questions) {
        final id = qJson['id'] as String;

        final answerType = qJson['answerType'] as String;
        final configRaw =
            Map<String, dynamic>.from(qJson['answerConfig'] as Map);
        final localConfig =
            _localizeConfigImagePaths(configRaw, answerType, imgDir);

        final variants =
            (qJson['questionVariants'] as List?)?.map((e) => e as String).toList();
        final questionText = variants?.isNotEmpty == true
            ? variants!.first
            : qJson['questionText'] as String? ?? '';

        String? imagePath;
        final imgName = qJson['imageName'] as String?;
        if (imgName != null) {
          final safe = p.basename(imgName);
          if (safe.isNotEmpty) imagePath = p.join(imgDir, safe);
        }

        // Localize imagePathVariants basenames to full paths
        final imageVariantsRaw = qJson['imageVariants'] as List?;
        String? imagePathVariants;
        if (imageVariantsRaw != null) {
          final localPaths = imageVariantsRaw
              .map((n) => p.join(imgDir, p.basename(n as String)))
              .toList();
          imagePathVariants = jsonEncode(localPaths);
        }

        // Localize occlusionConfig path keys
        final occlusionRaw = qJson['occlusionConfig'];
        String? occlusionConfig;
        if (occlusionRaw != null) {
          final localized =
              _localizeOcclusionConfig(occlusionRaw, answerType, imgDir);
          if (localized != null) occlusionConfig = jsonEncode(localized);
        }

        final incomingTs = _parseTs(qJson['updatedAt']);
        final existing = await _db!.getQuestionById(id);
        if (existing != null) {
          questionIdMap[id] = existing.id;
          // Last-write-wins: keep the local copy when it is strictly newer.
          if (incomingTs != null && existing.updatedAt.isAfter(incomingTs)) {
            continue;
          }
          await _db!.updateQuestion(QuestionsCompanion(
            id: Value(id),
            questionText: Value(questionText),
            questionVariants: (variants != null && variants.length > 1)
                ? Value(jsonEncode(variants))
                : const Value<String?>(null),
            answerType: Value(answerType),
            answerConfig: Value(jsonEncode(localConfig)),
            explanation: Value(qJson['explanation'] as String?),
            imagePath: Value(imagePath),
            imagePathVariants: Value(imagePathVariants),
            occlusionConfig: Value(occlusionConfig),
            updatedAt:
                incomingTs != null ? Value(incomingTs) : const Value.absent(),
          ));
          questionsUpdated++;
          continue;
        }

        final newId = await _db!.insertQuestion(QuestionsCompanion(
          id: Value(id),
          questionText: Value(questionText),
          questionVariants: variants != null && variants.length > 1
              ? Value(jsonEncode(variants))
              : const Value.absent(),
          answerType: Value(answerType),
          answerConfig: Value(jsonEncode(localConfig)),
          explanation: Value(qJson['explanation'] as String?),
          imagePath: Value(imagePath),
          imagePathVariants: Value(imagePathVariants),
          occlusionConfig: Value(occlusionConfig),
          updatedAt:
              incomingTs != null ? Value(incomingTs) : const Value.absent(),
        ));
        questionIdMap[id] = newId;
        questionsAdded++;
      }

      // 2. Folders — first pass: insert (without parent) or update in place.
      // Existing folders get their parent set directly here; newly inserted
      // folders are wired up in the second pass.
      final newFolderIds = <String>{};
      for (final fJson in payload.folders) {
        final id = fJson['id'] as String;

        String? imagePath;
        final imgName = fJson['imageName'] as String?;
        if (imgName != null) {
          final safe = p.basename(imgName);
          if (safe.isNotEmpty) imagePath = p.join(imgDir, safe);
        }

        final incomingTs = _parseTs(fJson['updatedAt']);
        final existing = await _db!.getFolderById(id);
        if (existing != null) {
          folderIdMap[id] = existing.id;
          // Last-write-wins: keep the local copy when it is strictly newer.
          if (incomingTs != null && existing.updatedAt.isAfter(incomingTs)) {
            continue;
          }
          await _db!.updateFolder(FoldersCompanion(
            id: Value(id),
            parentFolderId: Value(fJson['parentId'] as String?),
            title: Value(fJson['title'] as String),
            imagePath: Value(imagePath),
            updatedAt:
                incomingTs != null ? Value(incomingTs) : const Value.absent(),
          ));
          foldersUpdated++;
          continue;
        }

        final newId = await _db!.insertFolder(FoldersCompanion(
          id: Value(id),
          title: Value(fJson['title'] as String),
          imagePath: Value(imagePath),
          updatedAt:
              incomingTs != null ? Value(incomingTs) : const Value.absent(),
        ));
        folderIdMap[id] = newId;
        newFolderIds.add(id);
        foldersAdded++;
      }
      // Second pass: wire up parents for newly inserted folders. Resolve the
      // parent via the import map, falling back to a DB lookup so a new folder
      // nested under a pre-existing (unchanged, not-in-payload) parent is not
      // orphaned to the root.
      for (final fJson in payload.folders) {
        final id = fJson['id'] as String;
        if (!newFolderIds.contains(id)) continue;
        final parentId = fJson['parentId'] as String?;
        if (parentId == null) continue;
        final localId = folderIdMap[id];
        final parentLocalId =
            folderIdMap[parentId] ?? (await _db!.getFolderById(parentId))?.id;
        if (localId != null && parentLocalId != null) {
          await _db!.updateFolderParentId(localId, parentLocalId);
        }
      }

      // 3. Quizzes + junction rows
      for (final qzJson in payload.quizzes) {
        final id = qzJson['id'] as String;
        String quizLocalId;

        final folderId = qzJson['folderId'] as String?;
        final folderLocalId = folderId != null
            ? (folderIdMap[folderId] ??
                (await _db!.getFolderById(folderId))?.id)
            : null;

        String? imagePath;
        final imgName = qzJson['imageName'] as String?;
        if (imgName != null) {
          final safe = p.basename(imgName);
          if (safe.isNotEmpty) imagePath = p.join(imgDir, safe);
        }

        final incomingTs = _parseTs(qzJson['updatedAt']);
        final existing = await _db!.getQuizById(id);
        // Incoming wins unless the local copy is strictly newer.
        final bool quizIncomingWins = existing == null ||
            !(incomingTs != null && existing.updatedAt.isAfter(incomingTs));
        if (existing != null) {
          quizLocalId = existing.id;
          if (quizIncomingWins) {
            await _db!.updateQuiz(QuizzesCompanion(
              id: Value(id),
              folderId: Value(folderLocalId),
              title: Value(qzJson['title'] as String),
              imagePath: Value(imagePath),
              languageCode: Value(qzJson['languageCode'] as String?),
              updatedAt: incomingTs != null
                  ? Value(incomingTs)
                  : const Value.absent(),
            ));
            quizzesUpdated++;
          }
        } else {
          quizLocalId = await _db!.insertQuiz(QuizzesCompanion(
            id: Value(id),
            folderId: Value(folderLocalId),
            title: Value(qzJson['title'] as String),
            imagePath: Value(imagePath),
            languageCode: Value(qzJson['languageCode'] as String?),
            updatedAt:
                incomingTs != null ? Value(incomingTs) : const Value.absent(),
          ));
          quizzesAdded++;
        }

        // Resolve the sender's full ordered membership to local question IDs.
        final orderedLocalIds = <String>[];
        for (final qId
            in (qzJson['questionIds'] as List).map((e) => e as String)) {
          var qLocalId = questionIdMap[qId];
          if (qLocalId == null) {
            // Question already exists locally but wasn't included in this payload
            // (e.g. peer has it, so it was excluded from the delta).
            final localQ = await _db!.getQuestionById(qId);
            if (localQ != null) qLocalId = localQ.id;
          }
          if (qLocalId != null) orderedLocalIds.add(qLocalId);
        }

        if (quizIncomingWins) {
          // Full replace — propagates additions, reorders, and removals.
          await _db!.replaceQuizJunctions(quizLocalId, orderedLocalIds);
        } else {
          // Local quiz is newer: keep its membership/order, but additively wire
          // up any brand-new questions so they aren't orphaned.
          int order = 0;
          for (final qLocalId in orderedLocalIds) {
            await _db!.insertJunctionRowSafe(quizLocalId, qLocalId, order++);
          }
        }
      }
    });

    // Favorites (outside transaction — Hive)
    // Only add favorites whose quiz was actually imported (prevents broken refs).
    for (final favId in payload.favoriteSyncIds) {
      if (!FavoritesService().isFavorite(favId)) {
        final quizExists = await _db!.getQuizById(favId) != null;
        if (quizExists) {
          await FavoritesService().addFavorite(favId);
          favoritesAdded++;
        }
      }
    }

    // Non-content state (streak / statistics / SRS).
    bool statsWereMerged = false;
    if (applyNonContentState) {
      srsUpdated = await _applySrs(payload.srsData, overwrite: overwriteState);
      await _applyStreak(payload.streakData, overwrite: overwriteState);
      statsWereMerged =
          await _applyStatistics(payload.statisticsData, overwrite: overwriteState);
    }

    return SyncResult(
      foldersAdded: foldersAdded,
      quizzesAdded: quizzesAdded,
      questionsAdded: questionsAdded,
      foldersUpdated: foldersUpdated,
      quizzesUpdated: quizzesUpdated,
      questionsUpdated: questionsUpdated,
      srsUpdated: srsUpdated,
      favoritesAdded: favoritesAdded,
      statisticsUpdated: statsWereMerged,
    );
  }

  // ── Non-content state apply (merge vs overwrite) ─────────────
  // Merge mode (normal sync): highest streak / newer review / max stats win.
  // Overwrite mode (hard sync): this device is forced to mirror the sender.

  Future<void> _applyStreak(Map<String, dynamic>? streakData,
      {required bool overwrite}) async {
    if (streakData == null) return;
    final count = (streakData['streakCount'] as num?)?.toInt() ?? 0;
    final lastDate = streakData['lastActivityDate'] as String?;
    final freezes = (streakData['freezesUsedThisWeek'] as num?)?.toInt() ?? 0;
    final weekAnchor = streakData['weekAnchor'] as String?;
    final highest = (streakData['highestStreak'] as num?)?.toInt() ?? 0;
    if (overwrite) {
      await StreakService().overwriteFromSync(
        remoteCount: count,
        remoteLastDate: lastDate,
        remoteFreezesUsed: freezes,
        remoteWeekAnchor: weekAnchor,
        remoteHighestStreak: highest,
      );
    } else {
      await StreakService().mergeFromSync(
        remoteCount: count,
        remoteLastDate: lastDate,
        remoteFreezesUsed: freezes,
        remoteWeekAnchor: weekAnchor,
        remoteHighestStreak: highest,
      );
    }
  }

  Future<bool> _applyStatistics(Map<String, dynamic>? statsData,
      {required bool overwrite}) async {
    if (statsData == null) return false;
    if (overwrite) {
      await StatisticsService().replaceFromSync(statsData);
    } else {
      await StatisticsService().mergeFromSync(statsData);
    }
    return true;
  }

  /// Applies incoming SRS entries (skipping ones whose question is absent
  /// locally). Returns the number of SRS-enabled entries applied.
  Future<int> _applySrs(List<Map<String, dynamic>> srsData,
      {required bool overwrite}) async {
    final entries = <UserQuestionData>[];
    for (final srsJson in srsData) {
      final questionId = srsJson['questionId'] as String;
      if (await _db!.getQuestionById(questionId) == null) continue;
      entries.add(UserQuestionData(
        questionId: questionId,
        streak: (srsJson['streak'] as num).toInt(),
        easeFactor: (srsJson['easeFactor'] as num).toDouble(),
        intervalSeconds: (srsJson['intervalSeconds'] as num).toDouble(),
        spacedRepetitionEnabled: srsJson['spacedRepetitionEnabled'] as bool,
        lastReviewed: DateTime.parse(srsJson['lastReviewed'] as String),
        nextReview: DateTime.parse(srsJson['nextReview'] as String),
      ));
    }
    if (overwrite) {
      await SrsService().replaceAllFromSync(entries);
    } else {
      for (final e in entries) {
        await SrsService().upsertUserData(e);
      }
    }
    return entries.where((e) => e.spacedRepetitionEnabled).length;
  }

  Map<String, dynamic> _localizeConfigImagePaths(
    Map<String, dynamic> config,
    String answerType,
    String imgDir,
  ) {
    if (answerType != 'flashcard') return config;
    final result = Map<String, dynamic>.from(config);
    if (result['frontImagePath'] != null) {
      final name = p.basename(result['frontImagePath'] as String);
      result['frontImagePath'] = name.isNotEmpty ? p.join(imgDir, name) : null;
    }
    if (result['backImagePath'] != null) {
      final name = p.basename(result['backImagePath'] as String);
      result['backImagePath'] = name.isNotEmpty ? p.join(imgDir, name) : null;
    }
    return result;
  }

  // ── Image transfer ───────────────────────────────────────────

  // Returns true if the image is available locally after the call (either it
  // already existed or was successfully downloaded), false on failure.
  Future<bool> _fetchImage(String base, String imageName) async {
    final safeName = p.basename(imageName);
    if (safeName.isEmpty) return true;
    final imgDir = await _getImagesDir();
    final localFile = File(p.join(imgDir, safeName));
    if (await localFile.exists()) return true;
    try {
      final resp = await http
          .get(Uri.parse('$base/sync/image?name=${Uri.encodeComponent(safeName)}'))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        await localFile.writeAsBytes(resp.bodyBytes);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Utilities ────────────────────────────────────────────────

  Future<String> _getImagesDir() async {
    if (kDebugMode) {
      return '${Directory.current.path}/assets/images';
    }
    final docDir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${docDir.path}/images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    return imgDir.path;
  }

  String get _deviceName {
    if (_myDeviceName.isNotEmpty) return _myDeviceName;
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Leerlus Device';
    }
  }

  void _progress(String message) {
    if (!_syncProgressController.isClosed) _syncProgressController.add(message);
  }

  void dispose() {
    _server?.close();
    _acceptorFallbackTimer?.cancel();
    discovery.dispose();
    _syncProgressController.close();
    _incomingRequestController.close();
    _acceptorDoneController.close();
  }
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}
