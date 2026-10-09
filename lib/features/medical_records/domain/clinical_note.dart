import 'package:equatable/equatable.dart';

/// One version of a clinician's structured note.
///
/// Every save creates a new version server-side (auto-save history), and the
/// list comes back newest-first — so the patient is shown the latest only.
/// The eleven content fields are all optional free text; the UI renders only
/// the ones that have content, because a note with nine empty headings reads
/// as a broken screen.
class ClinicalNote extends Equatable {
  const ClinicalNote({
    required this.id,
    required this.version,
    this.authorUsername,
    this.createdAt,
    this.sections = const {},
  });

  factory ClinicalNote.fromDjangoJson(Map<String, dynamic> row) {
    String read(String key) => (row[key] as String? ?? '').trim();

    return ClinicalNote(
      id: '${row['id']}',
      version: row['version'] as int? ?? 0,
      authorUsername: row['author_username'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal(),
      // Ordered deliberately: this is the order a clinician reads a note in,
      // and a LinkedHashMap preserves it.
      sections: {
        for (final entry in const [
          ('Chief complaint', 'chief_complaint'),
          ('History of present illness', 'history_present_illness'),
          ('Past medical history', 'past_medical_history'),
          ('Family history', 'family_history'),
          ('Social history', 'social_history'),
          ('Allergies', 'allergies'),
          ('Medications', 'medications'),
          ('Examination', 'examination'),
          ('Assessment', 'assessment'),
          ('Plan', 'plan'),
          ('Notes', 'free_text'),
        ])
          if (read(entry.$2).isNotEmpty) entry.$1: read(entry.$2),
      },
    );
  }

  final String id;
  final int version;
  final String? authorUsername;
  final DateTime? createdAt;

  /// Heading → content, empty sections already dropped.
  final Map<String, String> sections;

  bool get isEmpty => sections.isEmpty;

  @override
  List<Object?> get props => [id, version, authorUsername, createdAt, sections];
}
