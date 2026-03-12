import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stage_app/models/placement.dart';
import 'package:stage_app/services/db.dart';
import 'package:stage_app/services/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PlacementDetailScreen extends StatefulWidget {
  final String id;
  final bool localOnly;

  const PlacementDetailScreen({
    super.key,
    required this.id,
    required this.localOnly,
  });

  @override
  State<PlacementDetailScreen> createState() => _PlacementDetailScreenState();
}

class _PlacementDetailScreenState extends State<PlacementDetailScreen> {
  Placement? _p;
  bool _loading = true;

  final _firstNotesCtrl = TextEditingController();
  final _secondNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNotesCtrl.dispose();
    _secondNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final p0 = await AppDb.instance.getPlacement(widget.id);

    if (!mounted) return;

    setState(() {
      _p = p0;
      _firstNotesCtrl.text = p0?.firstVisitNotes ?? '';
      _secondNotesCtrl.text = p0?.secondVisitNotes ?? '';
      _loading = false;
    });
  }

  Future<void> _callPhone(String? phone) async {
    final raw = (phone ?? '').trim();
    if (raw.isEmpty) return;

    final normalized = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: normalized);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendMail(String? email) async {
    final raw = (email ?? '').trim();
    if (raw.isEmpty) return;

    final uri = Uri(
      scheme: 'mailto',
      path: raw,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(String? address) async {
    final raw = (address ?? '').trim();
    if (raw.isEmpty) return;

    final encoded = Uri.encodeComponent(raw);

    Uri uri;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      uri = Uri.parse('http://maps.apple.com/?daddr=$encoded');
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$encoded',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
      firstVisitNotes: _firstNotesCtrl.text.trim().isEmpty
          ? null
          : _firstNotesCtrl.text.trim(),
      secondVisitNotes: _secondNotesCtrl.text.trim().isEmpty
          ? null
          : _secondNotesCtrl.text.trim(),
      ownerId: p0.ownerId ?? user?.id,
      ownerEmail: p0.ownerEmail ?? user?.email,
      dirty: true,
      updatedAt: DateTime.now(),
    );

    await AppDb.instance.upsertPlacement(updated);

    if (!mounted) return;

    setState(() => _p = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opgeslagen (lokaal)')),
    );

    if (!widget.localOnly && syncAfter) {
      final res = await SyncService.instance.syncNow();
      if (!mounted) return;

      final msg = res.skippedOffline
          ? 'Offline: sync overgeslagen.'
          : 'Sync klaar. Pushed: ${res.pushed}, Pulled: ${res.pulled}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

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
                    _heroBpvCard(p0),
                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Algemeen',
                      children: [
                        _kv('Sheet', p0.sheet),
                        _kv('Naam', p0.fullName),
                        _kv('Klas', p0.klas),
                        _kv('Docent', p0.docent),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'BPV',
                      children: [
                        _kv('Bedrijf', p0.bpvBedrijf),
                        _kv('Adres', p0.bpvBezoekadres),
                        _phoneRow(p0.bpv_telefoon),
                        _kv('Status', p0.bpvStatus),
                        _kv('Begindatum', _fmt(p0.bpvBegindatum)),
                        _kv('Verwachte einddatum', _fmt(p0.bpvVerwachteEinddatum)),
                        _kv('E-mail bedrijf', p0.bpvEmail),
                        _kv('Opmerkingen', p0.opmerkingen),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _sectionCard(
                      title: 'Bezoeken',
                      children: [
                        _visitCard(
                          title: 'Eerste bezoek',
                          date: p0.firstVisitDate,
                          onPick: () => _pickDate(
                            current: p0.firstVisitDate,
                            setValue: (d) async {
                              final updated = p0.copyWith(
                                firstVisitDate: d,
                                dirty: true,
                                updatedAt: DateTime.now(),
                              );
                              await AppDb.instance.upsertPlacement(updated);
                              if (!mounted) return;
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
                              final updated = p0.copyWith(
                                secondVisitDate: d,
                                dirty: true,
                                updatedAt: DateTime.now(),
                              );
                              await AppDb.instance.upsertPlacement(updated);
                              if (!mounted) return;
                              setState(() => _p = updated);
                            },
                          ),
                          notesCtrl: _secondNotesCtrl,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    FilledButton.icon(
                      onPressed: () => _save(syncAfter: !widget.localOnly),
                      icon: Icon(
                        widget.localOnly ? Icons.save : Icons.cloud_upload,
                      ),
                      label: Text(
                        widget.localOnly ? 'Opslaan' : 'Opslaan + sync',
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      widget.localOnly
                          ? 'Sync staat uit (Supabase niet geconfigureerd).'
                          : (p0.dirty
                              ? 'Deze regel heeft lokale wijzigingen die nog niet (zeker) in de cloud staan.'
                              : 'Alles gesynct.'),
                    ),
                  ],
                ),
    );
  }

  Widget _heroBpvCard(Placement p) {
    final company = (p.bpvBedrijf ?? '').trim();
    final address = (p.bpvBezoekadres ?? '').trim();
    final phone = (p.bpv_telefoon ?? '').trim();
    final email = (p.bpvEmail ?? '').trim();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company.isEmpty ? 'BPV-bedrijf' : company,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                address,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (phone.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _callPhone(phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Bel'),
                  ),
                if (email.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _sendMail(email),
                    icon: const Icon(Icons.email),
                    label: const Text('Mail'),
                  ),
                if (address.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _openMaps(address),
                    icon: const Icon(Icons.map),
                    label: const Text('Navigeer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final visibleChildren = children.where((w) => w is! SizedBox).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...visibleChildren,
          ],
        ),
      ),
    );
  }

  Widget _phoneRow(String? phone) {
    final value = (phone ?? '').trim();
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              'Telefoon',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
          IconButton(
            tooltip: 'Bel praktijkbegeleider',
            onPressed: () => _callPhone(value),
            icon: const Icon(Icons.phone),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String? v) {
    if (v == null || v.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) {
    return d == null ? '' : DateFormat('dd-MM-yyyy').format(d);
  }

  Widget _visitCard({
    required String title,
    required DateTime? date,
    required VoidCallback onPick,
    required TextEditingController notesCtrl,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
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