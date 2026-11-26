import 'package:sim/sim.dart';
import 'package:test/test.dart';

const List<String> _rows = <String>[
  '####################',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#S.................#',
  '####################',
];

Simulation _newSim({int players = 1}) {
  final sim = Simulation(map: TileMap.fromRows(_rows), seed: 1);
  for (var i = 1; i <= players; i++) {
    sim.addPlayer(i, x: 1.5 + i * 2, y: 5.2);
  }
  return sim;
}

InputCommand _in({int moveX = 0, int moveY = 0, int buttons = 0}) =>
    InputCommand(tick: 0, moveX: moveX, moveY: moveY, buttons: buttons);

void _run(Simulation sim, int ticks, InputCommand cmd, {int pid = 1}) {
  for (var i = 0; i < ticks; i++) {
    sim.step(<int, InputCommand>{pid: cmd});
  }
}

/// Deterministic pseudo-input that exercises movement, jet and aim.
InputCommand _scripted(int pid, int t) => InputCommand(
      tick: t,
      moveX: ((t * 7 + pid * 13) % 255) - 127,
      moveY: ((t * 5 + pid * 3) % 255) - 127,
      aim: (t * 331 + pid * 97) & 0xFFFF,
      buttons: ((t + pid * 17) % 90 < 45) ? InputCommand.btnJet : 0,
    );

List<int> _scriptedRun(int ticks) {
  final sim = _newSim(players: 3);
  final hashes = <int>[];
  for (var t = 0; t < ticks; t++) {
    sim.step(<int, InputCommand>{
      for (var pid = 1; pid <= 3; pid++) pid: _scripted(pid, t),
    });
    hashes.add(sim.hash());
  }
  return hashes;
}

void main() {
  group('movement and physics', () {
    test('a grounded player stays put under gravity', () {
      final sim = _newSim();
      _run(sim, 60, _in());
      final p = sim.state.players.first;
      expect(p.grounded, isTrue);
      expect(p.y, closeTo(5.2, 1e-9));
      expect(p.vy, equals(0.0));
    });

    test('an airborne player falls and lands', () {
      final sim = Simulation(map: TileMap.fromRows(_rows));
      sim.addPlayer(1, x: 5.5, y: 2.0);
      _run(sim, 200, _in());
      final p = sim.state.players.first;
      expect(p.grounded, isTrue);
      expect(p.y, closeTo(5.2, 1e-9));
    });

    test('the jetpack rises and drains fuel', () {
      final sim = _newSim();
      _run(sim, 30, _in(buttons: InputCommand.btnJet));
      final p = sim.state.players.first;
      expect(p.y < 5.2, isTrue);
      expect(p.fuel, equals(150));
      expect(p.grounded, isFalse);
    });

    test('pushing the stick up also fires the jetpack', () {
      final sim = _newSim();
      _run(sim, 30, _in(moveY: -127));
      expect(sim.state.players.first.y < 5.2, isTrue);
    });

    test('fuel runs out, the player falls, lands and recharges', () {
      final sim = _newSim();
      _run(sim, 180, _in(buttons: InputCommand.btnJet));
      expect(sim.state.players.first.fuel, equals(0));
      _run(sim, 300, _in());
      final p = sim.state.players.first;
      expect(p.grounded, isTrue);
      expect(p.fuel, equals(180));
    });

    test('the ceiling stops the jetpack', () {
      final sim = _newSim();
      _run(sim, 120, _in(buttons: InputCommand.btnJet));
      final p = sim.state.players.first;
      // Ceiling tile row 0 ends at y = 1, so the center cannot go above 1.8.
      expect(p.y >= 1.8 - 1e-9, isTrue);
    });

    test('walls stop horizontal movement on both sides', () {
      final sim = _newSim();
      _run(sim, 300, _in(moveX: 127));
      expect(sim.state.players.first.x, closeTo(18.6, 1e-9));
      _run(sim, 400, _in(moveX: -127));
      expect(sim.state.players.first.x, closeTo(1.4, 1e-9));
    });

    test('jetpacking while pressing against the left wall stays within bounds', () {
      final sim = _newSim();
      // Move to left wall
      _run(sim, 400, _in(moveX: -127));
      expect(sim.state.players.first.x, closeTo(1.4, 1e-9));
      // Jetpack up against the left wall
      _run(sim, 60, _in(moveX: -127, buttons: InputCommand.btnJet));
      final p = sim.state.players.first;
      expect(p.x, closeTo(1.4, 1e-9));
      expect(p.y < 5.2, isTrue);
      expect(p.y >= 1.8 - 1e-9, isTrue);
      expect(p.alive, isTrue);
    });

    test('an out of bounds player dies and initiates respawn', () {
      final sim = _newSim();
      final p = sim.state.players.first;
      p.x = -5.0; // Force OOB
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.alive, isFalse);
      expect(p.health, equals(0));
      expect(p.deaths, equals(1));
      expect(p.respawnTimer, equals(180));
      expect(sim.events.any((e) => e is PlayerDiedEvent && e.victimId == 1), isTrue);
    });

    test('a missing input repeats the last known input', () {
      final sim = _newSim();
      sim.step(<int, InputCommand>{1: _in(moveX: 127)});
      final x1 = sim.state.players.first.x;
      sim.step(<int, InputCommand>{});
      expect(sim.state.players.first.x > x1, isTrue);
    });
  });

  group('players', () {
    test('are kept sorted by id and ids are unique', () {
      final sim = Simulation(map: TileMap.fromRows(_rows));
      sim.addPlayer(3, x: 2, y: 5.2);
      sim.addPlayer(1, x: 4, y: 5.2);
      sim.addPlayer(2, x: 6, y: 5.2);
      expect(sim.state.players.map((p) => p.id).toList(), equals(<int>[1, 2, 3]));
      expect(() => sim.addPlayer(2, x: 8, y: 5.2), throwsArgumentError);
    });

    test('spawn points are used when no position is given', () {
      final sim = Simulation(map: TileMap.fromRows(_rows));
      final p = sim.addPlayer(1);
      expect(p.x, equals(1.5));
      expect(p.y, closeTo(5.2, 1e-12));
    });
  });

  group('snapshot, restore and hash', () {
    test('restore then replay gives the same hash as the original run', () {
      final sim = _newSim(players: 2);
      for (var t = 0; t < 40; t++) {
        sim.step(<int, InputCommand>{1: _scripted(1, t), 2: _scripted(2, t)});
      }
      final snap = sim.snapshot();
      final snapHash = sim.hash();

      for (var t = 40; t < 80; t++) {
        sim.step(<int, InputCommand>{1: _scripted(1, t), 2: _scripted(2, t)});
      }
      final firstRun = sim.hash();

      sim.restore(snap);
      expect(sim.hash(), equals(snapHash));
      for (var t = 40; t < 80; t++) {
        sim.step(<int, InputCommand>{1: _scripted(1, t), 2: _scripted(2, t)});
      }
      expect(sim.hash(), equals(firstRun));
    });

    test('a snapshot is independent of later steps', () {
      final sim = _newSim();
      final snap = sim.snapshot();
      final before = snap.hash();
      _run(sim, 20, _in(moveX: 127));
      expect(snap.hash(), equals(before));
    });

    test('hash changes when state changes', () {
      final sim = _newSim();
      final h0 = sim.hash();
      _run(sim, 1, _in(moveX: 127));
      expect(sim.hash(), isNot(equals(h0)));
    });
  });

  group('combat and shooting', () {
    test('firing spawns projectiles and drains ammo', () {
      final sim = _newSim(players: 1);
      final p = sim.state.players.first;
      expect(p.ammo, equals(sim.weapon.magazineSize));
      expect(sim.state.projectiles, isEmpty);

      // Fire to the right (aim 0)
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      expect(p.ammo, equals(sim.weapon.magazineSize - 1));
      expect(sim.state.projectiles.length, equals(1));
      final pr = sim.state.projectiles.first;
      expect(pr.shooterId, equals(1));
      expect(pr.vx > 0, isTrue);
      expect(sim.events.whereType<ShotFiredEvent>().length, equals(1));
    });

    test('projectiles hit enemy players and deal damage', () {
      final sim = _newSim(players: 2);
      final p2 = sim.state.players[1];
      expect(p2.health, equals(100));
      p2.shieldTicks = 0;

      // Aim directly at p2 (aim 0 = right) and fire
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      var hitEventFired = false;
      for (var i = 0; i < 20; i++) {
        sim.step(<int, InputCommand>{});
        if (sim.events.any((e) => e is ProjectileHitEvent && e.hitPlayerId == 2)) {
          hitEventFired = true;
        }
      }

      expect(p2.health < 100, isTrue);
      expect(hitEventFired, isTrue);
    });

    test('fatal damage causes death and initiates respawn timer', () {
      final sim = _newSim(players: 2);
      final p1 = sim.state.players[0];
      final p2 = sim.state.players[1];
      p2.health = 10; // 1 shot kill
      p2.shieldTicks = 0;

      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      for (var i = 0; i < 20; i++) {
        sim.step(<int, InputCommand>{});
      }

      expect(p2.alive, isFalse);
      expect(p2.deaths, equals(1));
      expect(p1.kills, equals(1));
      expect(p2.respawnTimer > 0, isTrue);
    });

    test('spawn shield ignores damage until it expires', () {
      final sim = _newSim(players: 2);
      final p2 = sim.state.players[1];
      expect(p2.shieldTicks, equals(40));
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      for (var i = 0; i < 20; i++) {
        sim.step(<int, InputCommand>{});
      }
      expect(p2.health, equals(100));
      expect(p2.alive, isTrue);
    });

    test('a semi-auto weapon fires once per press', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(automatic: false, fireIntervalTicks: 5, magazineSize: 8),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.first;
      final held = _in(buttons: InputCommand.btnFire);
      for (var i = 0; i < 12; i++) {
        sim.step(<int, InputCommand>{1: held});
      }
      expect(p.ammo, equals(7));
      sim.step(<int, InputCommand>{1: _in()});
      sim.step(<int, InputCommand>{1: held});
      expect(p.ammo, equals(6));
    });

    test('spawn loadout is a pistol in slot 1 and an empty slot 2', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 1, name: 'Rifle', magazineSize: 10),
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, automatic: false),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.single;
      expect(p.loadout, equals(<int>[1, PlayerState.emptyWeapon]));
      expect(p.activeSlot, equals(0));
      expect(p.ammo, equals(4));
      expect(p.magAmmo, equals(<int>[4, 0]));
    });

    test('switch toggles the two carried slots and keeps each magazine', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 1, magazineSize: 10),
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, automatic: false),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.first;
      p.loadout[0] = 0;
      p.magAmmo[0] = 10;
      p.loadout[1] = 1;
      p.magAmmo[1] = 4;
      p.activeSlot = 0;
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      expect(p.ammo, equals(9));
      sim.step(<int, InputCommand>{1: _in()});
      sim.step(<int, InputCommand>{
        1: _in(buttons: InputCommand.btnSwap),
      });
      expect(p.activeSlot, equals(1));
      expect(p.weaponIndex, equals(1));
      expect(p.ammo, equals(4));
      for (var i = 0; i < 10; i++) {
        sim.step(<int, InputCommand>{1: _in()});
      }
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnFire)});
      expect(p.ammo, equals(3));
      sim.step(<int, InputCommand>{
        1: const InputCommand(tick: 0, weaponId: 1),
      });
      expect(p.activeSlot, equals(0));
      expect(p.ammo, equals(9));
    });

    test('an empty slot does not accept a switch', () {
      final sim = _newSim();
      final p = sim.state.players.single;
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnSwap)});
      expect(p.activeSlot, equals(0));
      expect(p.loadout[1], equals(PlayerState.emptyWeapon));
    });

    test('walking onto a gun fills the empty slot', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 1, magazineSize: 10),
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, automatic: false),
        ],
        seed: 7,
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      sim.spawnGunField(count: 1);
      final gun = sim.state.pickups.single;
      final p = sim.state.players.single;
      p.x = gun.x;
      p.y = gun.y;
      final taken = gun.weaponIndex;
      final rounds = gun.ammo;
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.loadout[0], equals(1));
      expect(p.loadout[1], equals(taken));
      expect(p.activeSlot, equals(1));
      expect(p.ammo, equals(rounds));
      expect(gun.onGround, isFalse);
      expect(sim.events.whereType<GunPickedUpEvent>().length, equals(1));
    });

    test('a full loadout stays full until the active gun is dropped onto the pickup', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 1, name: 'Rifle', magazineSize: 10),
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, automatic: false),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.single;
      p.loadout[0] = 0;
      p.magAmmo[0] = 9;
      p.loadout[1] = 1;
      p.magAmmo[1] = 2;
      p.activeSlot = 1;
      sim.state.pickups.add(
        PickupState(id: 1, x: p.x, y: p.y, weaponIndex: 0, ammo: 10),
      );
      sim.state.nextPickupId = 2;
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.loadout, equals(<int>[0, 1]));
      expect(p.ammo, equals(2));
      expect(sim.state.pickups.single.onGround, isTrue);

      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnDrop)});
      expect(p.loadout[1], equals(0));
      expect(p.magAmmo[1], equals(10));
      expect(p.loadout[0], equals(0));
      expect(sim.state.pickups.single.weaponIndex, equals(1));
      expect(sim.state.pickups.single.ammo, equals(2));
      expect(sim.state.pickups.single.onGround, isTrue);
    });

    test('drop puts the active gun on the map and does not pick it straight back up', () {
      final sim = _newSim();
      final p = sim.state.players.single;
      p.ammo = 11;
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnDrop)});
      expect(p.loadout[0], equals(PlayerState.emptyWeapon));
      expect(p.ammo, equals(0));
      final gun = sim.state.pickups.single;
      expect(gun.weaponIndex, equals(0));
      expect(gun.ammo, equals(11));
      expect(gun.onGround, isTrue);
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.loadout[0], equals(PlayerState.emptyWeapon));
      sim.step(<int, InputCommand>{1: _in(moveX: 127)});
      for (var i = 0; i < 40; i++) {
        sim.step(<int, InputCommand>{1: _in(moveX: 127)});
      }
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.ignorePickupId, equals(0));
    });

    test('reload refills the active magazine when its timer ends', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, reloadTicks: 5, automatic: false),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.single;
      p.ammo = 2;
      sim.step(<int, InputCommand>{1: _in(buttons: InputCommand.btnReload)});
      expect(p.reloadCooldown, equals(5));
      expect(p.ammo, equals(2));
      for (var i = 0; i < 4; i++) {
        sim.step(<int, InputCommand>{1: _in()});
        expect(p.ammo, equals(2));
      }
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.reloadCooldown, equals(0));
      expect(p.ammo, equals(4));
    });

    test('respawn restores the starting pistol and clears the second slot', () {
      final sim = Simulation(
        map: TileMap.fromRows(_rows),
        weapons: const <WeaponConfig>[
          WeaponConfig(id: 1, name: 'Rifle', magazineSize: 10),
          WeaponConfig(id: 2, name: 'Pistol', magazineSize: 4, automatic: false),
        ],
      );
      sim.addPlayer(1, x: 3, y: 5.2);
      final p = sim.state.players.single;
      p.loadout[1] = 0;
      p.magAmmo[1] = 3;
      p.activeSlot = 1;
      p.alive = false;
      p.respawnTimer = 1;
      sim.step(<int, InputCommand>{1: _in()});
      expect(p.alive, isTrue);
      expect(p.loadout, equals(<int>[1, PlayerState.emptyWeapon]));
      expect(p.activeSlot, equals(0));
      expect(p.ammo, equals(4));
    });

    test('a taken gun comes back, and the same seed replays the same hashes', () {
      List<int> run() {
        final sim = Simulation(map: TileMap.fromRows(_rows), seed: 3);
        sim.addPlayer(1, x: 4, y: 5.2);
        sim.spawnGunField(count: 2);
        final gun = sim.state.pickups.first;
        final p = sim.state.players.single;
        p.x = gun.x;
        p.y = gun.y;
        sim.step(<int, InputCommand>{1: _in()});
        expect(gun.respawnTicks, equals(Simulation.gunRespawnTicks - 1));
        final hashes = <int>[sim.hash()];
        // Stop on the tick it reappears, before a player can grab it again.
        for (var i = 0; i < Simulation.gunRespawnTicks - 1; i++) {
          sim.step(<int, InputCommand>{1: _in()});
          hashes.add(sim.hash());
        }
        expect(gun.onGround, isTrue);
        return hashes;
      }

      final first = run();
      expect(run(), equals(first));
    });

    test('bot controller computes aim and fires at enemy', () {
      final sim = _newSim(players: 2);
      const bot = BotController(botId: 2);
      final botCmd = bot.computeInput(sim.state, sim.tick);
      expect(botCmd.firing, isTrue);
      expect(botCmd.aim, isNonZero);
    });
  });

  group('determinism', () {
    test('the same inputs give identical per-tick hashes', () {
      expect(_scriptedRun(600), equals(_scriptedRun(600)));
    });

    test('golden hash of the scripted scenario', () {
      // Movement is unchanged. The hash moved because each player now carries
      // a two-slot loadout (starting gun plus an empty slot) and pickups hash
      // their ammo, even when this run spawns none.
      expect(_scriptedRun(600).last, equals(3453363565));
    });
  });
}
