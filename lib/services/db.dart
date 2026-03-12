import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stage_app/models/placement.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'stage_app.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, _) async {
        await _createV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 -> v2 migration (add sync + meta)
          await db.execute('ALTER TABLE placements ADD COLUMN ownerId TEXT;');
          await db.execute('ALTER TABLE placements ADD COLUMN ownerEmail TEXT;');
          await db.execute('ALTER TABLE placements ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0;');
          await db.execute('ALTER TABLE placements ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS meta (
              key TEXT PRIMARY KEY,
              value TEXT
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_placements_owner ON placements(ownerId);');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_placements_dirty ON placements(dirty);');
        }

        if (oldVersion < 3) {
          // v2 -> v3 migration (add bpv_telefoon)
          await db.execute('ALTER TABLE placements ADD COLUMN bpv_telefoon TEXT;');
        }
      },
    );
  }

  Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE placements (
        id TEXT PRIMARY KEY,
        sheet TEXT NOT NULL,

        klas TEXT,
        roepnaam TEXT,
        voorvoegsel TEXT,
        achternaam TEXT,
        crebo TEXT,
        opleiding TEXT,
        cohort TEXT,
        emailSchool TEXT,
        docent TEXT,

        bpvBedrijf TEXT,
        bpvBezoekadres TEXT,
        bpvStatus TEXT,
        bpvBegindatum TEXT,
        bpvVerwachteEinddatum TEXT,

        bpvEmail TEXT,
        bpv_telefoon TEXT,
        opmerkingen TEXT,

        firstVisitDate TEXT,
        firstVisitNotes TEXT,
        secondVisitDate TEXT,
        secondVisitNotes TEXT,

        ownerId TEXT,
        ownerEmail TEXT,
        dirty INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,

        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    await db.execute('CREATE INDEX idx_placements_sheet ON placements(sheet);');
    await db.execute('CREATE INDEX idx_placements_name ON placements(achternaam, roepnaam);');
    await db.execute('CREATE INDEX idx_placements_docent ON placements(docent);');
    await db.execute('CREATE INDEX idx_placements_owner ON placements(ownerId);');
    await db.execute('CREATE INDEX idx_placements_dirty ON placements(dirty);');
  }

  Database get db {
    final d = _db;
    if (d == null) throw StateError('DB not initialized');
    return d;
  }

  Future<void> upsertPlacement(Placement p0) async {
    await db.insert(
      'placements',
      p0.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMany(List<Placement> items) async {
    final batch = db.batch();
    for (final it in items) {
      batch.insert('placements', it.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markClean(List<String> ids) async {
    if (ids.isEmpty) return;
    final args = ids.map((_) => '?').join(',');
    await db.rawUpdate('UPDATE placements SET dirty = 0 WHERE id IN ($args)', ids);
  }

  Future<List<Placement>> listDirtyPlacements() async {
    final rows = await db.query('placements', where: 'dirty = 1 AND deleted = 0');
    return rows.map(Placement.fromDb).toList();
  }

  Future<List<String>> listSheets() async {
    final rows = await db.rawQuery('SELECT DISTINCT sheet FROM placements ORDER BY sheet ASC');
    return rows.map((r) => r['sheet'] as String).toList();
  }

  Future<List<Placement>> queryPlacements({
    required String sheet,
    String? search,
    String? ownerId,
  }) async {
    final s = (search ?? '').trim();
    final where = <String>['sheet = ?', 'deleted = 0'];
    final args = <Object?>[sheet];

    if (ownerId != null) {
      where.add('(ownerId = ? OR ownerId IS NULL)');
      args.add(ownerId);
    }

    if (s.isNotEmpty) {
      where.add('('
          'lower(roepnaam) LIKE ? OR lower(achternaam) LIKE ? OR lower(bpvBedrijf) LIKE ? OR lower(klas) LIKE ? OR lower(docent) LIKE ? OR lower(bpv_telefoon) LIKE ?'
          ')');
      final like = '%${s.toLowerCase()}%';
      args.addAll([like, like, like, like, like, like]);
    }

    final rows = await db.query(
      'placements',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'achternaam ASC, roepnaam ASC',
    );

    return rows.map(Placement.fromDb).toList();
  }

  Future<Placement?> getPlacement(String id) async {
    final rows = await db.query('placements', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Placement.fromDb(rows.first);
  }

  Future<void> clearAll() async => db.delete('placements');

  Future<String?> getMeta(String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await db.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}