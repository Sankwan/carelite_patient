import 'package:equatable/equatable.dart';

import 'emergency_contact.dart';

/// Gender options from the Figma Complete Profile chips (99:267).
enum Gender {
  female('Female'),
  male('Male'),
  preferNotToSay('Prefer not to say');

  const Gender(this.label);

  final String label;
}

/// The eight ABO/Rh types shown as chips in the design.
enum BloodType {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  abPositive('AB+'),
  abNegative('AB-'),
  oPositive('O+'),
  oNegative('O-');

  const BloodType(this.label);

  final String label;
}

/// The patient-supplied half of a `profiles` row. Deliberately hand-written
/// (no json_serializable) in line with the project's no-codegen rule — the
/// map keys below are the column names in
/// supabase/migrations/0001_profiles_and_roles.sql.
class PatientProfile extends Equatable {
  const PatientProfile({
    this.fullName = '',
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.emergencyContact = const EmergencyContact(),
  });

  final String fullName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final BloodType? bloodType;
  final EmergencyContact emergencyContact;

  /// Name and date of birth are the only hard requirements — a patient can
  /// finish setup without disclosing gender, blood type or a contact, and
  /// fill them in later from Profile.
  bool get isSubmittable =>
      fullName.trim().length >= 2 && dateOfBirth != null;

  PatientProfile copyWith({
    String? fullName,
    DateTime? dateOfBirth,
    Gender? gender,
    BloodType? bloodType,
    EmergencyContact? emergencyContact,
  }) {
    return PatientProfile(
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  Map<String, dynamic> toColumns() {
    return <String, dynamic>{
      'full_name': fullName.trim(),
      // Date only — no timezone, so a birthday never shifts a day.
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'gender': gender?.name,
      'blood_type': bloodType?.label,
      'emergency_contact_name': emergencyContact.name.trim(),
      'emergency_contact_phone': emergencyContact.phone.trim(),
      'has_completed_profile': true,
    };
  }

  @override
  List<Object?> get props =>
      [fullName, dateOfBirth, gender, bloodType, emergencyContact];
}
