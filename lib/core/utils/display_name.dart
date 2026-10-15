/// Turns a raw backend `username` into something a patient can comfortably
/// read.
///
/// This backend has no name field anywhere (see `DjangoAuthRepository` and
/// `Provider.fromClinicianJson`) — `username` is the only identifier it
/// exposes, and the seeded clinician accounts are `dr_adjei`, `dr_owusu`,
/// `dr_mensah`… — snake_case with the honorific baked into the username
/// itself. Shown verbatim, "dr_adjei" read as a raw system identifier next
/// to a rating badge and a "Book" button — the underscore is what actually
/// broke the illusion of a polished screen.
///
/// This is presentation only: it does not invent information the backend
/// doesn't have (no surname is guessed, no "Dr." is added where the
/// username didn't already carry one) — it only reformats the exact string
/// the server sent. `formatUsername('dr_adjei')` → `'Dr. Adjei'`;
/// `formatUsername('kofi')` → `'Kofi'`; anything already clean (spaces,
/// mixed case) passes through unchanged rather than being mangled.
String formatUsername(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) return trimmed;

  // Already human-shaped (a real name, or nothing to fix) — leave it alone
  // rather than risk mangling something that didn't need reformatting.
  if (!trimmed.contains('_')) {
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  final parts = trimmed.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';

  String capitalize(String word) =>
      word[0].toUpperCase() + word.substring(1).toLowerCase();

  // "dr_adjei" → "Dr. Adjei": the one honorific this backend's seed data
  // actually uses, so it's the one case worth a period instead of a plain
  // capitalized word.
  final first = parts.first.toLowerCase();
  if (first == 'dr' && parts.length > 1) {
    return 'Dr. ${parts.skip(1).map(capitalize).join(' ')}';
  }

  return parts.map(capitalize).join(' ');
}

/// A clinician's name as patients should see it.
///
/// Uses the real name (`full_name`) when the account has one, prefixed
/// "Dr."; otherwise falls back to reformatting the username, so accounts
/// created without a name still read cleanly.
String clinicianDisplayName({String? fullName, required String username}) {
  final name = fullName?.trim() ?? '';
  if (name.isEmpty) return formatUsername(username);
  return RegExp(r'^dr\.?\s', caseSensitive: false).hasMatch(name)
      ? name
      : 'Dr. $name';
}

/// The account's real name, or null when it has none. Blank and missing
/// are the same thing to the UI.
String? realNameOrNull(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
