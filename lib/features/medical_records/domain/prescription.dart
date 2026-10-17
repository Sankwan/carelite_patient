import 'package:equatable/equatable.dart';

import 'care_facility.dart';

/// One drug on a prescription.
class PrescriptionItem extends Equatable {
  const PrescriptionItem({
    required this.drugName,
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.notes = '',
  });

  factory PrescriptionItem.fromDjangoJson(Map<String, dynamic> row) {
    return PrescriptionItem(
      drugName: row['drug_name'] as String? ?? 'Medication',
      dosage: row['dosage'] as String? ?? '',
      frequency: row['frequency'] as String? ?? '',
      duration: row['duration'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
    );
  }

  final String drugName;
  final String dosage;
  final String frequency;
  final String duration;
  final String notes;

  /// "500mg · twice daily · 5 days", skipping whatever is blank so the line
  /// never reads "· ·".
  String get instructions => [dosage, frequency, duration]
      .where((p) => p.trim().isNotEmpty)
      .join(' · ');

  @override
  List<Object?> get props => [drugName, dosage, frequency, duration, notes];
}

/// A signed prescription, optionally routed to a pharmacy.
class Prescription extends Equatable {
  const Prescription({
    required this.id,
    this.prescriberName = '',
    this.items = const [],
    this.pharmacy,
    this.signedAt,
  });

  factory Prescription.fromDjangoJson(Map<String, dynamic> row) {
    return Prescription(
      id: '${row['id']}',
      // The one place in this backend where a real human name exists —
      // ClinicianProfile.prescriber_name, captured for the legal record.
      prescriberName: row['prescriber_name'] as String? ?? '',
      items: ((row['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PrescriptionItem.fromDjangoJson)
          .toList(growable: false),
      pharmacy: CareFacility.fromDjangoJson(
        row['assigned_pharmacy'] as Map<String, dynamic>?,
      ),
      signedAt: DateTime.tryParse(row['signed_at'] as String? ?? '')?.toLocal(),
    );
  }

  final String id;
  final String prescriberName;
  final List<PrescriptionItem> items;

  /// Null until a clinician assigns one — the patient collects from
  /// anywhere until then, so the UI must not imply a pharmacy is waiting.
  final CareFacility? pharmacy;

  final DateTime? signedAt;

  @override
  List<Object?> get props => [id, prescriberName, items, pharmacy, signedAt];
}
