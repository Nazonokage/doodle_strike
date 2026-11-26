import 'commands/input_command.dart';
import 'entities/pickup_state.dart';
import 'entities/projectile_state.dart';
import 'math/rng.dart';

/// One player's full simulation state. Mutable on purpose: the simulation
/// steps it in place. Always copy before keeping a reference across ticks.
class PlayerState {
  /// Carried guns. Slot 0 is the first slot the player spawns with.
  static const int slotCount = 2;

  /// [loadout] entry that means the slot has no weapon.
  static const int emptyWeapon = -1;
  static const int maxGrenades = 3;
  static const int maxShield = 100;

  PlayerState({
    required this.id,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.fuel = 0,
    this.health = 100,
    this.alive = true,
    this.grounded = false,
    this.input = InputCommand.neutral,
    List<int>? loadout,
    List<int>? magAmmo,
    this.activeSlot = 0,
    this.shieldTicks = 0,
    this.fireCooldown = 0,
    this.reloadCooldown = 0,
    this.respawnTimer = 0,
    this.kills = 0,
    this.deaths = 0,
    this.ignorePickupId = 0,
    this.grenades = 1,
    this.shield = 0,
    this.meleeCooldown = 0,
    this.knockbackX = 0,
  })  : loadout = _fixedSlots(loadout, emptyWeapon),
        magAmmo = _fixedSlots(magAmmo, 0);

  final int id;

  /// Center of the player's box, in tiles.
  double x;
  double y;
  double vx;
  double vy;
  int fuel;
  int health;
  bool alive;
  bool grounded;

  /// Last known input. Reused on ticks where no new input arrives.
  InputCommand input;

  /// Catalog index in each carried slot. [emptyWeapon] means the slot is empty.
  /// Always length [slotCount].
  final List<int> loadout;

  /// Rounds left in each carried slot, parallel to [loadout].
  final List<int> magAmmo;

  /// Which carried slot is in the player's hands. 0 or 1.
  int activeSlot;

  /// Ticks of spawn protection remaining. Hits are ignored while this is > 0.
  int shieldTicks;

  /// Pickup id this player will not auto-collect until they walk off it.
  /// 0 means none. Stops a dropped gun from jumping straight back into the hand.
  int ignorePickupId;

  /// Carried thrown grenades. Shield energy is separate from spawn immunity.
  int grenades;
  int shield;
  int meleeCooldown;
  double knockbackX;

  /// Catalog index of the gun in hand, or [emptyWeapon].
  int get weaponIndex {
    if (activeSlot < 0 || activeSlot >= loadout.length) return emptyWeapon;
    return loadout[activeSlot];
  }

  bool occupies(int slot) =>
      slot >= 0 && slot < loadout.length && loadout[slot] != emptyWeapon;

  bool get hasEmptySlot {
    for (final weapon in loadout) {
      if (weapon == emptyWeapon) return true;
    }
    return false;
  }

  /// Rounds in the active magazine. Zero when the active slot is empty.
  int get ammo => occupies(activeSlot) ? magAmmo[activeSlot] : 0;

  set ammo(int value) {
    if (activeSlot >= 0 && activeSlot < magAmmo.length) {
      magAmmo[activeSlot] = value;
    }
  }

  static List<int> _fixedSlots(List<int>? values, int fill) {
    final list = List<int>.filled(slotCount, fill);
    if (values == null) return list;
    final n = values.length < slotCount ? values.length : slotCount;
    for (var i = 0; i < n; i++) {
      list[i] = values[i];
    }
    return list;
  }

  /// Ticks until next shot can be fired.
  int fireCooldown;

  /// Ticks remaining in active reload.
  int reloadCooldown;

  /// Ticks remaining before respawn if [alive] is false.
  int respawnTimer;

  int kills;
  int deaths;

  PlayerState copy() => PlayerState(
        id: id,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        fuel: fuel,
        health: health,
        alive: alive,
        grounded: grounded,
        input: input,
        loadout: List<int>.from(loadout),
        magAmmo: List<int>.from(magAmmo),
        activeSlot: activeSlot,
        shieldTicks: shieldTicks,
        ignorePickupId: ignorePickupId,
        grenades: grenades,
        shield: shield,
        meleeCooldown: meleeCooldown,
        knockbackX: knockbackX,
        fireCooldown: fireCooldown,
        reloadCooldown: reloadCooldown,
        respawnTimer: respawnTimer,
        kills: kills,
        deaths: deaths,
      );
}

/// Everything that influences future ticks. If a field is missing here, or
/// from copy() or hash(), prediction replays will silently diverge.
class WorldState {
  WorldState({required int seed})
      : tick = 0,
        players = <PlayerState>[],
        projectiles = <ProjectileState>[],
        pickups = <PickupState>[],
        nextProjectileId = 1,
        nextPickupId = 1,
        rng = Rng(seed);

  WorldState._(
    this.tick,
    this.players,
    this.projectiles,
    this.pickups,
    this.nextProjectileId,
    this.nextPickupId,
    this.rng,
  );

  /// Rebuild a state from a snapshot. Lists are copied and sorted by id.
  factory WorldState.assemble({
    required int tick,
    required List<PlayerState> players,
    required List<ProjectileState> projectiles,
    required int nextProjectileId,
    required int rngState,
    List<PickupState> pickups = const <PickupState>[],
    int nextPickupId = 1,
  }) {
    final sortedPlayers = List<PlayerState>.from(players)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedShots = List<ProjectileState>.from(projectiles)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedPickups = List<PickupState>.from(pickups)
      ..sort((a, b) => a.id.compareTo(b.id));
    return WorldState._(
      tick,
      sortedPlayers,
      sortedShots,
      sortedPickups,
      nextProjectileId,
      nextPickupId,
      Rng.fromState(rngState),
    );
  }

  int tick;

  /// Always sorted by ascending id. Iteration order must never depend on
  /// anything else.
  final List<PlayerState> players;

  /// Active projectiles stepped by the sim, sorted by ascending id.
  final List<ProjectileState> projectiles;

  /// Gun pickups, sorted by ascending id. Hidden ones still occupy a slot.
  final List<PickupState> pickups;

  int nextProjectileId;
  int nextPickupId;

  final Rng rng;

  PlayerState? playerById(int id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  WorldState copy() => WorldState._(
        tick,
        <PlayerState>[for (final p in players) p.copy()],
        <ProjectileState>[for (final pr in projectiles) pr.copy()],
        <PickupState>[for (final g in pickups) g.copy()],
        nextProjectileId,
        nextPickupId,
        rng.copy(),
      );

  static const int _mask = 0xFFFFFFFF;

  static int _mix(int h, int v) => (h * 33 + (v & _mask)) & _mask;

  static int _q(double v) => (v * 100000).round();

  /// Stable 32-bit hash of the full state, folded in a fixed field order.
  /// Doubles are quantized so tiny representation noise cannot flip the hash.
  int hash() {
    var h = 5381;
    h = _mix(h, tick);
    h = _mix(h, rng.state);
    h = _mix(h, nextProjectileId);
    h = _mix(h, nextPickupId);
    h = _mix(h, players.length);
    for (final p in players) {
      h = _mix(h, p.id);
      h = _mix(h, _q(p.x));
      h = _mix(h, _q(p.y));
      h = _mix(h, _q(p.vx));
      h = _mix(h, _q(p.vy));
      h = _mix(h, p.fuel);
      h = _mix(h, p.health);
      h = _mix(h, p.alive ? 1 : 0);
      h = _mix(h, p.grounded ? 1 : 0);
      h = _mix(h, p.activeSlot);
      h = _mix(h, p.weaponIndex);
      h = _mix(h, p.shieldTicks);
      h = _mix(h, p.ignorePickupId);
      h = _mix(h, p.loadout.length);
      for (final weapon in p.loadout) {
        h = _mix(h, weapon);
      }
      h = _mix(h, p.magAmmo.length);
      for (final rounds in p.magAmmo) {
        h = _mix(h, rounds);
      }
      h = _mix(h, p.fireCooldown);
      h = _mix(h, p.reloadCooldown);
      h = _mix(h, p.respawnTimer);
      h = _mix(h, p.kills);
      h = _mix(h, p.deaths);
      if (p.grenades != 1 ||
          p.shield != 0 ||
          p.meleeCooldown != 0 ||
          p.knockbackX != 0) {
        // Fold the added combat state only when it departs from its defaults,
        // keeping older no-item replay goldens stable.
        h = _mix(h, p.grenades);
        h = _mix(h, p.shield);
        h = _mix(h, p.meleeCooldown);
        h = _mix(h, _q(p.knockbackX));
      }
      h = _mix(h, p.input.tick);
      h = _mix(h, p.input.moveX);
      h = _mix(h, p.input.moveY);
      h = _mix(h, p.input.aim);
      h = _mix(h, p.input.buttons);
      h = _mix(h, p.input.weaponId);
    }
    h = _mix(h, pickups.length);
    for (final g in pickups) {
      h = _mix(h, g.id);
      h = _mix(h, _q(g.x));
      h = _mix(h, _q(g.y));
      h = _mix(h, g.weaponIndex);
      h = _mix(h, g.ammo);
      h = _mix(h, g.respawnTicks);
      if (g.kind != PickupKind.weapon) h = _mix(h, g.kind.index);
    }
    h = _mix(h, projectiles.length);
    for (final pr in projectiles) {
      h = _mix(h, pr.id);
      h = _mix(h, pr.shooterId);
      h = _mix(h, _q(pr.x));
      h = _mix(h, _q(pr.y));
      h = _mix(h, _q(pr.vx));
      h = _mix(h, _q(pr.vy));
      h = _mix(h, pr.damage);
      h = _mix(h, pr.lifetime);
      h = _mix(h, _q(pr.radius));
      if (pr.kind == ProjectileKind.grenade) {
        h = _mix(h, pr.kind.index);
        h = _mix(h, pr.fuseTicks);
        h = _mix(h, _q(pr.blastRadius));
      }
    }
    return h;
  }
}
