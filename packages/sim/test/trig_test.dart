import 'package:sim/sim.dart';
import 'package:test/test.dart';

void main() {
  group('Trig', () {
    test('quarter turns are exact', () {
      expect(Trig.sinOf(0), equals(0.0));
      expect(Trig.cosOf(0), equals(1.0));
      expect(Trig.sinOf(16384), equals(1.0));
      expect(Trig.cosOf(16384), equals(0.0));
      expect(Trig.sinOf(32768), equals(0.0));
      expect(Trig.cosOf(32768), equals(-1.0));
      expect(Trig.sinOf(49152), equals(-1.0));
      expect(Trig.cosOf(49152), equals(0.0));
    });

    test('eighth turn matches the known constant', () {
      // 8192 = 45 degrees. Hard-coded so a bad table is caught.
      expect(Trig.sinOf(8192), closeTo(0.7071067811865476, 1e-12));
      expect(Trig.cosOf(8192), closeTo(0.7071067811865476, 1e-12));
    });

    test('every table step has unit length', () {
      for (var a = 0; a < 65536; a += 64) {
        final s = Trig.sinOf(a);
        final c = Trig.cosOf(a);
        expect(s * s + c * c, closeTo(1.0, 1e-12));
      }
    });

    test('angles wrap at 16 bits', () {
      expect(Trig.sinOf(65536 + 16384), equals(1.0));
      expect(Trig.cosOf(-1), equals(Trig.cosOf(65535)));
    });

    test('direction returns cos and sin', () {
      final d = Trig.direction(16384);
      expect(d.x, equals(0.0));
      expect(d.y, equals(1.0));
    });

    test('angleBetween matches cardinal directions', () {
      expect(Trig.angleBetween(0, 0, 10, 0), equals(0)); // Right
      expect(Trig.angleBetween(0, 0, 0, 10), equals(16384)); // Down (+y)
      expect(Trig.angleBetween(0, 0, -10, 0), equals(32768)); // Left
      expect(Trig.angleBetween(0, 0, 0, -10), equals(49152)); // Up (-y)
    });
  });
}
