import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// One set of vitals captured during a consultation. Every measurement is
/// optional on the server — a clinician records whatever was actually
/// taken — so each field here is nullable rather than defaulted to 0,
/// which would read as a real reading.
class VitalsRecord extends Equatable {
  const VitalsRecord({
    required this.id,
    required this.recordedAt,
    this.recordedByUsername = '',
    this.bmi,
    this.systolic,
    this.diastolic,
    this.temperature,
    this.pulse,
    this.respiratoryRate,
    this.spo2,
    this.weightKg,
    this.heightCm,
    this.bloodGlucose,
  });

  factory VitalsRecord.fromDjangoJson(Map<String, dynamic> row) {
    return VitalsRecord(
      id: '${row['id']}',
      recordedAt: DateTime.parse(row['recorded_at'] as String).toLocal(),
      recordedByUsername: row['recorded_by_username'] as String? ?? '',
      bmi: _numFrom(row['bmi']),
      systolic: _intFrom(row['systolic']),
      diastolic: _intFrom(row['diastolic']),
      temperature: _numFrom(row['temperature']),
      pulse: _intFrom(row['pulse']),
      respiratoryRate: _intFrom(row['respiratory_rate']),
      spo2: _intFrom(row['spo2']),
      weightKg: _numFrom(row['weight_kg']),
      heightCm: _numFrom(row['height_cm']),
      bloodGlucose: _numFrom(row['blood_glucose']),
    );
  }

  final String id;
  final DateTime recordedAt;
  final String recordedByUsername;
  final double? bmi;
  final int? systolic;
  final int? diastolic;
  final double? temperature;
  final int? pulse;
  final int? respiratoryRate;
  final int? spo2;
  final double? weightKg;
  final double? heightCm;
  final double? bloodGlucose;

  /// "120/80" or null if either half is missing — a lone systolic or
  /// diastolic number is not a blood-pressure reading.
  String? get bloodPressureLabel =>
      (systolic != null && diastolic != null) ? '$systolic/$diastolic' : null;

  /// True once at least one measurement was actually taken — a row that
  /// somehow has nothing is not worth a card.
  bool get hasAnyMeasurement =>
      bloodPressureLabel != null ||
      temperature != null ||
      pulse != null ||
      respiratoryRate != null ||
      spo2 != null ||
      weightKg != null ||
      heightCm != null ||
      bloodGlucose != null;

  String get dateLabel => DateFormat('d MMM yyyy, h:mm a').format(recordedAt);

  static double? _numFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        recordedAt,
        recordedByUsername,
        bmi,
        systolic,
        diastolic,
        temperature,
        pulse,
        respiratoryRate,
        spo2,
        weightKg,
        heightCm,
        bloodGlucose,
      ];
}
