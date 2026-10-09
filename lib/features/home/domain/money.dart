/// Ghana cedis, stored as pesewas so no amount is ever a float.
///
/// Money never becomes a double anywhere in this app: a rounding drift
/// between the app's display and the server's arithmetic is exactly the
/// sort of bug that stays invisible until reconciliation.
extension type const Money(int pesewas) {
  /// "GHS 180" for whole cedis, "GHS 89.50" when there are pesewas.
  String get formatted {
    final cedis = pesewas ~/ 100;
    final remainder = pesewas % 100;
    if (remainder == 0) return 'GHS $cedis';
    return 'GHS $cedis.${remainder.toString().padLeft(2, '0')}';
  }
}
