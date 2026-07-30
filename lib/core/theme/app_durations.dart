class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static const Duration navigation = Duration(milliseconds: 220);

  // Named entrance / reveal timings. Distinct from the general slow
  // bucket so hero animations can outlast the slow scale without drifting.
  static const Duration entranceShort = Duration(milliseconds: 800);
  static const Duration entranceLong = Duration(milliseconds: 1200);
  static const Duration splash = Duration(milliseconds: 1500);
  static const Duration pulse = Duration(milliseconds: 1500);

  // Expand / collapse panels (settings sub-tiles, transcript).
  static const Duration expand = Duration(milliseconds: 220);
  static const Duration collapse = Duration(milliseconds: 180);
}
