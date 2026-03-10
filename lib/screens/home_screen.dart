import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/models/placement.dart';
import 'package:stage_app/screens/placement_detail_screen.dart';
import 'package:stage_app/services/db.dart';
import 'package:stage_app/services/excel_importer.dart';
import 'package:stage_app/services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  final bool localOnly;
  const HomeScreen({super.key, required this.localOnly});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _activeSheet;
  List<String> _sheets = const [];
  List<Placement> _items = const [];
  String _search = '';
  bool _loading = true;

  String? get _ownerId => widget.localOnly ? null : Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _refresh();

    // Best effort initial sync
    if (!widget.localOnly) {
      Future.microtask(() async {
        await _sync(showSnack: false);
        await _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final sheets = await AppDb.instance.listSheets();
    final active = _activeSheet ?? (sheets.isEmpty ? null : sheets.first);
    final items = (active == null)
        ? <Placement>[]
        : await AppDb.instance.queryPlacements(sheet: active, search: _search, ownerId: _ownerId);

    setState(() {
      _sheets = sheets;
      _activeSheet = active;
      _items = items;
      _loading = false;
    });
  }

  Future<void> _sync({bool showSnack = true}) async {
    if (widget.localOnly) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync staat uit: Supabase is niet geconfigureerd.')),
        );
      }
      return;
    }

    final res = await SyncService.instance.syncNow();
    if (!mounted) return;

    if (showSnack) {
      final msg = res.skippedOffline
          ? 'Offline: sync overgeslagen.'
          : 'Sync klaar. Pushed: ${res.pushed}, Pulled: ${res.pulled}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickAndImportExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;

    final user = widget.localOnly ? null : Supabase.instance.client.auth.currentUser;
    final imported = ExcelImporter.importXlsx(
      Uint8List.fromList(bytes),
      ownerId: user?.id,
      ownerEmail: user?.email,
    );
    await AppDb.instance.upsertMany(imported);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Geïmporteerd: ${imported.length} regels (lokaal)')),
    );

    await _refresh();

    // Best effort: sync right after import
    if (!widget.localOnly) {
      await _sync(showSnack: true);
      await _refresh();
    }
  }

  Future<void> _openDetail(Placement p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlacementDetailScreen(id: p.id, localOnly: widget.localOnly)),
    );
    await _refresh();
  }

  Future<void> _logout() async {
    if (widget.localOnly) return;
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final activeSheet = _activeSheet;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.localOnly ? 'Stage App (lokaal)' : 'Stage App'),
        actions: [
          if (!widget.localOnly)
            IconButton(
              tooltip: 'Sync',
              onPressed: () async {
                await _sync(showSnack: true);
                await _refresh();
              },
              icon: const Icon(Icons.sync),
            ),
          IconButton(
            tooltip: 'Importeer Excel',
            onPressed: _pickAndImportExcel,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Ververs',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (!widget.localOnly)
            IconButton(
              tooltip: 'Uitloggen',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Zoeken (naam, klas, bedrijf, docent)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) async {
                      _search = v;
                      await _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: activeSheet,
                  hint: const Text('Sheet'),
                  items: _sheets
                      .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    setState(() => _activeSheet = v);
                    await _refresh();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_items.isEmpty
                    ? const Center(child: Text('Geen resultaten. Importeer een Excel-bestand.'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          final p = _items[i];
                          final subtitle = [
                            if ((p.klas ?? '').trim().isNotEmpty) p.klas,
                            if ((p.bpvBedrijf ?? '').trim().isNotEmpty) p.bpvBedrijf,
                            if ((p.docent ?? '').trim().isNotEmpty) 'Docent: ${p.docent}',
                          ].whereType<String>().join(' • ');

                          return ListTile(
                            title: Text(p.fullName),
                            subtitle: Text(subtitle.isEmpty ? p.sheet : subtitle),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (p.dirty) const Icon(Icons.cloud_upload, size: 18),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => _openDetail(p),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
