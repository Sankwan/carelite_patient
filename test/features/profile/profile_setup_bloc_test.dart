import 'package:bloc_test/bloc_test.dart';
import 'package:carelite_app/core/network/failure.dart';
import 'package:carelite_app/core/utils/result.dart';
import 'package:carelite_app/features/profile/data/profile_repository.dart';
import 'package:carelite_app/features/profile/domain/patient_profile.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_setup_bloc.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_setup_event.dart';
import 'package:carelite_app/features/profile/presentation/bloc/profile_setup_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _FakePatientProfile extends Fake implements PatientProfile {}

void main() {
  late _MockProfileRepository profileRepository;

  const userId = 'user-1';
  final dateOfBirth = DateTime(1995, 6, 12);

  setUpAll(() {
    registerFallbackValue(_FakePatientProfile());
  });

  setUp(() {
    profileRepository = _MockProfileRepository();
  });

  /// Fills the two required fields so the Bloc will accept a submit.
  void completeRequiredFields(ProfileSetupBloc bloc) {
    bloc
      ..add(const ProfileFullNameChanged('Esi Owusu'))
      ..add(ProfileDateOfBirthChanged(dateOfBirth));
  }

  group('ProfileSetupBloc', () {
    blocTest<ProfileSetupBloc, ProfileSetupState>(
      'builds up the draft profile as fields change',
      build: () => ProfileSetupBloc(profileRepository: profileRepository),
      act: (bloc) => bloc
        ..add(const ProfileFullNameChanged('Esi Owusu'))
        ..add(const ProfileGenderChanged(Gender.female))
        ..add(const ProfileBloodTypeChanged(BloodType.oPositive))
        ..add(const ProfileEmergencyContactChanged(name: 'Kwame Owusu')),
      expect: () => [
        isA<ProfileSetupState>()
            .having((s) => s.profile.fullName, 'fullName', 'Esi Owusu'),
        isA<ProfileSetupState>()
            .having((s) => s.profile.gender, 'gender', Gender.female),
        isA<ProfileSetupState>()
            .having((s) => s.profile.bloodType, 'bloodType', BloodType.oPositive),
        isA<ProfileSetupState>().having(
          (s) => s.profile.emergencyContact.name,
          'emergencyContact.name',
          'Kwame Owusu',
        ),
      ],
    );

    test('is not submittable until name and date of birth are present', () {
      const empty = PatientProfile();
      expect(empty.isSubmittable, isFalse);

      final nameOnly = empty.copyWith(fullName: 'Esi Owusu');
      expect(nameOnly.isSubmittable, isFalse);

      final complete = nameOnly.copyWith(dateOfBirth: dateOfBirth);
      expect(complete.isSubmittable, isTrue);
    });

    blocTest<ProfileSetupBloc, ProfileSetupState>(
      'ignores a submit while required fields are missing',
      build: () => ProfileSetupBloc(profileRepository: profileRepository),
      act: (bloc) => bloc.add(const ProfileSubmitted(userId)),
      expect: () => <ProfileSetupState>[],
      verify: (_) => verifyNever(
        () => profileRepository.saveProfile(
          userId: any(named: 'userId'),
          profile: any(named: 'profile'),
        ),
      ),
    );

    blocTest<ProfileSetupBloc, ProfileSetupState>(
      'emits [submitting, success] when the profile saves',
      build: () {
        when(() => profileRepository.saveProfile(
              userId: any(named: 'userId'),
              profile: any(named: 'profile'),
            )).thenAnswer((_) async => const Result.ok(null));
        return ProfileSetupBloc(profileRepository: profileRepository);
      },
      act: (bloc) {
        completeRequiredFields(bloc);
        bloc.add(const ProfileSubmitted(userId));
      },
      skip: 2, // the two field-change states
      expect: () => [
        isA<ProfileSetupState>()
            .having((s) => s.status, 'status', ProfileSetupStatus.submitting),
        isA<ProfileSetupState>()
            .having((s) => s.status, 'status', ProfileSetupStatus.success),
      ],
    );

    blocTest<ProfileSetupBloc, ProfileSetupState>(
      'returns to editing with the failure when the save is rejected',
      build: () {
        when(() => profileRepository.saveProfile(
              userId: any(named: 'userId'),
              profile: any(named: 'profile'),
            )).thenAnswer(
          (_) async => const Result.err(UnexpectedFailure('RLS denied')),
        );
        return ProfileSetupBloc(profileRepository: profileRepository);
      },
      act: (bloc) {
        completeRequiredFields(bloc);
        bloc.add(const ProfileSubmitted(userId));
      },
      skip: 2,
      expect: () => [
        isA<ProfileSetupState>()
            .having((s) => s.status, 'status', ProfileSetupStatus.submitting),
        isA<ProfileSetupState>()
            .having((s) => s.status, 'status', ProfileSetupStatus.editing)
            .having((s) => s.failure?.message, 'failure.message', 'RLS denied'),
      ],
    );
  });
}
