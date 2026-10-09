import 'package:equatable/equatable.dart';

import '../../../core/utils/display_name.dart';
import 'money.dart';

/// Mirrors two different backend concepts under one client-side type:
/// `accounts.models.ClinicianProfile` (clinician) and
/// `facilities.models.Facility.Type` (lab / imaging / pharmacy) — confirmed
/// against github.com/campofo/carelite. They are genuinely different Django
/// models with different fields (see [Provider.fromClinicianJson] vs.
/// [Provider.fromFacilityMatchJson]); this enum exists so the UI can render
/// "a place or person the patient might see" uniformly, not because the
/// backend treats them as one thing.
enum ProviderKind { clinician, lab, imaging, pharmacy }

/// A clinician, lab, imaging center or pharmacy as the patient app sees it.
///
/// [specialty] and [rating] live here and nowhere else, so the same provider
/// reads identically everywhere it appears in this app.
class Provider extends Equatable {
  const Provider({
    required this.id,
    required this.kind,
    required this.displayName,
    this.specialty,
    this.rating,
    this.reviewCount = 0,
    this.consultationFee,
    this.isAvailable = false,
    this.distanceMetres,
    this.bio,
    this.yearsExperience,
  });

  /// Parses a clinician row — verified against both
  /// `accounts.serializers.PublicClinicianSerializer` (the
  /// `/api/accounts/clinicians/` list, which also carries `consultation_fee`)
  /// and `appointments.serializers.ClinicianBriefSerializer` (the smaller
  /// shape nested inside a booked appointment, which does not). Both are
  /// handled by one factory because every field beyond `id`/`username` is
  /// read as optional.
  ///
  /// `rating` and `consultation_fee` are Django `DecimalField`s, which DRF
  /// serializes as JSON **strings** ("4.80", "160.00") — verified live, not
  /// assumed. Parsing them as num would throw.
  ///
  /// There is no `displayName` field on this backend at all: no
  /// first_name/last_name, no "full name" anywhere. `username` is the only
  /// human-readable identifier — for this app's own patients it happens to
  /// be their email (see DjangoAuthRepository). The seeded clinician
  /// accounts are `dr_adjei`, `dr_owusu`… — shown verbatim that reads as a
  /// raw system identifier, not a name, so [formatUsername] reshapes it to
  /// "Dr. Adjei" without inventing any information the backend didn't send.
  factory Provider.fromClinicianJson(Map<String, dynamic> row) {
    return Provider(
      id: '${row['id']}',
      kind: ProviderKind.clinician,
      displayName: formatUsername(
        (row['user']?['username'] ?? row['username']) as String? ?? 'Clinician',
      ),
      specialty: row['specialty'] as String?,
      rating: _decimal(row['rating']),
      consultationFee: _pesewas(row['consultation_fee']),
      isAvailable: row['is_online'] as bool? ?? false,
      // Present on the browse list (PublicClinicianSerializer), absent from
      // the brief shape nested in an appointment — hence both optional.
      bio: row['bio'] as String?,
      yearsExperience: row['years_experience'] as int?,
      // Clinicians carry no location in this backend — consultations are
      // virtual, so there is nothing to compute a distance from. Always
      // null; ProviderCard already renders correctly without one.
    );
  }

  /// Parses one item of `POST /api/match/`'s response
  /// (`facilities.serializers.MatchResultSerializer`: {facility,
  /// distance_km, stock_qty}) — verified live against a running instance,
  /// including a real ranked-by-distance result.
  factory Provider.fromFacilityMatchJson(Map<String, dynamic> row) {
    final facility = (row['facility'] as Map).cast<String, dynamic>();
    final distanceKm = (row['distance_km'] as num?)?.toDouble();
    return Provider(
      id: '${facility['id']}',
      kind: _facilityKind(facility['type'] as String?),
      displayName: facility['name'] as String? ?? 'Facility',
      isAvailable: facility['is_onboarded'] as bool? ?? false,
      distanceMetres: distanceKm == null ? null : distanceKm * 1000,
    );
  }

  /// Parses one row of `GET /api/facilities/`
  /// (`facilities.serializers.FacilitySerializer`) — the un-ranked browse
  /// list, used when there is no patient location to rank by.
  factory Provider.fromFacilityJson(Map<String, dynamic> row) {
    return Provider(
      id: '${row['id']}',
      kind: _facilityKind(row['type'] as String?),
      displayName: row['name'] as String? ?? 'Facility',
      isAvailable: row['is_onboarded'] as bool? ?? false,
    );
  }

  final String id;
  final ProviderKind kind;
  final String displayName;
  final String? specialty;
  final double? rating;
  final int reviewCount;
  final Money? consultationFee;
  final bool isAvailable;

  /// Null when the patient declined location, or (always, today) for
  /// clinicians. The provider is still shown, just without a distance —
  /// never a reason to hide a result.
  final double? distanceMetres;

  /// Only the browse list carries these; null everywhere else. The profile
  /// screen omits the section rather than printing an empty heading.
  final String? bio;
  final int? yearsExperience;

  /// "6 years experience". Null when unknown, so the caller omits the chip.
  String? get experienceLabel {
    final years = yearsExperience;
    if (years == null || years <= 0) return null;
    return '$years year${years == 1 ? '' : 's'} experience';
  }

  /// "2.1 km" / "850 m". Null when distance is unknown, so callers omit the
  /// row rather than print a misleading "0 km".
  String? get distanceLabel {
    final metres = distanceMetres;
    if (metres == null) return null;
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  static double? _decimal(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value as String);
  }

  static Money? _pesewas(dynamic value) {
    final cedis = _decimal(value);
    if (cedis == null) return null;
    return Money((cedis * 100).round());
  }

  static ProviderKind _facilityKind(String? type) => switch (type) {
        'LAB' => ProviderKind.lab,
        'IMAGING' => ProviderKind.imaging,
        'PHARMACY' => ProviderKind.pharmacy,
        _ => ProviderKind.lab,
      };

  @override
  List<Object?> get props => [
        id, kind, displayName, specialty, rating, reviewCount,
        consultationFee, isAvailable, distanceMetres, bio, yearsExperience,
      ];
}
