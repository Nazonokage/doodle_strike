import 'dart:io';

import 'package:sim/sim.dart';
import 'package:test/test.dart';

void main() {
  test('the shipped weapon file parses into four guns', () {
    final raw = File('../../assets/data/weapons.json').readAsStringSync();
    final weapons = WeaponCatalog.parse(raw);
    expect(weapons.map((w) => w.name), ['Rifle', 'Pistol', 'Shotgun', 'SMG']);
    expect(weapons[1].automatic, isFalse);
    expect(weapons[2].pellets, 5);
    expect(weapons[3].automatic, isTrue);
  });

  test('unknown fields are rejected', () {
    const raw = '''
[
  {
    "id": 1,
    "name": "Rifle",
    "damage": 10,
    "fireIntervalTicks": 8,
    "projectileSpeed": 0.5,
    "lifetimeTicks": 40,
    "spreadUnits": 0,
    "magazine": 10,
    "reloadTicks": 40,
    "automatic": true,
    "pellets": 1,
    "projectileRadius": 0.1,
    "recoil": 3
  }
]
''';
    expect(() => WeaponCatalog.parse(raw), throwsFormatException);
  });
}