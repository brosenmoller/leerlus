import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leerlus/data/database/app_database.dart';
import 'package:leerlus/l10n/app_localizations.dart';
import 'package:leerlus/models/sync_models.dart';
import 'package:leerlus/services/sync_service.dart';
import 'package:permission_handler/permission_handler.dart';

enum _SyncState { idle, requesting, syncing, done, error }

class SyncScreen extends StatefulWidget {
  final AppDatabase db;

  const SyncScreen({super.key, required this.db});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  static const _wifiChannel = MethodChannel('com.nebaj.leerlus/wifi');

  final _syncService = SyncService();

  _SyncState _state = _SyncState.idle;
  List<SyncPeer> _peers = [];
  String _statusMessage = '';
  SyncResult? _result;
  String? _error;
  String _thisDeviceName = '';
  SyncPeer? _lastSyncedPeer;

  bool _setupError = false;
  String _setupErrorMessage = '';

  // Permission state (Android 12+ only)
  bool _permissionGranted = true;
  bool _permissionPermanentlyDenied = false;

  late final StreamSubscription<List<SyncPeer>> _peersSub;
  late final StreamSubscription<String> _requestSub;
  late final StreamSubscription<String> _progressSub;
  late final StreamSubscription<SyncResult> _acceptorDoneSub;

  @override
  void initState() {
    super.initState();
    _peersSub = _syncService.discovery.peersStream.listen((peers) {
      if (mounted) setState(() => _peers = peers);
    });
    _requestSub = _syncService.incomingRequests.listen(_onIncomingRequest);
    _progressSub = _syncService.syncProgress.listen((msg) {
      if (mounted) setState(() => _statusMessage = msg);
    });
    _acceptorDoneSub = _syncService.acceptorSyncComplete.listen((result) {
      if (mounted) setState(() {
        _state = _SyncState.done;
        _result = result;
      });
    });
    _checkPermissionAndInit();
  }

  // ── Permission ────────────────────────────────────────────────

  Future<void> _checkPermissionAndInit() async {
    if (!Platform.isAndroid) {
      _initAndStartDiscovery();
      return;
    }
    // NEARBY_WIFI_DEVICES is a runtime permission only on Android 12+ (API 31+).
    // On older versions, UDP socket operations need no dangerous permission.
    final sdkInt = await _wifiChannel.invokeMethod<int>('getSdkInt') ?? 0;
    if (sdkInt < 31) {
      _initAndStartDiscovery();
      return;
    }
    final status = await Permission.nearbyWifiDevices.status;
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (_permissionGranted) _initAndStartDiscovery();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.nearbyWifiDevices.request();
    if (!mounted) return;
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    if (_permissionGranted) _initAndStartDiscovery();
  }

  // ── Discovery ─────────────────────────────────────────────────

  Future<void> _initAndStartDiscovery() async {
    if (mounted) setState(() { _setupError = false; _setupErrorMessage = ''; });
    try {
      // Start the HTTP server (triggers Windows Firewall prompt if needed).
      await _syncService.init(widget.db);

      String deviceName;
      try {
        if (Platform.isAndroid) {
          // Platform.localHostname returns "localhost" on Android — use Build.MODEL.
          deviceName = await _wifiChannel.invokeMethod<String>('getDeviceName')
              ?? 'Android Device';
        } else {
          deviceName = Platform.localHostname;
        }
      } catch (_) {
        deviceName = 'Leerlus';
      }

      if (mounted) setState(() => _thisDeviceName = deviceName);
      await _syncService.startDiscovery(deviceName);
      if (mounted) setState(() => _peers = _syncService.discovery.currentPeers);
    } catch (e) {
      if (mounted) setState(() {
        _setupError = true;
        _setupErrorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    // Shut down the server so no background ports are held open.
    _syncService.shutdown();
    _peersSub.cancel();
    _requestSub.cancel();
    _progressSub.cancel();
    _acceptorDoneSub.cancel();
    super.dispose();
  }

  // ── Sync flow ─────────────────────────────────────────────────

  void _onIncomingRequest(String incomingDeviceName) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncAcceptTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DevicePairRow(
              thisDevice: _thisDeviceName.isNotEmpty
                  ? _thisDeviceName
                  : l10n.syncThisDevice,
              otherDevice: incomingDeviceName,
            ),
            const SizedBox(height: 12),
            Text(l10n.syncAcceptMessage(incomingDeviceName)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _syncService.respondToRequest(false);
              Navigator.pop(ctx);
            },
            child: Text(l10n.syncReject),
          ),
          FilledButton(
            onPressed: () {
              _syncService.respondToRequest(true);
              Navigator.pop(ctx);
              setState(() {
                _state = _SyncState.syncing;
                _statusMessage = l10n.syncInProgress;
                _lastSyncedPeer = SyncPeer(
                  deviceName: incomingDeviceName,
                  host: '',
                  port: 0,
                );
              });
            },
            child: Text(l10n.syncAccept),
          ),
        ],
      ),
    );
  }

  Future<void> _syncWithPeer(SyncPeer peer) async {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    // First dialog: choose sync mode
    bool hardSync = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          title: Text(l10n.syncTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DevicePairRow(
                thisDevice: _thisDeviceName.isNotEmpty
                    ? _thisDeviceName
                    : l10n.syncThisDevice,
                otherDevice: peer.deviceName,
              ),
              const SizedBox(height: 12),
              Text(l10n.syncConfirmMessage(peer.deviceName)),
              const SizedBox(height: 12),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.syncHardSyncLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: hardSync ? cs.error : null,
                    fontWeight:
                        hardSync ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                value: hardSync,
                activeColor: cs.error,
                onChanged: (v) => setStateDlg(() => hardSync = v ?? false),
              ),
              if (hardSync) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l10n.syncHardSyncWarning,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.syncAccept),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    // Second dialog when hard sync is enabled
    if (hardSync) {
      final overrideConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.syncOverrideTitle(peer.deviceName)),
          content: Text(l10n.syncOverrideConfirm(peer.deviceName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.syncOverride),
            ),
          ],
        ),
      );
      if (overrideConfirmed != true || !mounted) return;
    }

    setState(() {
      _state = _SyncState.requesting;
      _statusMessage = l10n.syncRequestSent;
      _lastSyncedPeer = peer;
    });

    try {
      final result = await _syncService.syncWith(peer, hardSync: hardSync);
      if (mounted) {
        setState(() {
          _state = _SyncState.done;
          _result = result;
        });
      }
    } on SyncException catch (e) {
      if (mounted) {
        setState(() {
          _state = _SyncState.error;
          _error = e.message;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _state = _SyncState.error;
          _error = 'Connection timed out. Make sure both devices are on the same network and try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _SyncState.error;
          _error = e.toString();
        });
      }
    }
  }

  void _reset() => setState(() {
        _state = _SyncState.idle;
        _result = null;
        _error = null;
        _statusMessage = '';
        _lastSyncedPeer = null;
        _peers = _syncService.discovery.currentPeers;
      });

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncTitle),
        actions: [
          if (_state == _SyncState.idle && _permissionGranted)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.syncRefresh,
              onPressed: () {
                setState(() => _peers = []);
                _syncService.stopDiscovery().then((_) => _initAndStartDiscovery());
              },
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: !_permissionGranted
              ? _buildPermissionView(l10n, colorScheme)
              : _setupError
                  ? _buildSetupErrorView(l10n, colorScheme)
                  : switch (_state) {
                      _SyncState.idle => _buildDiscoveryView(l10n, colorScheme),
                      _SyncState.requesting => _buildProgressView(l10n, colorScheme),
                      _SyncState.syncing => _buildProgressView(l10n, colorScheme),
                      _SyncState.done => _buildResultView(l10n, colorScheme),
                      _SyncState.error => _buildErrorView(l10n),
                    },
        ),
      ),
    );
  }

  // ── Permission view ───────────────────────────────────────────

  Widget _buildPermissionView(AppLocalizations l10n, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_lock_rounded, size: 72, color: cs.error),
            const SizedBox(height: 16),
            Text(
              l10n.syncPermissionTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _permissionPermanentlyDenied
                  ? l10n.syncPermissionPermanentlyDenied
                  : l10n.syncPermissionRationale,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (_permissionPermanentlyDenied)
              FilledButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.syncOpenSettings),
              )
            else
              FilledButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.security_rounded),
                label: Text(l10n.syncPermissionGrantButton),
              ),
          ],
        ),
      ),
    );
  }

  // ── Setup error view ──────────────────────────────────────────

  Widget _buildSetupErrorView(AppLocalizations l10n, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: cs.error),
            const SizedBox(height: 16),
            Text(
              l10n.syncSetupFailed,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              Platform.isWindows ? l10n.syncFirewallHint : _setupErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initAndStartDiscovery,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ── Discovery view ────────────────────────────────────────────

  Widget _buildDiscoveryView(AppLocalizations l10n, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: cs.secondaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.syncInfo,
                        style: TextStyle(color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                if (_thisDeviceName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 36), // align with text above
                      Icon(Icons.smartphone, size: 14,
                          color: cs.onSecondaryContainer.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.syncDiscoverableAs(_thisDeviceName),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSecondaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.syncNearbyDevices,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_peers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l10n.syncDiscovering,
                    style: const TextStyle(color: Colors.grey)),
                if (Platform.isWindows) ...[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    iconColor: cs.onSurfaceVariant,
                    collapsedIconColor: cs.onSurfaceVariant,
                    title: Text(
                      l10n.syncTroubleshootingTitle,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    children: [
                      const SizedBox(height: 8),
                      Card(
                        color: cs.errorContainer,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.security_rounded,
                                  size: 18, color: cs.onErrorContainer),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.syncFirewallHint,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else
          ..._peers.map((peer) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.devices_rounded),
                  title: Text(peer.deviceName),
                  subtitle: Text(peer.host),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _syncWithPeer(peer),
                ),
              )),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.wifi),
          title: Text(l10n.syncWaitingForIncoming),
          subtitle: Text(l10n.syncWaitingSubtitle),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ── Progress view ─────────────────────────────────────────────

  Widget _buildProgressView(AppLocalizations l10n, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastSyncedPeer != null) ...[
              _DevicePairRow(
                thisDevice: _thisDeviceName.isNotEmpty
                    ? _thisDeviceName
                    : l10n.syncThisDevice,
                otherDevice: _lastSyncedPeer!.deviceName,
              ),
              const SizedBox(height: 24),
            ],
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _statusMessage.isEmpty ? l10n.syncInProgress : _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result view ───────────────────────────────────────────────

  Widget _buildResultView(AppLocalizations l10n, ColorScheme cs) {
    final r = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(l10n.syncComplete,
                style: Theme.of(context).textTheme.headlineSmall),
            if (_lastSyncedPeer != null) ...[
              const SizedBox(height: 16),
              _DevicePairRow(
                thisDevice: _thisDeviceName.isNotEmpty
                    ? _thisDeviceName
                    : l10n.syncThisDevice,
                otherDevice: _lastSyncedPeer!.deviceName,
              ),
            ],
            const SizedBox(height: 16),
            if (r.isHardSync)
              Text(
                l10n.syncHardSyncComplete(
                    _lastSyncedPeer?.deviceName ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            else if (!r.isEmpty)
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (r.foldersAdded > 0)
                        _ResultRow(Icons.folder_outlined,
                            l10n.syncResultFolders(r.foldersAdded)),
                      if (r.quizzesAdded > 0)
                        _ResultRow(Icons.quiz_outlined,
                            l10n.syncResultQuizzes(r.quizzesAdded)),
                      if (r.questionsAdded > 0)
                        _ResultRow(Icons.help_outline,
                            l10n.syncResultQuestions(r.questionsAdded)),
                      if (r.foldersUpdated > 0)
                        _ResultRow(Icons.drive_file_rename_outline,
                            l10n.syncResultFoldersUpdated(r.foldersUpdated)),
                      if (r.quizzesUpdated > 0)
                        _ResultRow(Icons.edit_outlined,
                            l10n.syncResultQuizzesUpdated(r.quizzesUpdated)),
                      if (r.questionsUpdated > 0)
                        _ResultRow(Icons.edit_note,
                            l10n.syncResultQuestionsUpdated(r.questionsUpdated)),
                      if (r.srsUpdated > 0)
                        _ResultRow(Icons.auto_awesome_outlined,
                            l10n.syncResultSrs(r.srsUpdated)),
                      if (r.foldersDeleted > 0)
                        _ResultRow(Icons.folder_delete_outlined,
                            l10n.syncResultFoldersDeleted(r.foldersDeleted)),
                      if (r.quizzesDeleted > 0)
                        _ResultRow(Icons.delete_outline,
                            l10n.syncResultQuizzesDeleted(r.quizzesDeleted)),
                      if (r.questionsDeleted > 0)
                        _ResultRow(Icons.help_outline,
                            l10n.syncResultQuestionsDeleted(r.questionsDeleted)),
                    ],
                  ),
                ),
              )
            else
              Text(l10n.syncAlreadyUpToDate,
                  style: const TextStyle(color: Colors.grey)),
            if (r.imagesFailedCount > 0) ...[
              const SizedBox(height: 12),
              _ResultRow(
                Icons.image_not_supported_outlined,
                l10n.syncResultImagesFailed(r.imagesFailedCount),
                color: cs.error,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.sync),
              label: Text(l10n.syncSyncAgain),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error view ────────────────────────────────────────────────

  Widget _buildErrorView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.syncFailed,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_error ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────

/// Shows two device chips connected by a sync-arrow, indicating which devices
/// are involved in the current operation.
class _DevicePairRow extends StatelessWidget {
  final String thisDevice;
  final String otherDevice;

  const _DevicePairRow({required this.thisDevice, required this.otherDevice});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DeviceChip(
          name: thisDevice,
          icon: Icons.phone_android_rounded,
          background: cs.primaryContainer,
          foreground: cs.onPrimaryContainer,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.sync_alt_rounded,
              size: 22, color: cs.onSurfaceVariant),
        ),
        _DeviceChip(
          name: otherDevice,
          icon: Icons.devices_rounded,
          background: cs.secondaryContainer,
          foreground: cs.onSecondaryContainer,
        ),
      ],
    );
  }
}

class _DeviceChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _DeviceChip({
    required this.name,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ResultRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }
}
