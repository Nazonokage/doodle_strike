import 'package:sim/sim.dart';
import 'package:test/test.dart';

void main() {
  group('TileMap', () {
    final map = TileMap.fromRows(const <String>[
      '####',
      '#S.#',
      '####',
    ]);

    test('parses size, solids and spawn points', () {
      expect(map.width, equals(4));
      expect(map.height, equals(3));
      expect(map.isSolid(0, 0), isTrue);
      expect(map.isSolid(1, 1), isFalse);
      expect(map.spawnPoints.length, equals(1));
      expect(map.spawnPoints.first.x, equals(1.5));
      expect(map.spawnPoints.first.y, closeTo(1.2, 1e-12));
    });

    test('outside the grid is solid', () {
      expect(map.isSolid(-1, 1), isTrue);
      expect(map.isSolid(1, 99), isTrue);
    });
  });
}
