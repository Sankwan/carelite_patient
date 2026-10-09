import 'package:equatable/equatable.dart';

import '../../domain/patient_profile.dart';

sealed class ProfileSetupEvent extends Equatable {
  const ProfileSetupEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileFullNameChanged extends ProfileSetupEvent {
  const ProfileFullNameChanged(this.fullName);

  final String fullName;

  @override
  List<Object?> get props => [fullName];
}

final class ProfileDateOfBirthChanged extends ProfileSetupEvent {
  const ProfileDateOfBirthChanged(this.dateOfBirth);

  final DateTime dateOfBirth;

  @override
  List<Object?> get props => [dateOfBirth];
}

final class ProfileGenderChanged extends ProfileSetupEvent {
  const ProfileGenderChanged(this.gender);

  final Gender gender;

  @override
  List<Object?> get props => [gender];
}

final class ProfileBloodTypeChanged extends ProfileSetupEvent {
  const ProfileBloodTypeChanged(this.bloodType);

  final BloodType bloodType;

  @override
  List<Object?> get props => [bloodType];
}

final class ProfileEmergencyContactChanged extends ProfileSetupEvent {
  const ProfileEmergencyContactChanged({this.name, this.phone});

  final String? name;
  final String? phone;

  @override
  List<Object?> get props => [name, phone];
}

final class ProfileSubmitted extends ProfileSetupEvent {
  const ProfileSubmitted(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
