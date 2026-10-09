/// Derives avatar initials from a person's name.
///
/// One implementation on purpose. The Figma mockups hardcode initials in a
/// layer separate from the name beside them, which is how "Dr. Ama Owusu"
/// ends up next to the wrong monogram on the Notifications screen. Deriving
/// them makes that class of bug impossible.
///
/// Honorifics are dropped so "Dr. Ama Owusu" reads AO, not DA.
String initialsOf(String fullName) {
  const honorifics = {'dr', 'dr.', 'mr', 'mr.', 'mrs', 'mrs.', 'ms', 'ms.', 'prof', 'prof.'};

  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .where((part) => !honorifics.contains(part.toLowerCase()))
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final word = parts.first;
    return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
