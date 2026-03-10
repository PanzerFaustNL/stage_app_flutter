import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/models/placement.dart';
import 'package:stage_app/services/db.dart';
import 'package:stage_app/services/sync_service.dart';

class PlacementDetailScreen extends StatefulWidget {
  final String id;
  final bool localOnly;
  const PlacementDetailScreen({super.key, required this.id, required this.localOnly});

  @override
  State<PlacementDetailScreen> createState() => _PlacementDetailScreenState();
}

class _PlacementDetailScreenState extends State<PlacementDetailScreen> {
  Placement? _p;
  bool _loading = true;

  final _firstNotesCtrl = TextEditingController();
  final _secondNotesCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNotesCtrl.dispose();
    _secondNotesCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p0 = await AppDb.instance.getPlacement(widget.id);
    setState(() {
      _p = p0;
      _firstNotesCtrl.text = p0?.firstVisitNotes ?? '';
      _secondNotesCtrl.text = p0?.secondVisitNotes ?? '';
      _loading = false;
    });
  }

  Future<void> _pickDate({
    required DateTime? current,
    required void Function(DateTime?) setValue,
  }) async {
    final initial = current ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setValue(picked);
  }

  Future<void> _save({bool syncAfter = false}) async {
    final p0 = _p;
    if (p0 == null) return;

    final user = widget.localOnly ? null : Supabase.instance.client.auth.currentUser;

    final updated = p0.copyWith(
      firstVisitNotes: _firstNotesCtrl.text.trim().isEmpty ? null : _firstNotesCtrl.text.trim(),
      secondVisitNotes: _secondNotesCtrl.text.trim().isEmpty ? null : _secondNotesCtrl.text.trim(),
      ownerId: p0.ownerId ?? user?.id,
      ownerEmail: p0.ownerEmail ?? user?.email,
      dirty: true,
      updatedAt: DateTime.now(),
    );

    await AppDb.instance.upsertPlacement(updated);
    if (!mounted) return;

    setState(() => _p = updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opgeslagen (lokaal)')));

    if (!widget.localOnly && syncAfter) {
      final res = await SyncService.instance.syncNow();
      if (!mounted) return;
      final msg = res.skippedOffline
          ? 'Offline: sync overgeslagen.'
          : 'Sync klaar. Pushed: ${res.pushed}, Pulled: ${res.pulled}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p0 = _p;

    return Scaffold(
      appBar: AppBar(
        title: Text(p0?.fullName ?? 'Detail'),
        actions: [
          IconButton(
            tooltip: 'Opslaan',
            onPressed: () => _save(syncAfter: false),
            icon: const Icon(Icons.save),
          ),
          if (!widget.localOnly)
            IconButton(
              tooltip: 'Opslaan + sync',
              onPressed: () => _save(syncAfter: true),
              icon: const Icon(Icons.cloud_upload),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (p0 == null)
              ? const Center(child: Text('Niet gevonden'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _kv('Sheet', p0.sheet),
                    _kv('Naam', p0.fullName),
                    _kv('Klas', p0.klas),
                    _kv('Docent', p0.docent),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text('BPV', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _kv('Bedrijf', p0.bpvBedrijf),
                    _kv('Adres', p0.bpvBezoekadres),
                    _kv('Status', p0.bpvStatus),
                    _kv('Begindatum', _fmt(p0.bpvBegindatum)),
                    _kv('Verwachte einddatum', _fmt(p0.bpvVerwachteEinddatum)),
                    _kv('E-mail bedrijf', p0.bpvEmail),
                    _kv('Opmerkingen', p0.opmerkingen),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text('Bezoeken', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _visitCard(
                      title: 'Eerste bezoek',
                      date: p0.firstVisitDate,
                      onPick: () => _pickDate(
                        current: p0.firstVisitDate,
                        setValue: (d) async {
                          final updated = p0.copyWith(firstVisitDate: d, dirty: true, updatedAt: DateTime.now());
                          await AppDb.instance.upsertPlacement(updated);
                          setState(() => _p = updated);
                        },
                      ),
                      notesCtrl: _firstNotesCtrl,
                    ),
                    const SizedBox(height: 12),
                    _visitCard(
                      title: 'Tweede bezoek',
                      date: p0.secondVisitDate,
                      onPick: () => _pickDate(
                        current: p0.secondVisitDate,
                        setValue: (d) async {
                          final updated = p0.copyWith(secondVisitDate: d, dirty: true, updatedAt: DateTime.now());
                          await AppDb.instance.upsertPlacement(updated);
                          setState(() => _p = updated);
                        },
                      ),
                      notesCtrl: _secondNotesCtrl,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _save(syncAfter: !widget.localOnly),
                      icon: Icon(widget.localOnly ? Icons.save : Icons.cloud_upload),
                      label: Text(widget.localOnly ? 'Opslaan' : 'Opslaan + sync'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.localOnly
                          ? 'Sync staat uit (Supabase niet geconfigureerd).'
                          : (p0.dirty ? 'Deze regel heeft lokale wijzigingen die nog niet (zeker) in de cloud staan.' : 'Alles gesynct.'),
                    ),
                  ],
                ),
    );
  }

  Widget _kv(String k, String? v) {
    if (v == null || v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) => d == null ? '' : DateFormat('dd-MM-yyyy').format(d);

  Widget _visitCard({
    required String title,
    required DateTime? date,
    required VoidCallback onPick,
    required TextEditingController notesCtrl,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(_fmt(date)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Kies datum',
                  onPressed: onPick,
                  icon: const Icon(Icons.date_range),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notities',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
