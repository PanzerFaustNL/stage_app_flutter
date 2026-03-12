import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:stage_app/models/placement.dart';

class ExcelImporter {
  static const _uuid = Uuid();

  /// Importeert placements uit een xlsx (bytes).
  ///
  /// - Leest elke sheet
  /// - Gebruikt de eerste rij als header
  /// - Mapt kolommen op basis van bekende header-namen (case-insensitive)
  /// - Zet imported rows als dirty zodat ze mee syncen naar de cloud
  static List<Placement> importXlsx(
    Uint8List bytes, {
    String? ownerId,
    String? ownerEmail,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final results = <Placement>[];

    for (final sheetName in excel.tables.keys) {
      final table = excel.tables[sheetName];
      if (table == null) continue;

      final rows = table.rows;
      if (rows.isEmpty) continue;

      final headerRow = rows.first;
      final header = <int, String>{};

      for (var c = 0; c < headerRow.length; c++) {
        final v = headerRow[c]?.value;
        final s = (v == null) ? '' : v.toString();
        header[c] = s.trim();
      }

      for (var r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (_rowIsEmpty(row)) continue;

        String? getByHeader(List<String> names) {
          for (final name in names) {
            final colIndex = _findCol(header, name);
            if (colIndex == null) continue;
            final cell = (colIndex < row.length) ? row[colIndex] : null;
            final v = cell?.value;
            if (v == null) continue;
            final s = v.toString().trim();
            if (s.isNotEmpty) return s;
          }
          return null;
        }

        DateTime? getDateByHeader(List<String> names) {
          for (final name in names) {
            final colIndex = _findCol(header, name);
            if (colIndex == null) continue;
            final cell = (colIndex < row.length) ? row[colIndex] : null;
            if (cell == null) continue;

            final parsed = _parseExcelDate(cell.value);
            if (parsed != null) return parsed;
          }
          return null;
        }

        final now = DateTime.now();

        final p = Placement(
          id: _uuid.v4(),
          sheet: sheetName,
          klas: getByHeader(['Klas', 'KLAS', 'Groep']),
          roepnaam: getByHeader(['Roepnaam', 'Voornaam', 'Naam', 'Student']),
          voorvoegsel: getByHeader(['Voorvoegsel', 'Tussenvoegsel']),
          achternaam: getByHeader(['Achternaam', 'Familienaam', 'Naam']),
          crebo: getByHeader([
            'Crebo',
            'CREBO',
            'Crebo- / elementcode',
          ]),
          opleiding: getByHeader(['Opleiding', 'Opleidingen']),
          cohort: getByHeader(['Cohort']),
          emailSchool: getByHeader([
            'Email school',
            'E-mail school',
            'School e-mail',
            'E-mailadres school',
            'E-mailadres',
            'Email School',
          ]),
          docent: getByHeader(['Docent', 'Begeleider', 'Stagebegeleider', 'Coach']),
          bpvBedrijf: getByHeader([
            'BPV Bedrijven',
            'BPV Bedrijf',
            'BPV-bedrijf',
            'Bedrijf',
            'Stagebedrijf',
          ]),
          bpvBezoekadres: getByHeader([
            'BPV Bezoekadres',
            'Bezoekadres',
            'Adres bedrijf',
            'Adres',
          ]),
          bpvStatus: getByHeader(['BPV Statussen', 'BPV Status', 'Status']),
          bpvBegindatum: getDateByHeader([
            'BPV Begindata',
            'BPV Begindatum',
            'Startdatum',
            'Start',
          ]),
          bpvVerwachteEinddatum: getDateByHeader([
            'BPV Verwachte einddata',
            'BPV Einddatum',
            'Einddatum',
            'Einde',
          ]),
          bpvEmail: getByHeader([
            'Praktijkbegeleiders BPV-bedrijf e-mailadres',
            'BPV e-mail',
            'E-mail bedrijf',
            'Email bedrijf',
            'BPV-mailadres',
          ]),
          bpv_telefoon: getByHeader([
            'BPV Telefoon',
            'BPV telefoon',
            'Telefoon',
            'Telefoonnummer',
            'BPV-telefoon',
            'Praktijkbegeleider telefoon',
            'Praktijkbegeleiders BPV-bedrijf telefoonnummer',
          ]),
          opmerkingen: getByHeader(['Opmerkingen', 'Notities', 'Aantekeningen']),
          firstVisitDate: null,
          firstVisitNotes: null,
          secondVisitDate: null,
          secondVisitNotes: null,
          ownerId: ownerId,
          ownerEmail: ownerEmail,
          dirty: true,
          deleted: false,
          createdAt: now,
          updatedAt: now,
        );

        results.add(p);
      }
    }

    return results;
  }

  static DateTime? _parseExcelDate(dynamic value) {
    if (value == null) return null;

    final s = value.toString().trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    final n = num.tryParse(s.replaceAll(',', '.'));
    if (n != null) {
      final base = DateTime(1899, 12, 30);
      return base.add(Duration(days: n.floor()));
    }

    return null;
  }

  static bool _rowIsEmpty(List<Data?> row) {
    for (final cell in row) {
      final v = cell?.value;
      if (v == null) continue;
      if (v.toString().trim().isNotEmpty) return false;
    }
    return true;
  }

  static int? _findCol(Map<int, String> header, String name) {
    final target = name.trim().toLowerCase();
    for (final e in header.entries) {
      if (e.value.trim().toLowerCase() == target) return e.key;
    }
    return null;
  }
}