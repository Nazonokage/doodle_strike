import 'commands/input_command.dart';
import 'entities/projectile_state.dart';
import 'events/sim_event.dart';
import 'math/trig.dart';
import 'physics/physics_config.dart';
import 'physics/tile_map.dart';
import 'weapons/weapon_config.dart';
import 'world_state.dart';

/// Advances the world by whole 1/60 s ticks. No wall clock, no platform math,
/// no unordered iteration: given the same inputs it always yields the same
/// states, which is what prediction and replay rely on.
class Simulation {
  Simulation({
    required this.map,
    this.config = const PhysicsConfig(),
    WeaponConfig? weapon,
    List<WeaponConfig>? weapons,
    int seed = 1,
  })  : weapons = List<WeaponConfig>.unmodifiable(
          weapons ?? <WeaponConfig>[weapon ?? const WeaponConfig()],
        ),
        _state = WorldState(seed: seed) {
    if (this.weapons.isEmpty || this.weapons.length > 6) {
      throw ArgumentError('expected 1 to 6 weapons');
    }
  }

  final TileMap map;
  final PhysicsConfig config;
  final List<WeaponConfig> weapons;

  /// First weapon. Tests and older call sites treat this as the starting gun.
  WeaponConfig get weapon => weapons.first;

  WeaponConfig weaponOf(PlayerState player) => weapons[player.weaponIndex];
  WorldState _state;

  /// Sim events emitted during the last [step] call.
  /// Views can consume these after each tick to spawn visual/audio effects.
  final List<SimEvent> events = <SimEvent>[];

  static const double _eps = 1e-9;

  int get tick => _state.tick;

  WorldState get state => _state;

  /// Stable hash of the full state, for determinism tests and desync checks.
  int hash() => _state.hash();

  /// Copy of the full state (for the prediction buffer).
  WorldState snapshot() => _state.copy();

  /// Replace the full state with a copy of [s].
  void restore(WorldState s) {
    _state = s.copy();
  }

  /// Add a player. Without explicit coordinates, spawn points are used in
  /// order. Players are kept sorted by id.
  PlayerState addPlayer(int id, {double? x, double? y}) {
    if (_state.playerById(id) != null) {
      throw ArgumentError('player $id already exists');
    }
    var px = x;
    var py = y;
    if (px == null || py == null) {
      if (map.spawnPoints.isEmpty) {
        throw StateError('no spawn points and no explicit position given');
      }
      final sp = map.spawnPoints[_state.players.length % map.spawnPoints.length];
      px = sp.x;
      py = sp.y;
    }
    final p = PlayerState(
      id: id,
      x: px,
      y: py,
      fuel: config.fuelMax,
      health: config.healthMax,
      magAmmo: <int>[for (final w in weapons) w.magazineSize],
      shieldTicks: 40,
    );
    _state.players.add(p);
    _state.players.sort((a, b) => a.id.compareTo(b.id));
    return p;
  }

  /// Advance exactly one tick. A player with no entry in [inputs] repeats
  /// their last known input.
  void step(Map<int, InputCommand> inputs) {
    events.clear();

    // 1. Process players
    for (final p in _state.players) {
      final prev = p.input;
      final cmd = inputs[p.id];
      if (cmd != null) p.input = cmd;

      if (!p.alive) {
        _handleDeadPlayer(p);
        continue;
      }

      if (p.shieldTicks > 0) p.shieldTicks -= 1;
      _handleWeaponSelect(p, prev);
      _handlePlayerCombat(p, prev);
      _movePlayer(p);
    }

    // 2. Step active projectiles
    _stepProjectiles();

    _state.tick += 1;
  }

  void _handleDeadPlayer(PlayerState p) {
    p.respawnTimer -= 1;
    if (p.respawnTimer <= 0) {
      p.alive = true;
      p.health = config.healthMax;
      p.fuel = config.fuelMax;
      p.weaponIndex = 0;
      p.magAmmo
        ..clear()
        ..addAll(<int>[for (final w in weapons) w.magazineSize]);
      p.fireCooldown = 0;
      p.reloadCooldown = 0;
      p.shieldTicks = 75;
      p.vx = 0;
      p.vy = 0;

      if (map.spawnPoints.isNotEmpty) {
        final spIndex = (p.id + _state.rng.nextInt(map.spawnPoints.length)) % map.spawnPoints.length;
        final sp = map.spawnPoints[spIndex];
        p.x = sp.x;
        p.y = sp.y;
      }

      events.add(PlayerRespawnedEvent(playerId: p.id, x: p.x, y: p.y));
    }
  }

  void _handleWeaponSelect(PlayerState p, InputCommand prev) {
    final c = p.input;
    var index = p.weaponIndex;
    if (c.weaponId != 0) {
      for (var i = 0; i < weapons.length; i++) {
        if (weapons[i].id == c.weaponId) {
          index = i;
          break;
        }
      }
    } else if ((c.buttons & InputCommand.btnSwap) != 0 && (prev.buttons & InputCommand.btnSwap) == 0) {
      index = (index + 1) % weapons.length;
    }
    if (index != p.weaponIndex) {
      p.weaponIndex = index;
      // Switching cancels a reload in progress. The other magazine is kept.
      p.reloadCooldown = 0;
    }
  }

  void _handlePlayerCombat(PlayerState p, InputCommand prev) {
    final gun = weapons[p.weaponIndex];
    final c = p.input;

    // Reloading. A held reload key only starts a cycle on the press edge.
    if (p.reloadCooldown > 0) {
      p.reloadCooldown -= 1;
      if (p.reloadCooldown == 0) {
        p.ammo = gun.magazineSize;
      }
    } else if ((c.buttons & InputCommand.btnReload) != 0 &&
        (prev.buttons & InputCommand.btnReload) == 0 &&
        p.ammo < gun.magazineSize) {
      p.reloadCooldown = gun.reloadTicks;
    }

    if (p.fireCooldown > 0) {
      p.fireCooldown -= 1;
    }

    final trigger = gun.automatic ? c.firing : (c.firing && !prev.firing);
    if (trigger && p.fireCooldown <= 0 && p.reloadCooldown <= 0) {
      if (p.ammo > 0) {
        p.ammo -= 1;
        p.fireCooldown = gun.fireIntervalTicks;
        _spawnShot(p, gun, c.aim);
      } else {
        p.reloadCooldown = gun.reloadTicks;
      }
    }
  }

  void _spawnShot(PlayerState p, WeaponConfig gun, int aim) {
    final pellets = gun.pellets < 1 ? 1 : gun.pellets;
    double? originX;
    double? originY;
    for (var i = 0; i < pellets; i++) {
      var shotAim = aim;
      if (gun.spreadUnits > 0) {
        final span = gun.spreadUnits * 2 + 1;
        final delta = _state.rng.nextInt(span) - gun.spreadUnits;
        shotAim = (aim + delta) & 0xFFFF;
      }
      final dir = Trig.direction(shotAim);
      final projX = p.x + dir.x * 0.45;
      final projY = p.y + dir.y * 0.45;
      originX ??= projX;
      originY ??= projY;
      _state.projectiles.add(
        ProjectileState(
          id: _state.nextProjectileId++,
          shooterId: p.id,
          x: projX,
          y: projY,
          vx: dir.x * gun.projectileSpeed,
          vy: dir.y * gun.projectileSpeed,
          damage: gun.damage,
          lifetime: gun.projectileLifetimeTicks,
          radius: gun.projectileRadius,
        ),
      );
    }
    events.add(ShotFiredEvent(shooterId: p.id, x: originX ?? p.x, y: originY ?? p.y, aim: aim));
  }

  void _stepProjectiles() {
    if (_state.projectiles.isEmpty) return;

    // Stable sort by id
    _state.projectiles.sort((a, b) => a.id.compareTo(b.id));

    final aliveProjectiles = <ProjectileState>[];

    for (final pr in _state.projectiles) {
      pr.lifetime -= 1;
      if (pr.lifetime <= 0) continue;

      final steps = _substeps(pr.vx, pr.vy);
      final sx = pr.vx / steps;
      final sy = pr.vy / steps;
      var consumed = false;
      for (var s = 0; s < steps; s++) {
        pr.x += sx;
        pr.y += sy;

        if (map.isSolid(pr.x.floor(), pr.y.floor())) {
          events.add(ProjectileHitEvent(x: pr.x, y: pr.y, hitPlayerId: null, damage: 0));
          consumed = true;
          break;
        }

        if (_damagePlayers(pr)) {
          consumed = true;
          break;
        }
      }

      if (!consumed) aliveProjectiles.add(pr);
    }

    _state.projectiles
      ..clear()
      ..addAll(aliveProjectiles);
  }

  /// Splits a fast projectile so it cannot skip a one-tile wall or a body.
  static int _substeps(double vx, double vy) {
    final ax = vx < 0 ? -vx : vx;
    final ay = vy < 0 ? -vy : vy;
    final maxComponent = ax > ay ? ax : ay;
    var steps = 1;
    while (0.45 * steps < maxComponent && steps < 8) {
      steps += 1;
    }
    return steps;
  }

  /// Returns true when the projectile is spent on a player.
  /// Spawn shields absorb nothing: the shot flies on.
  bool _damagePlayers(ProjectileState pr) {
    for (final p in _state.players) {
      if (!p.alive || p.id == pr.shooterId || p.shieldTicks > 0) continue;

      final hw = config.halfWidth;
      final hh = config.halfHeight;
      final rad = pr.radius;
      final overlaps = pr.x + rad >= p.x - hw &&
          pr.x - rad <= p.x + hw &&
          pr.y + rad >= p.y - hh &&
          pr.y - rad <= p.y + hh;
      if (!overlaps) continue;

      p.health -= pr.damage;
      events.add(ProjectileHitEvent(x: pr.x, y: pr.y, hitPlayerId: p.id, damage: pr.damage));
      if (p.health <= 0) {
        p.health = 0;
        p.alive = false;
        p.shieldTicks = 0;
        p.deaths += 1;
        p.respawnTimer = 180; // 3 seconds at 60 Hz
        final shooter = _state.playerById(pr.shooterId);
        if (shooter != null) shooter.kills += 1;
        events.add(PlayerDiedEvent(victimId: p.id, killerId: pr.shooterId, x: p.x, y: p.y));
      }
      return true;
    }
    return false;
  }

  static int _clampStick(int v) => v < -127 ? -127 : (v > 127 ? 127 : v);

  void _movePlayer(PlayerState p) {
    final c = p.input;

    // Horizontal: stick maps directly to velocity
    p.vx = (_clampStick(c.moveX) / 127.0) * config.runSpeed;

    // Vertical: gravity always, thrust while jetting and fuel remains.
    final jetting = c.wantsJet && p.fuel > 0;
    if (jetting) {
      p.vy -= config.thrust;
      p.fuel -= config.fuelDrain;
      if (p.fuel < 0) p.fuel = 0;
    } else if (p.grounded) {
      p.fuel += config.fuelRecharge;
      if (p.fuel > config.fuelMax) p.fuel = config.fuelMax;
    }
    p.vy += config.gravity;
    if (p.vy < -config.maxRise) p.vy = -config.maxRise;
    if (p.vy > config.maxFall) p.vy = config.maxFall;

    // Move and resolve one axis at a time.
    p.x += p.vx;
    _resolveX(p);
    p.grounded = false;
    p.y += p.vy;
    _resolveY(p);
  }

  void _resolveX(PlayerState p) {
    final hw = config.halfWidth;
    final hh = config.halfHeight;
    final tx0 = (p.x - hw).floor();
    final tx1 = (p.x + hw - _eps).floor();
    final ty0 = (p.y - hh).floor();
    final ty1 = (p.y + hh - _eps).floor();
    for (var ty = ty0; ty <= ty1; ty++) {
      for (var tx = tx0; tx <= tx1; tx++) {
        if (!map.isSolid(tx, ty)) continue;
        if (p.vx > 0) {
          p.x = tx - hw;
        } else if (p.vx < 0) {
          p.x = tx + 1.0 + hw;
        }
        p.vx = 0;
        return;
      }
    }
  }

  void _resolveY(PlayerState p) {
    final hw = config.halfWidth;
    final hh = config.halfHeight;
    final tx0 = (p.x - hw).floor();
    final tx1 = (p.x + hw - _eps).floor();
    final ty0 = (p.y - hh).floor();
    final ty1 = (p.y + hh - _eps).floor();
    for (var ty = ty0; ty <= ty1; ty++) {
      for (var tx = tx0; tx <= tx1; tx++) {
        if (!map.isSolid(tx, ty)) continue;
        if (p.vy > 0) {
          p.y = ty - hh;
          p.grounded = true;
        } else if (p.vy < 0) {
          p.y = ty + 1.0 + hh;
        }
        p.vy = 0;
        return;
      }
    }
  }
}
