/// Reads a human-readable message out of a Django REST Framework error body.
///
/// DRF has two shapes and uses both freely:
///
/// * `{"detail": "No available certified clinician matched this request."}`
///   — from `raise ValidationError({"detail": ...})`, permission denials and
///   404s.
/// * `{"scheduled_at": ["Required for a SCHEDULED booking."]}` — from field
///   validation, where every value is a *list* of strings.
///
/// Both were verified against a running instance (a bad login, a duplicate
/// registration, a booking with no clinician, and an unmatched `ANY`
/// booking). Reading only `detail` would have turned every field error into
/// "Something went wrong", which is exactly the message that makes a real,
/// fixable validation problem look like a broken app.
String drfMessage(dynamic body, {String fallback = 'Something went wrong. Please try again.'}) {
  if (body is Map) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    // `non_field_errors` is DRF's key for a serializer-level `validate()`
    // failure; it reads better than an arbitrary field, so prefer it.
    final ordered = [
      if (body.containsKey('non_field_errors')) body['non_field_errors'],
      ...body.entries
          .where((e) => e.key != 'non_field_errors')
          .map((e) => e.value),
    ];
    for (final value in ordered) {
      if (value is List && value.isNotEmpty) return '${value.first}';
      if (value is String && value.isNotEmpty) return value;
    }
  }
  if (body is List && body.isNotEmpty) return '${body.first}';
  return fallback;
}
