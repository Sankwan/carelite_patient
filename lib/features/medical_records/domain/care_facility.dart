import 'package:equatable/equatable.dart';

/// The lab, imaging centre or pharmacy a clinician sent the patient to.
///
/// Parsed from the `FacilitySerializer` object nested under
/// `assigned_facility` / `assigned_pharmacy`. Every field except the name is
/// optional on the server (`address`, `phone`, `operating_hours` are
/// `blank=True`), so a blank string is normalised to null here and the UI
/// offers only the actions it has data for.
class CareFacility extends Equatable {
  const CareFacility({
    required this.name,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.operatingHours,
  });

  static CareFacility? fromDjangoJson(Map<String, dynamic>? row) {
    if (row == null) return null;
    final name = _text(row['name']);
    if (name == null) return null;
    return CareFacility(
      name: name,
      address: _text(row['address']),
      phone: _text(row['phone']),
      latitude: (row['lat'] as num?)?.toDouble(),
      longitude: (row['lng'] as num?)?.toDouble(),
      operatingHours: _text(row['operating_hours']),
    );
  }

  final String name;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? operatingHours;

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasPhone => phone != null;

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props =>
      [name, address, phone, latitude, longitude, operatingHours];
}
