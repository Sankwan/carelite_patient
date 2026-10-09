/// The filter controls on Find a Clinician.
///
/// Every one of these maps to a query parameter the backend really has
/// (`?specialty=`, `?online=`) on `GET /api/accounts/clinicians/`. That is
/// the whole design constraint: filtering happens server-side, because the
/// list is paginated at 20 and filtering a fetched page would give answers
/// that are wrong the moment there are more clinicians than fit on it.
///
/// Deliberately absent, and not stubbed:
///
/// * **Nearest** — `ClinicianProfile` carries no lat/lng at all
///   (consultations are virtual), so there is no distance to sort by.
/// * **Lowest fee** — no fee ordering server-side. Sorting the fetched page
///   would give "cheapest of the 20 highest-rated", which is not the
///   cheapest clinician.
/// * **Top rated** — not a choice: `-rating, username` is the only ordering
///   the endpoint has, so it is always in effect. A toggle for it would be a
///   button that changes nothing.
library;

import 'package:equatable/equatable.dart';

class ClinicianFilter extends Equatable {
  const ClinicianFilter({this.specialty = '', this.onlineOnly = false});

  /// Sent as `?specialty=`, which the backend matches with `icontains`
  /// against the specialty field only.
  ///
  /// This is why the search box is labelled "Search by specialty" rather
  /// than the design's "Search doctors, specialties…": there is no name
  /// search on this backend, and typing a doctor's name into a specialty
  /// filter returns nothing. Better a narrower promise that works than a
  /// wider one that silently fails.
  final String specialty;

  /// Sent as `?online=true`. Omitted entirely when false — `?online=false`
  /// is a real filter that returns only *offline* clinicians, so sending it
  /// unconditionally would hide everyone who is available.
  final bool onlineOnly;

  bool get isActive => specialty.trim().isNotEmpty || onlineOnly;

  /// The subtitle under the result count.
  String summaryLabel(int count) {
    final noun = count == 1 ? 'clinician' : 'clinicians';
    return onlineOnly
        ? '$count $noun online now · highest rated first'
        : '$count $noun · highest rated first';
  }

  Map<String, dynamic> toQuery() {
    return {
      if (specialty.trim().isNotEmpty) 'specialty': specialty.trim(),
      if (onlineOnly) 'online': 'true',
    };
  }

  ClinicianFilter copyWith({String? specialty, bool? onlineOnly}) {
    return ClinicianFilter(
      specialty: specialty ?? this.specialty,
      onlineOnly: onlineOnly ?? this.onlineOnly,
    );
  }

  @override
  List<Object?> get props => [specialty, onlineOnly];
}

/// The two entry points from Home into the same clinician search.
///
/// General Care browses everyone, filtered only by availability; specialty
/// narrowing lives exclusively under Find Specialists.
enum ClinicianSearchMode {
  general('Find a Clinician'),
  specialists('Find Specialists');

  const ClinicianSearchMode(this.title);

  final String title;
}

/// The specialties offered as one-tap chips on Find Specialists.
///
/// Hardcoded on purpose: there is no `GET /api/specialties/` endpoint, and
/// deriving the list from the clinicians currently on page 1 would make the
/// chips change as the filter changes. These are passed through the same
/// `?specialty=` icontains filter as free text, so a chip for a specialty
/// nobody practices yet simply returns an empty state — it can never 400.
const List<String> kSpecialistChips = [
  'Clinical Psychology',
  'Physiotherapy',
  'Psychiatry',
  'Cardiology',
  'Dermatology',
  'Pediatrics',
  'Gynaecology',
  'Nutrition',
];
