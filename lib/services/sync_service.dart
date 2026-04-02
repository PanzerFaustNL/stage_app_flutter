import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/models/placement.dart';
import 'package:stage_app/services/db.dart';

class SyncResult {
  final int pushed;
  final int pulled;
  final bool skippedOffline;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.skippedOffline,
  });
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _metaLastSync = 'last_sync_iso';

  SupabaseClient get _sb => Supabase.instance.client;

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r != ConnectivityResult.none;
  }

  Future<SyncResult> syncNow() async {
    try {
      _sb.auth.currentUser;
    } catch (_) {
      return const SyncResult(
        pushed: 0,
        pulled: 0,
        skippedOffline: true,
      );
    }

    if (!await _online()) {
      return const SyncResult(
        pushed: 0,
        pulled: 0,
        skippedOffline: true,
      );
    }

    final user = _sb.auth.currentUser;
    if (user == null) {
      return const SyncResult(
        pushed: 0,
        pulled: 0,
        skippedOffline: false,
      );
    }

    int pushed = 0;

    // 1) Push local dirty rows
    final dirty = await AppDb.instance.listDirtyPlacements();

    if (dirty.isNotEmpty) {
      final payload = dirty
          .map(
            (p) => p.copyWith(
          ownerId: p.ownerId ?? user.id,
          ownerEmail: p.ownerEmail ?? user.email,
          updatedAt: DateTime.now().toUtc(),
        ).toRemote(),
      )
          .toList();

      await _sb.from('placements').upsert(payload, onConflict: 'id');
      pushed = dirty.length;
      await AppDb.instance.markClean(dirty.map((e) => e.id).toList());
    }

    // 2) Pull remote updates since last sync
    final lastIso = await AppDb.instance.getMeta(_metaLastSync);
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);

    final dynamic rows;
    if (last == null) {
      rows = await _sb
          .from('placements')
          .select()
          .order('updated_at', ascending: true);
    } else {
      rows = await _sb
          .from('placements')
          .select()
          .gte('updated_at', last.toUtc().toIso8601String())
          .order('updated_at', ascending: true);
    }

    final list = (rows as List).cast<Map<String, Object?>>();
    final placements = list.map(Placement.fromRemote).toList();

    if (placements.isNotEmpty) {
      await AppDb.instance.upsertMany(placements);
    }

    // 3) Save newest updated_at returned by server, not device time
    String newLastSyncIso =
        lastIso ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String();

    DateTime? latestUpdatedAt;
    for (final p in placements) {
      final dt = p.updatedAt.toUtc();
      if (latestUpdatedAt == null || dt.isAfter(latestUpdatedAt)) {
        latestUpdatedAt = dt;
      }
    }

    if (latestUpdatedAt != null) {
      newLastSyncIso = latestUpdatedAt.toIso8601String();
    }

    await AppDb.instance.setMeta(_metaLastSync, newLastSyncIso);

    return SyncResult(
      pushed: pushed,
      pulled: placements.length,
      skippedOffline: false,
    );
  }
}