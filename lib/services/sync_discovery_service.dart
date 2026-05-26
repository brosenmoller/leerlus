import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:leerlus/models/sync_models.dart';

class SyncDiscoveryService {
  static const int _discoveryPort = 47562;
  static const String _magic = 'Leerlus_SYNC';
  static const Duration _broadcastInterval = Duration(seconds: 3);
  static const Duration _peerTimeout = Duration(seconds: 12);

  RawDatagramSocket? _socket;
  final List<RawDatagramSocket> _broadcastSockets = [];
  Timer? _broadcastTimer;
  Timer? _pruneTimer;
  String? _deviceName;
  int? _httpPort;
  Set<String> _localIps = {};

  final _peers = <String, _PeerEntry>{};
  final _peersController = StreamController<List<SyncPeer>>.broadcast();

  Stream<List<SyncPeer>> get peersStream => _peersController.stream;
  List<SyncPeer> get currentPeers => _peers.values.map((e) => e.peer).toList();

  static const _wifiChannel = MethodChannel('com.nebaj.leerlus/wifi');

  Future<void> start({required String deviceName, required int httpPort}) async {
    if (_socket != null) return;
    _deviceName = deviceName;
    _httpPort = httpPort;
    _localIps = await _getLocalIps();

    // Android drops broadcast/multicast packets unless a multicast lock is held.
    if (Platform.isAndroid) {
      try {
        await _wifiChannel.invokeMethod('acquireMulticastLock');
      } catch (_) {}
    }

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort,
        reuseAddress: true, reusePort: false);
    _socket!.broadcastEnabled = true;
    _socket!.listen(_onDatagram);

    // Create per-interface sockets so broadcasts go through every active
    // network adapter (fixes Windows routing built-in quizzes 255.255.255.255 through
    // the wrong adapter instead of the WiFi one the phone is on).
    for (final ip in _localIps) {
      if (!_isUsableIp(ip)) continue;
      try {
        final s = await RawDatagramSocket.bind(
            InternetAddress(ip), 0, reuseAddress: true);
        s.broadcastEnabled = true;
        _broadcastSockets.add(s);
      } catch (_) {}
    }

    _broadcastTimer = Timer.periodic(_broadcastInterval, (_) => _broadcast());
    _broadcast();
    _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) => _prunePeers());
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _pruneTimer?.cancel();
    _broadcastTimer = null;
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    for (final s in _broadcastSockets) {
      s.close();
    }
    _broadcastSockets.clear();
    _peers.clear();
    if (!_peersController.isClosed) _peersController.add([]);
    if (Platform.isAndroid) {
      try {
        await _wifiChannel.invokeMethod('releaseMulticastLock');
      } catch (_) {}
    }
  }

  void _broadcast() {
    if (_socket == null || _deviceName == null || _httpPort == null) return;
    final msg = '$_magic:$_deviceName:$_httpPort';
    final data = msg.codeUnits;
    // Send from each interface-bound socket so the broadcast reaches peers on
    // every adapter (important on Windows where 255.255.255.255 may be routed
    // through a virtual adapter rather than the active WiFi interface).
    for (final s in _broadcastSockets) {
      try {
        s.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
      } catch (_) {}
    }
    // Fallback via the main anyIPv4 socket.
    try {
      _socket!.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
    } catch (_) {}
  }

  static bool _isUsableIp(String ip) {
    if (ip.contains(':')) return false; // IPv6 — not used for LAN broadcast
    if (ip.startsWith('127.')) return false; // Loopback
    if (ip.startsWith('169.254.')) return false; // Link-local / APIPA
    return true;
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    final senderIp = datagram.address.address;
    if (_localIps.contains(senderIp)) return;

    final msg = String.fromCharCodes(datagram.data);
    final parts = msg.split(':');
    if (parts.length < 3 || parts[0] != _magic) return;

    final deviceName = parts[1];
    final port = int.tryParse(parts[2]);
    if (port == null) return;

    // Key by IP only so that if the remote server restarts on a new port the
    // entry is updated in-place rather than creating a duplicate stale entry.
    final key = senderIp;
    final peer = SyncPeer(deviceName: deviceName, host: senderIp, port: port);
    // Once we receive a UDP broadcast, the peer is self-refreshing — no longer
    // needs the persistent flag set by registerPeer().
    _peers[key] = _PeerEntry(peer: peer, lastSeen: DateTime.now());
    if (!_peersController.isClosed) _peersController.add(currentPeers);
  }

  /// Register a peer discovered via an incoming HTTP connection rather than UDP.
  /// Persists until [stop] is called (not subject to the UDP prune timer),
  /// unless the peer is later heard via UDP broadcast.
  void registerPeer(SyncPeer peer) {
    final key = peer.host;
    _peers[key] = _PeerEntry(peer: peer, lastSeen: DateTime.now(), persistent: true);
    if (!_peersController.isClosed) _peersController.add(currentPeers);
  }

  void _prunePeers() {
    final cutoff = DateTime.now().subtract(_peerTimeout);
    final before = _peers.length;
    _peers.removeWhere((_, e) => !e.persistent && e.lastSeen.isBefore(cutoff));
    if (_peers.length != before && !_peersController.isClosed) {
      _peersController.add(currentPeers);
    }
  }

  static Future<Set<String>> _getLocalIps() async {
    try {
      final interfaces = await NetworkInterface.list();
      return interfaces.expand((i) => i.addresses).map((a) => a.address).toSet();
    } catch (_) {
      return {};
    }
  }

  void dispose() {
    stop();
    _peersController.close();
  }
}

class _PeerEntry {
  final SyncPeer peer;
  DateTime lastSeen;
  // True for peers registered via HTTP (not UDP) — exempt from prune timer.
  final bool persistent;
  _PeerEntry({required this.peer, required this.lastSeen, this.persistent = false});
}
