import 'commands/input_command.dart';
import 'entities/pickup_state.dart';
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

  /// First weapon. Tests and older call sites treat this as the fallback gun.
  WeaponConfig get weapon => weapons.first;

  /// Catalog id of the pistol players spawn with. Falls back to the first
  /// weapon when the catalog has no pistol (unit tests with one gun).
  static const int pistolWeaponId = 2;

  /// Gun in the player's hands, or null when that slot is empty.
  WeaponConfig? carriedWeapon(PlayerState player) {
    final index = player.weaponIndex;
    if (index < 0 || index >= weapons.length) return null;
    return weapons[index];
  }

  WeaponConfig weaponOf(PlayerState player) => carriedWeapon(player) ?? weapon;
  WorldState _state;

  /// Sim events emitted during the last [step] call.
  /// Views can consume these after each tick to spawn visual/audio effects.
  final List<SimEvent> events = <SimEvent>[];

  static const double _eps = 1e-9;

  /// Ticks a taken gun stays gone before another one appears. 5 seconds.
  static const int gunRespawnTicks = 300;
  static const int supplyRespawnTicks = 480;
  static const int grenadeFuseTicks = 90;
  static const double grenadeBlastRadius = 4.5;
  static const int grenadeBlastDamage = 72;
  static const int punchDamage = 18;

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
      final sp =
          map.spawnPoints[_state.players.length % map.spawnPoints.length];
      px = sp.x;
      py = sp.y;
    }
    final p = PlayerState(
      id: id,
      x: px,
      y: py,
      fuel: config.fuelMax,
      health: config.healthMax,
      shieldTicks: 40,
      grenades: 1,
    );
    _applyStartingLoadout(p);
    _state.players.add(p);
    _state.players.sort((a, b) => a.id.compareTo(b.id));
    return p;
  }

  /// Drop [count] guns on grounded open tiles. Draws from the sim PRNG, so
  /// the same seed always lays out the same guns. Call once, before ticking.
  void spawnGunField({int count = 5}) {
    for (var n = 0; n < count; n++) {
      final placed = _placeGun();
      if (!placed) return;
    }
  }

  /// Add one grenade and one shield pickup to the arena. Their positions are
  /// selected by the same seeded generator as weapon drops.
  void spawnUtilityField() {
    _placePickup(PickupKind.grenade);
    _placePickup(PickupKind.shield);
  }

  /// Advance exactly one tick. A player with no entry in [inputs] repeats
  /// their last known input.
  void step(Map<int, InputCommand> inputs) {
    events.clear();
    final previous = <int, InputCommand>{};

    // 1. Process players
    for (final p in _state.players) {
      final prev = p.input;
      previous[p.id] = prev;
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

      // Out-of-bounds safety net: if a player escapes the map, trigger death and respawn.
      if (p.x < 0 || p.x > map.width || p.y < 0 || p.y > map.height) {
        p.health = 0;
        p.alive = false;
        p.shieldTicks = 0;
        p.deaths += 1;
        p.respawnTimer = 180;
        events.add(
            PlayerDiedEvent(victimId: p.id, killerId: p.id, x: p.x, y: p.y));
      }
    }

    // Resolve melee after every player has moved so knockback is not
    // overwritten by a later player's movement update in this tick.
    for (final p in _state.players) {
      if (p.alive && carriedWeapon(p) == null) {
        _punchIfRequested(p, previous[p.id] ?? InputCommand.neutral);
      }
    }

    // 2. Guns on the ground, then shots. Pickup checks use the post-move pose.
    _collectPickups(previous);
    _tickPickups();

    // 3. Step active projectiles
    _stepProjectiles();

    _state.tick += 1;
  }

  void _handleDeadPlayer(PlayerState p) {
    p.respawnTimer -= 1;
    if (p.respawnTimer <= 0) {
      p.alive = true;
      p.health = config.healthMax;
      p.fuel = config.fuelMax;
      _applyStartingLoadout(p);
      p.fireCooldown = 0;
      p.reloadCooldown = 0;
      p.shieldTicks = 75;
      p.shield = 0;
      p.grenades = 1;
      p.meleeCooldown = 0;
      p.vx = 0;
      p.vy = 0;

      if (map.spawnPoints.isNotEmpty) {
        final spIndex = (p.id + _state.rng.nextInt(map.spawnPoints.length)) %
            map.spawnPoints.length;
        final sp = map.spawnPoints[spIndex];
        p.x = sp.x;
        p.y = sp.y;
      }

      events.add(PlayerRespawnedEvent(playerId: p.id, x: p.x, y: p.y));
    }
  }

  void _handleWeaponSelect(PlayerState p, InputCommand prev) {
    final c = p.input;
    var slot = p.activeSlot;
    if (c.weaponId == 1 || c.weaponId == 2) {
      final requested = c.weaponId - 1;
      if (p.occupies(requested)) slot = requested;
    } else if ((c.buttons & InputCommand.btnSwap) != 0 &&
        (prev.buttons & InputCommand.btnSwap) == 0) {
      final other = slot == 0 ? 1 : 0;
      if (p.occupies(other)) slot = other;
    }
    if (slot != p.activeSlot) {
      p.activeSlot = slot;
      // Switching cancels a reload in progress. The other magazine is kept.
      p.reloadCooldown = 0;
    }
  }

  void _handlePlayerCombat(PlayerState p, InputCommand prev) {
    _throwGrenadeIfRequested(p, prev);
    final gun = carriedWeapon(p);
    final c = p.input;
    if (gun == null) {
      if (p.fireCooldown > 0) p.fireCooldown -= 1;
      p.reloadCooldown = 0;
      return;
    }

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

  void _throwGrenadeIfRequested(PlayerState p, InputCommand prev) {
    final current = p.input.buttons & InputCommand.btnGrenade;
    final previous = prev.buttons & InputCommand.btnGrenade;
    if (current == 0 || previous != 0 || p.grenades <= 0) return;
    p.grenades -= 1;
    final direction = Trig.direction(p.input.aim);
    _state.projectiles.add(
      ProjectileState(
        id: _state.nextProjectileId++,
        shooterId: p.id,
        x: p.x + direction.x * 0.55,
        y: p.y + direction.y * 0.55,
        vx: p.vx + direction.x * 0.22,
        vy: p.vy + direction.y * 0.22,
        damage: grenadeBlastDamage,
        lifetime: grenadeFuseTicks,
        radius: 0.16,
        kind: ProjectileKind.grenade,
        fuseTicks: grenadeFuseTicks,
        blastRadius: grenadeBlastRadius,
      ),
    );
  }

  void _punchIfRequested(PlayerState p, InputCommand prev) {
    if (p.meleeCooldown > 0) p.meleeCooldown -= 1;
    final now = p.input.buttons;
    final pressed = ((now & InputCommand.btnFire) != 0 &&
            (prev.buttons & InputCommand.btnFire) == 0) ||
        ((now & InputCommand.btnMelee) != 0 &&
            (prev.buttons & InputCommand.btnMelee) == 0);
    if (!pressed || p.meleeCooldown > 0) return;

    p.meleeCooldown = 32;
    final direction = Trig.direction(p.input.aim);
    PlayerState? target;
    var nearestDistSq = 3.24;
    for (final candidate in _state.players) {
      if (!candidate.alive || candidate.id == p.id || candidate.shieldTicks > 0)
        continue;
      final dx = candidate.x - p.x;
      final dy = candidate.y - p.y;
      final distanceSq = dx * dx + dy * dy;
      final inFront = dx * direction.x + dy * direction.y >= 0.2;
      if (inFront && distanceSq < nearestDistSq) {
        nearestDistSq = distanceSq;
        target = candidate;
      }
    }
    if (target == null) return;

    final airborne = !target.grounded || target.vy.abs() > 0.025;
    final knockback = airborne ? 0.42 : 0.22;
    target.knockbackX += direction.x * knockback;
    target.vy += direction.y * knockback - (airborne ? 0.16 : 0.025);
    _applyDamage(target, punchDamage, p.id);
    events.add(
      MeleeHitEvent(
        playerId: p.id,
        targetId: target.id,
        x: target.x,
        y: target.y,
        damage: punchDamage,
      ),
    );
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
    events.add(ShotFiredEvent(
        shooterId: p.id, x: originX ?? p.x, y: originY ?? p.y, aim: aim));
  }

  void _stepProjectiles() {
    if (_state.projectiles.isEmpty) return;

    // Stable sort by id
    _state.projectiles.sort((a, b) => a.id.compareTo(b.id));

    final aliveProjectiles = <ProjectileState>[];

    for (final pr in _state.projectiles) {
      if (pr.kind == ProjectileKind.grenade) {
        pr.lifetime -= 1;
        pr.fuseTicks -= 1;
        if (pr.fuseTicks <= 0 || pr.lifetime <= 0) {
          _explodeGrenade(pr);
          continue;
        }
        _stepGrenade(pr);
        aliveProjectiles.add(pr);
        continue;
      }

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
          events.add(ProjectileHitEvent(
              x: pr.x, y: pr.y, hitPlayerId: null, damage: 0));
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

  void _stepGrenade(ProjectileState grenade) {
    grenade.vy += config.gravity * 0.65;
    final nextX = grenade.x + grenade.vx;
    if (map.isSolid(nextX.floor(), grenade.y.floor())) {
      grenade.vx = -grenade.vx * 0.58;
    } else {
      grenade.x = nextX;
    }

    final nextY = grenade.y + grenade.vy;
    if (map.isSolid(grenade.x.floor(), nextY.floor())) {
      grenade.vy = -grenade.vy * 0.42;
      grenade.vx *= 0.82;
    } else {
      grenade.y = nextY;
    }
    if (grenade.vx.abs() < 0.004) grenade.vx = 0;
    if (grenade.vy.abs() < 0.004 &&
        map.isSolid(grenade.x.floor(), (grenade.y + 0.03).floor())) {
      grenade.vy = 0;
    }
  }

  void _explodeGrenade(ProjectileState grenade) {
    final radiusSq = grenade.blastRadius * grenade.blastRadius;
    for (final target in _state.players) {
      if (!target.alive || target.shieldTicks > 0) continue;
      final dx = target.x - grenade.x;
      final dy = target.y - grenade.y;
      final distanceSq = dx * dx + dy * dy;
      if (distanceSq > radiusSq) continue;
      final scale = 1 - distanceSq / radiusSq;
      final damage = (grenade.damage * scale).round();
      if (damage <= 0) continue;
      final direction = Trig.direction(
          Trig.angleBetween(grenade.x, grenade.y, target.x, target.y));
      target.knockbackX += direction.x * (0.12 + scale * 0.2);
      target.vy += direction.y * (0.12 + scale * 0.2) - scale * 0.1;
      _applyDamage(target, damage, grenade.shooterId);
      events.add(ProjectileHitEvent(
          x: target.x, y: target.y, hitPlayerId: target.id, damage: damage));
    }
    events.add(GrenadeExplodedEvent(
        x: grenade.x, y: grenade.y, radius: grenade.blastRadius));
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

      _applyDamage(p, pr.damage, pr.shooterId);
      events.add(ProjectileHitEvent(
          x: pr.x, y: pr.y, hitPlayerId: p.id, damage: pr.damage));
      return true;
    }
    return false;
  }

  void _applyDamage(PlayerState target, int damage, int sourceId) {
    if (target.shieldTicks > 0) return;
    var remaining = damage;
    if (target.shield > 0) {
      final absorbed = target.shield < remaining ? target.shield : remaining;
      target.shield -= absorbed;
      remaining -= absorbed;
    }
    target.health -= remaining;
    if (target.health > 0) return;
    target.health = 0;
    target.alive = false;
    target.shieldTicks = 0;
    target.deaths += 1;
    target.respawnTimer = 180;
    final attacker = _state.playerById(sourceId);
    if (attacker != null && attacker.id != target.id) attacker.kills += 1;
    events.add(PlayerDiedEvent(
        victimId: target.id, killerId: sourceId, x: target.x, y: target.y));
  }

  void _collectPickups(Map<int, InputCommand> previous) {
    for (final p in _state.players) {
      if (!p.alive) continue;
      _releaseIgnoredPickup(p);
      _handleDrop(p, previous[p.id] ?? InputCommand.neutral);
      for (final g in _state.pickups) {
        if (!g.onGround || g.id == p.ignorePickupId) continue;
        if (!_overlapsPickup(p, g)) continue;
        switch (g.kind) {
          case PickupKind.weapon:
            if (g.weaponIndex < 0 || g.weaponIndex >= weapons.length) {
              continue;
            }
            final matchingSlot = p.loadout.indexOf(g.weaponIndex);
            if (matchingSlot >= 0) {
              final weapon = weapons[g.weaponIndex];
              final room = weapon.magazineSize - p.magAmmo[matchingSlot];
              final added = g.ammo < room ? g.ammo : room;
              if (added <= 0) continue;
              p.magAmmo[matchingSlot] += added;
              if (matchingSlot == p.activeSlot) p.reloadCooldown = 0;
              g.respawnTicks = gunRespawnTicks;
              events.add(AmmoPickedUpEvent(
                playerId: p.id,
                weaponIndex: g.weaponIndex,
                roundsAdded: added,
                x: g.x,
                y: g.y,
              ));
              break;
            }
            if (!p.hasEmptySlot) continue;
            _takeGun(p, g);
          case PickupKind.grenade:
            if (p.grenades >= PlayerState.maxGrenades) continue;
            p.grenades += 1;
            g.respawnTicks = supplyRespawnTicks;
            events.add(UtilityPickedUpEvent(
                playerId: p.id, kind: g.kind, x: g.x, y: g.y));
          case PickupKind.shield:
            if (p.shield >= PlayerState.maxShield) continue;
            p.shield += 45;
            if (p.shield > PlayerState.maxShield)
              p.shield = PlayerState.maxShield;
            g.respawnTicks = supplyRespawnTicks;
            events.add(UtilityPickedUpEvent(
                playerId: p.id, kind: g.kind, x: g.x, y: g.y));
        }
        break;
      }
    }
  }

  void _releaseIgnoredPickup(PlayerState p) {
    if (p.ignorePickupId == 0) return;
    PickupState? ignored;
    for (final g in _state.pickups) {
      if (g.id == p.ignorePickupId) {
        ignored = g;
        break;
      }
    }
    if (ignored == null || !ignored.onGround || !_overlapsPickup(p, ignored)) {
      p.ignorePickupId = 0;
    }
  }

  void _handleDrop(PlayerState p, InputCommand prev) {
    final c = p.input;
    final pressed = (c.buttons & InputCommand.btnDrop) != 0 &&
        (prev.buttons & InputCommand.btnDrop) == 0;
    if (!pressed || !p.occupies(p.activeSlot)) return;

    if (!p.hasEmptySlot) {
      for (final g in _state.pickups) {
        if (!g.onGround || !_overlapsPickup(p, g)) continue;
        _swapWithGround(p, g);
        return;
      }
    }

    final slot = p.activeSlot;
    final dropped = PickupState(
      id: _state.nextPickupId++,
      x: p.x,
      y: p.y,
      weaponIndex: p.loadout[slot],
      ammo: p.magAmmo[slot],
    );
    _state.pickups.add(dropped);
    p.loadout[slot] = PlayerState.emptyWeapon;
    p.magAmmo[slot] = 0;
    p.reloadCooldown = 0;
    p.ignorePickupId = dropped.id;
    final other = slot == 0 ? 1 : 0;
    if (p.occupies(other)) p.activeSlot = other;
  }

  void _swapWithGround(PlayerState p, PickupState g) {
    final slot = p.activeSlot;
    final oldWeapon = p.loadout[slot];
    final oldAmmo = p.magAmmo[slot];
    if (g.weaponIndex < 0 || g.weaponIndex >= weapons.length) return;
    p.loadout[slot] = g.weaponIndex;
    p.magAmmo[slot] = g.ammo;
    g.weaponIndex = oldWeapon;
    g.ammo = oldAmmo;
    p.reloadCooldown = 0;
    p.fireCooldown = 0;
    events.add(GunPickedUpEvent(
        playerId: p.id, weaponIndex: p.loadout[slot], x: g.x, y: g.y));
  }

  void _takeGun(PlayerState p, PickupState g) {
    final index = g.weaponIndex;
    if (index < 0 || index >= weapons.length) return;
    var slot = -1;
    for (var i = 0; i < PlayerState.slotCount; i++) {
      if (!p.occupies(i)) {
        slot = i;
        break;
      }
    }
    if (slot < 0) return;
    p.loadout[slot] = index;
    p.magAmmo[slot] = g.ammo;
    p.activeSlot = slot;
    p.reloadCooldown = 0;
    p.fireCooldown = 0;
    g.respawnTicks = gunRespawnTicks;
    events.add(
        GunPickedUpEvent(playerId: p.id, weaponIndex: index, x: g.x, y: g.y));
  }

  bool _overlapsPickup(PlayerState p, PickupState g) {
    final dx = p.x - g.x;
    final dy = p.y - g.y;
    final ax = dx < 0 ? -dx : dx;
    final ay = dy < 0 ? -dy : dy;
    if (ax > config.halfWidth + 0.45) return false;
    if (ay > config.halfHeight + 0.45) return false;
    return true;
  }

  void _tickPickups() {
    for (final g in _state.pickups) {
      if (g.respawnTicks <= 0) continue;
      g.respawnTicks -= 1;
      if (g.respawnTicks == 0) {
        _relocateGun(g);
      }
    }
  }

  /// Returns false when the map has no free grounded tile left.
  bool _placeGun() {
    final spots = _groundSpots(excludeId: null);
    if (spots.isEmpty) return false;
    final spot = spots[_state.rng.nextInt(spots.length)];
    final weaponIndex = _state.rng.nextInt(weapons.length);
    _state.pickups.add(
      PickupState(
        id: _state.nextPickupId++,
        x: spot.$1,
        y: spot.$2,
        kind: PickupKind.weapon,
        weaponIndex: weaponIndex,
        ammo: weapons[weaponIndex].magazineSize,
      ),
    );
    return true;
  }

  bool _placePickup(PickupKind kind) {
    final spots = _groundSpots(excludeId: null);
    if (spots.isEmpty) return false;
    final spot = spots[_state.rng.nextInt(spots.length)];
    _state.pickups.add(
      PickupState(
        id: _state.nextPickupId++,
        x: spot.$1,
        y: spot.$2,
        kind: kind,
      ),
    );
    return true;
  }

  void _relocateGun(PickupState g) {
    final spots = _groundSpots(excludeId: g.id);
    if (spots.isEmpty) {
      g.respawnTicks = 30;
      return;
    }
    final spot = spots[_state.rng.nextInt(spots.length)];
    g.x = spot.$1;
    g.y = spot.$2;
    if (g.kind == PickupKind.weapon) {
      g.weaponIndex = _state.rng.nextInt(weapons.length);
      g.ammo = weapons[g.weaponIndex].magazineSize;
    }
  }

  void _applyStartingLoadout(PlayerState p) {
    final index = _startingWeaponIndex();
    p.loadout[0] = index;
    p.loadout[1] = PlayerState.emptyWeapon;
    p.magAmmo[0] = weapons[index].magazineSize;
    p.magAmmo[1] = 0;
    p.activeSlot = 0;
    p.ignorePickupId = 0;
  }

  int _startingWeaponIndex() {
    for (var i = 0; i < weapons.length; i++) {
      if (weapons[i].id == pistolWeaponId) return i;
    }
    for (var i = 0; i < weapons.length; i++) {
      if (weapons[i].name == 'Pistol') return i;
    }
    return 0;
  }

  /// Grounded empty tiles, row-major, that are not on top of a player, a
  /// spawn, or another gun that is currently showing.
  List<(double, double)> _groundSpots({required int? excludeId}) {
    final spots = <(double, double)>[];
    for (var ty = 0; ty < map.height; ty++) {
      for (var tx = 0; tx < map.width; tx++) {
        if (map.isSolid(tx, ty) || !map.isSolid(tx, ty + 1)) continue;
        final x = tx + 0.5;
        final y = ty + 1.0 - 0.35;
        if (_spotBlocked(x, y, excludeId)) continue;
        spots.add((x, y));
      }
    }
    return spots;
  }

  bool _spotBlocked(double x, double y, int? excludeId) {
    if (_near(x, y, _state.players.map((p) => (p.x, p.y)), 2.25)) return true;
    for (final s in map.spawnPoints) {
      final dx = s.x - x;
      final dy = s.y - y;
      if (dx * dx + dy * dy < 2.25) return true;
    }
    for (final g in _state.pickups) {
      if (!g.onGround || g.id == excludeId) continue;
      final dx = g.x - x;
      final dy = g.y - y;
      if (dx * dx + dy * dy < 4) return true;
    }
    return false;
  }

  bool _near(
      double x, double y, Iterable<(double, double)> points, double radiusSq) {
    for (final point in points) {
      final dx = point.$1 - x;
      final dy = point.$2 - y;
      if (dx * dx + dy * dy < radiusSq) return true;
    }
    return false;
  }

  static int _clampStick(int v) => v < -127 ? -127 : (v > 127 ? 127 : v);

  void _movePlayer(PlayerState p) {
    final c = p.input;

    // Horizontal: stick maps directly to velocity
    p.vx = (_clampStick(c.moveX) / 127.0) * config.runSpeed + p.knockbackX;

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
    p.knockbackX *= 0.82;
    if (p.knockbackX > -0.003 && p.knockbackX < 0.003) p.knockbackX = 0;
    p.grounded = false;
    p.y += p.vy;
    _resolveY(p);
  }

  void _resolveX(PlayerState p) {
    final hw = config.halfWidth;
    final hh = config.halfHeight;
    final tx0 = (p.x - hw + _eps).floor();
    final tx1 = (p.x + hw - _eps).floor();
    final ty0 = (p.y - hh + _eps).floor();
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
    final tx0 = (p.x - hw + _eps).floor();
    final tx1 = (p.x + hw - _eps).floor();
    final ty0 = (p.y - hh + _eps).floor();
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
