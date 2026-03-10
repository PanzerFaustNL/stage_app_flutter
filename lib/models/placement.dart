class Placement {
  final String id; // UUID (used both locally + remotely)
  final String sheet;

  final String? klas;
  final String? roepnaam;
  final String? voorvoegsel;
  final String? achternaam;
  final String? crebo;
  final String? opleiding;
  final String? cohort;
  final String? emailSchool;
  final String? docent;

  final String? bpvBedrijf;
  final String? bpvBezoekadres;
  final String? bpvStatus;
  final DateTime? bpvBegindatum;
  final DateTime? bpvVerwachteEinddatum;

  final String? bpvEmail;
  final String? opmerkingen;

  // Bezoeken (extra t.o.v. Excel)
  final DateTime? firstVisitDate;
  final String? firstVisitNotes;
  final DateTime? secondVisitDate;
  final String? secondVisitNotes;

  // Multi-docent + sync
  final String? ownerId; // Supabase auth user id
  final String? ownerEmail;
  final bool dirty; // local changes not pushed yet
  final bool deleted; // soft delete (future-proof)

  final DateTime createdAt;
  final DateTime updatedAt;

  const Placement({
    required this.id,
    required this.sheet,
    this.klas,
    this.roepnaam,
    this.voorvoegsel,
    this.achternaam,
    this.crebo,
    this.opleiding,
    this.cohort,
    this.emailSchool,
    this.docent,
    this.bpvBedrijf,
    this.bpvBezoekadres,
    this.bpvStatus,
    this.bpvBegindatum,
    this.bpvVerwachteEinddatum,
    this.bpvEmail,
    this.opmerkingen,
    this.firstVisitDate,
    this.firstVisitNotes,
    this.secondVisitDate,
    this.secondVisitNotes,
    this.ownerId,
    this.ownerEmail,
    this.dirty = false,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName {
    final parts = [
      roepnaam?.trim(),
      (voorvoegsel ?? '').trim().isEmpty ? null : voorvoegsel!.trim(),
      achternaam?.trim(),
    ].whereType<String>().where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? '(onbekend)' : parts.join(' ');
  }

  Placement copyWith({
    String? id,
    String? sheet,
    String? klas,
    String? roepnaam,
    String? voorvoegsel,
    String? achternaam,
    String? crebo,
    String? opleiding,
    String? cohort,
    String? emailSchool,
    String? docent,
    String? bpvBedrijf,
    String? bpvBezoekadres,
    String? bpvStatus,
    DateTime? bpvBegindatum,
    DateTime? bpvVerwachteEinddatum,
    String? bpvEmail,
    String? opmerkingen,
    DateTime? firstVisitDate,
    String? firstVisitNotes,
    DateTime? secondVisitDate,
    String? secondVisitNotes,
    String? ownerId,
    String? ownerEmail,
    bool? dirty,
    bool? deleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Placement(
      id: id ?? this.id,
      sheet: sheet ?? this.sheet,
      klas: klas ?? this.klas,
      roepnaam: roepnaam ?? this.roepnaam,
      voorvoegsel: voorvoegsel ?? this.voorvoegsel,
      achternaam: achternaam ?? this.achternaam,
      crebo: crebo ?? this.crebo,
      opleiding: opleiding ?? this.opleiding,
      cohort: cohort ?? this.cohort,
      emailSchool: emailSchool ?? this.emailSchool,
      docent: docent ?? this.docent,
      bpvBedrijf: bpvBedrijf ?? this.bpvBedrijf,
      bpvBezoekadres: bpvBezoekadres ?? this.bpvBezoekadres,
      bpvStatus: bpvStatus ?? this.bpvStatus,
      bpvBegindatum: bpvBegindatum ?? this.bpvBegindatum,
      bpvVerwachteEinddatum: bpvVerwachteEinddatum ?? this.bpvVerwachteEinddatum,
      bpvEmail: bpvEmail ?? this.bpvEmail,
      opmerkingen: opmerkingen ?? this.opmerkingen,
      firstVisitDate: firstVisitDate ?? this.firstVisitDate,
      firstVisitNotes: firstVisitNotes ?? this.firstVisitNotes,
      secondVisitDate: secondVisitDate ?? this.secondVisitDate,
      secondVisitNotes: secondVisitNotes ?? this.secondVisitNotes,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'sheet': sheet,
        'klas': klas,
        'roepnaam': roepnaam,
        'voorvoegsel': voorvoegsel,
        'achternaam': achternaam,
        'crebo': crebo,
        'opleiding': opleiding,
        'cohort': cohort,
        'emailSchool': emailSchool,
        'docent': docent,
        'bpvBedrijf': bpvBedrijf,
        'bpvBezoekadres': bpvBezoekadres,
        'bpvStatus': bpvStatus,
        'bpvBegindatum': bpvBegindatum?.toIso8601String(),
        'bpvVerwachteEinddatum': bpvVerwachteEinddatum?.toIso8601String(),
        'bpvEmail': bpvEmail,
        'opmerkingen': opmerkingen,
        'firstVisitDate': firstVisitDate?.toIso8601String(),
        'firstVisitNotes': firstVisitNotes,
        'secondVisitDate': secondVisitDate?.toIso8601String(),
        'secondVisitNotes': secondVisitNotes,
        'ownerId': ownerId,
        'ownerEmail': ownerEmail,
        'dirty': dirty ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static Placement fromDb(Map<String, Object?> m) => Placement(
        id: m['id'] as String,
        sheet: m['sheet'] as String,
        klas: m['klas'] as String?,
        roepnaam: m['roepnaam'] as String?,
        voorvoegsel: m['voorvoegsel'] as String?,
        achternaam: m['achternaam'] as String?,
        crebo: m['crebo'] as String?,
        opleiding: m['opleiding'] as String?,
        cohort: m['cohort'] as String?,
        emailSchool: m['emailSchool'] as String?,
        docent: m['docent'] as String?,
        bpvBedrijf: m['bpvBedrijf'] as String?,
        bpvBezoekadres: m['bpvBezoekadres'] as String?,
        bpvStatus: m['bpvStatus'] as String?,
        bpvBegindatum: _dt(m['bpvBegindatum'] as String?),
        bpvVerwachteEinddatum: _dt(m['bpvVerwachteEinddatum'] as String?),
        bpvEmail: m['bpvEmail'] as String?,
        opmerkingen: m['opmerkingen'] as String?,
        firstVisitDate: _dt(m['firstVisitDate'] as String?),
        firstVisitNotes: m['firstVisitNotes'] as String?,
        secondVisitDate: _dt(m['secondVisitDate'] as String?),
        secondVisitNotes: m['secondVisitNotes'] as String?,
        ownerId: m['ownerId'] as String?,
        ownerEmail: m['ownerEmail'] as String?,
        dirty: (m['dirty'] as int? ?? 0) == 1,
        deleted: (m['deleted'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  Map<String, Object?> toRemote() => {
        'id': id,
        'sheet': sheet,
        'klas': klas,
        'roepnaam': roepnaam,
        'voorvoegsel': voorvoegsel,
        'achternaam': achternaam,
        'crebo': crebo,
        'opleiding': opleiding,
        'cohort': cohort,
        'email_school': emailSchool,
        'docent': docent,
        'bpv_bedrijf': bpvBedrijf,
        'bpv_bezoekadres': bpvBezoekadres,
        'bpv_status': bpvStatus,
        'bpv_begindatum': bpvBegindatum?.toIso8601String(),
        'bpv_verwachte_einddatum': bpvVerwachteEinddatum?.toIso8601String(),
        'bpv_email': bpvEmail,
        'opmerkingen': opmerkingen,
        'first_visit_date': firstVisitDate?.toIso8601String(),
        'first_visit_notes': firstVisitNotes,
        'second_visit_date': secondVisitDate?.toIso8601String(),
        'second_visit_notes': secondVisitNotes,
        'owner_id': ownerId,
        'owner_email': ownerEmail,
        'deleted': deleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Placement fromRemote(Map<String, Object?> m) => Placement(
        id: m['id'] as String,
        sheet: m['sheet'] as String,
        klas: m['klas'] as String?,
        roepnaam: m['roepnaam'] as String?,
        voorvoegsel: m['voorvoegsel'] as String?,
        achternaam: m['achternaam'] as String?,
        crebo: m['crebo'] as String?,
        opleiding: m['opleiding'] as String?,
        cohort: m['cohort'] as String?,
        emailSchool: m['email_school'] as String?,
        docent: m['docent'] as String?,
        bpvBedrijf: m['bpv_bedrijf'] as String?,
        bpvBezoekadres: m['bpv_bezoekadres'] as String?,
        bpvStatus: m['bpv_status'] as String?,
        bpvBegindatum: _dt(m['bpv_begindatum'] as String?),
        bpvVerwachteEinddatum: _dt(m['bpv_verwachte_einddatum'] as String?),
        bpvEmail: m['bpv_email'] as String?,
        opmerkingen: m['opmerkingen'] as String?,
        firstVisitDate: _dt(m['first_visit_date'] as String?),
        firstVisitNotes: m['first_visit_notes'] as String?,
        secondVisitDate: _dt(m['second_visit_date'] as String?),
        secondVisitNotes: m['second_visit_notes'] as String?,
        ownerId: m['owner_id'] as String?,
        ownerEmail: m['owner_email'] as String?,
        dirty: false,
        deleted: (m['deleted'] as bool? ?? false),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  static DateTime? _dt(String? s) => (s == null || s.isEmpty) ? null : DateTime.parse(s);
}
