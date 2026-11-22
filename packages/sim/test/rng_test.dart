import 'package:sim/sim.dart';
import 'package:test/test.dart';

void main() {
  group('Rng', () {
    test('matches independently computed golden values', () {
      // Values computed separately in Python from the same LCG constants.
      final r = Rng(42);
      expect(r.nextU32(), equals(1083814273));
      expect(r.nextU32(), equals(378494188));
      expect(r.nextU32(), equals(2479403867));
    });

    test('nextInt uses the high bits and stays in range', () {
      expect(Rng(42).nextInt(10), equals(7));
      final r = Rng(7);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextInt(6);
        expect(v >= 0 && v < 6, isTrue);
      }
    });

    test('copy is independent', () {
      final a = Rng(5);
      final b = a.copy();
      a.nextU32();
      expect(b.state, equals(Rng(5).state));
      expect(a.state, isNot(equals(b.state)));
    });
  });
}
