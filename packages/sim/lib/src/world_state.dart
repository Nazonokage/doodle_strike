import 'commands/input_command.dart';
import 'entities/projectile_state.dart';
import 'math/rng.dart';

/// One player's full simulation state. Mutable on purpose: the simulation
/// steps it in place. Always copy before keeping a reference across ticks.
class PlayerState {
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
    int ammo = 30,
    List<int>? magAmmo,
    this.weaponIndex = 0,
    this.shieldTicks = 0,
    this.fireCooldown = 0,
    this.reloadCooldown = 0,
    this.respawnTimer = 0,
    this.kills = 0,
    this.deaths = 0,
  }) : magAmmo = magAmmo ?? <int>[ammo];

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

  /// Rounds left in each weapon's magazine, indexed like the sim weapon list.
  final List<int> magAmmo;

  /// Index into the sim weapon list.
  int weaponIndex;

  /// Ticks of spawn protection remaining. Hits are ignored while this is > 0.
  int shieldTicks;

  /// Rounds in the active magazine.
  int get ammo => magAmmo[weaponIndex];

  set ammo(int value) => magAmmo[weaponIndex] = value;

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
        magAmmo: List<int>.from(magAmmo),
        weaponIndex: weaponIndex,
        shieldTicks: shieldTicks,
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
        nextProjectileId = 1,
        rng = Rng(seed);

  WorldState._(
    this.tick,
    this.players,
    this.projectiles,
    this.nextProjectileId,
    this.rng,
  );

  /// Rebuild a state from a snapshot. Lists are copied and sorted by id.
  factory WorldState.assemble({
    required int tick,
    required List<PlayerState> players,
    required List<ProjectileState> projectiles,
    required int nextProjectileId,
    required int rngState,
  }) {
    final sortedPlayers = List<PlayerState>.from(players)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedShots = List<ProjectileState>.from(projectiles)
      ..sort((a, b) => a.id.compareTo(b.id));
    return WorldState._(
      tick,
      sortedPlayers,
      sortedShots,
      nextProjectileId,
      Rng.fromState(rngState),
    );
  }

  int tick;

  /// Always sorted by ascending id. Iteration order must never depend on
  /// anything else.
  final List<PlayerState> players;

  /// Active projectiles stepped by the sim, sorted by ascending id.
  final List<ProjectileState> projectiles;

  int nextProjectileId;

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
        nextProjectileId,
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
      h = _mix(h, p.weaponIndex);
      h = _mix(h, p.shieldTicks);
      h = _mix(h, p.magAmmo.length);
      for (final rounds in p.magAmmo) {
        h = _mix(h, rounds);
      }
      h = _mix(h, p.fireCooldown);
      h = _mix(h, p.reloadCooldown);
      h = _mix(h, p.respawnTimer);
      h = _mix(h, p.kills);
      h = _mix(h, p.deaths);
      h = _mix(h, p.input.tick);
      h = _mix(h, p.input.moveX);
      h = _mix(h, p.input.moveY);
      h = _mix(h, p.input.aim);
      h = _mix(h, p.input.buttons);
      h = _mix(h, p.input.weaponId);
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
    }
    return h;
  }
}
