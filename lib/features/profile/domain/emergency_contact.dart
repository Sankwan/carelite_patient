import 'package:equatable/equatable.dart';

/// Who to call for this patient in an emergency.
///
/// Kept as its own model rather than two loose fields on [PatientProfile]
/// because a clinician needs read access to *exactly this* during an active
/// consultation and nothing else on the patient record — see the
/// column-scoped RLS policy in supabase/migrations (requirement #2).
class EmergencyContact extends Equatable {
  const EmergencyContact({this.name = '', this.phone = ''});

  final String name;
  final String phone;

  bool get isEmpty => name.trim().isEmpty && phone.trim().isEmpty;

  EmergencyContact copyWith({String? name, String? phone}) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  @override
  List<Object?> get props => [name, phone];
}
