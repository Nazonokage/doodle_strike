import 'trig_table.g.dart';

/// Table-driven trigonometry on 16-bit integer angles (0..65535 = 0..360 deg).
///
/// This exists because the platform math library's transcendental functions
/// are not guaranteed to give identical results on ARM, x86 and the web.
/// The table is checked in; see tools/gen_trig_table.py.
class Trig {
  const Trig._();

  static const int angleMask = 0xFFFF;
  static const int _shift = 64; // 65536 angle units / 1024 table steps
  static const int _steps = 1024;
  static const int _quarter = 256;

  static double sinOf(int angle16) {
    final i = (angle16 & angleMask) ~/ _shift;
    return kSinTable[i];
  }

  static double cosOf(int angle16) {
    final i = ((angle16 & angleMask) ~/ _shift + _quarter) % _steps;
    return kSinTable[i];
  }

  /// Unit direction vector for an angle. 0 points right, angles increase
  /// toward +y (screen down).
  static ({double x, double y}) direction(int angle16) =>
      (x: cosOf(angle16), y: sinOf(angle16));

  /// Returns a 16-bit angle (0..65535) from (x1, y1) to (x2, y2).
  /// Uses binary search on kSinTable and Newton-Raphson square root to remain
  /// pure and deterministic across all architectures without the platform math library.
  static int angleBetween(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final distSq = dx * dx + dy * dy;
    if (distSq < 1e-12) return 0;

    var len = distSq > 1.0 ? distSq * 0.5 : 1.0;
    for (var i = 0; i < 10; i++) {
      len = 0.5 * (len + distSq / len);
    }

    final sinVal = (dy / len).abs();
    var low = 0;
    var high = _quarter;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (kSinTable[mid] < sinVal) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final step = low;

    int tableIndex;
    if (dx >= 0 && dy >= 0) {
      tableIndex = step;
    } else if (dx < 0 && dy >= 0) {
      tableIndex = 512 - step;
    } else if (dx < 0 && dy < 0) {
      tableIndex = 512 + step;
    } else {
      tableIndex = _steps - step;
    }
    return (tableIndex * _shift) & angleMask;
  }
}
