import 'dart:typed_data';

import 'package:sim/sim.dart';

import 'codec.dart';
import 'messages.dart';

/// Authoritative world at one tick, plus the newest input tick the host has
/// applied for each player. Clients reconcile against [lastInputTick].
class WorldSnapshot {
  const WorldSnapshot({
    required this.header,
    required this.state,
    required this.lastInputTick,
  });

  final PacketHeader header;
  final WorldState state;

  /// Player id to the input tick the host consumed for them.
  final Map<int, int> lastInputTick;
}

Uint8List encodeSnapshot(WorldSnapshot snap) {
  final ackKeys = snap.lastInputTick.keys.toList()..sort();
  return encodeJsonMap(<String, Object?>{
    'k': 'snap',
    'h': snap.header.toJson(),
    'ack': <String, Object?>{
      for (final id in ackKeys) '$id': snap.lastInputTick[id],
    },
    'rng': snap.state.rng.state,
    'np': snap.state.nextProjectileId,
    'ng': snap.state.nextPickupId,
    'pl': <Object?>[for (final p in snap.state.players) _playerToJson(p)],
    'pr': <Object?>[for (final pr in snap.state.projectiles) _shotToJson(pr)],
    'gp': <Object?>[for (final g in snap.state.pickups) _pickupToJson(g)],
    't': snap.state.tick,
  });
}

WorldSnapshot decodeSnapshot(Uint8List data) {
  final map = decodeJsonMap(data);
  if (packetKind(map) != 'snap') {
    throw const FormatException('expected a snapshot');
  }
  final header = headerFromMap(map);
  final ackRaw = map['ack']! as Map<String, Object?>;
  final players = <PlayerState>[
    for (final entry in map['pl']! as List<Object?>)
      _playerFromJson(entry! as List<Object?>),
  ];
  final shots = <ProjectileState>[
    for (final entry in map['pr']! as List<Object?>)
      _shotFromJson(entry! as List<Object?>),
  ];
  final pickups = <PickupState>[
    for (final entry in map['gp']! as List<Object?>)
      _pickupFromJson(entry! as List<Object?>),
  ];
  return WorldSnapshot(
    header: header,
    lastInputTick: <int, int>{
      for (final entry in ackRaw.entries)
        int.parse(entry.key): entry.value! as int,
    },
    state: WorldState.assemble(
      tick: map['t']! as int,
      players: players,
      projectiles: shots,
      nextProjectileId: map['np']! as int,
      rngState: map['rng']! as int,
      pickups: pickups,
      nextPickupId: map['ng']! as int,
    ),
  );
}

/// Positional so a full six-player snapshot stays under 1.5 KB.
/// id, x, y, vx, vy, fuel, health, alive, grounded, active slot, shield,
/// slot ammo, fire cooldown, reload, respawn, kills, deaths, input,
/// loadout, ignored pickup id, shield energy, grenades, melee cooldown,
/// horizontal knockback.
List<Object?> _playerToJson(PlayerState p) => <Object?>[
      p.id,
      p.x,
      p.y,
      p.vx,
      p.vy,
      p.fuel,
      p.health,
      p.alive,
      p.grounded,
      p.activeSlot,
      p.shieldTicks,
      p.magAmmo,
      p.fireCooldown,
      p.reloadCooldown,
      p.respawnTimer,
      p.kills,
      p.deaths,
      inputToJson(p.input),
      p.loadout,
      p.ignorePickupId,
      p.shield,
      p.grenades,
      p.meleeCooldown,
      p.knockbackX,
    ];

PlayerState _playerFromJson(List<Object?> j) => PlayerState(
      id: j[0]! as int,
      x: _asDouble(j[1]),
      y: _asDouble(j[2]),
      vx: _asDouble(j[3]),
      vy: _asDouble(j[4]),
      fuel: j[5]! as int,
      health: j[6]! as int,
      alive: j[7]! as bool,
      grounded: j[8]! as bool,
      activeSlot: j[9]! as int,
      shieldTicks: j[10]! as int,
      magAmmo: <int>[for (final n in j[11]! as List<Object?>) n! as int],
      fireCooldown: j[12]! as int,
      reloadCooldown: j[13]! as int,
      respawnTimer: j[14]! as int,
      kills: j[15]! as int,
      deaths: j[16]! as int,
      input: inputFromJson(j[17]),
      loadout: <int>[for (final n in j[18]! as List<Object?>) n! as int],
      ignorePickupId: j[19]! as int,
      shield: j[20]! as int,
      grenades: j[21]! as int,
      meleeCooldown: j[22]! as int,
      knockbackX: _asDouble(j[23]),
    );

/// id, x, y, weapon index, respawn ticks, ammo.
List<Object?> _pickupToJson(PickupState g) => <Object?>[
      g.id,
      g.x,
      g.y,
      g.weaponIndex,
      g.respawnTicks,
      g.ammo,
      g.kind.index,
    ];

PickupState _pickupFromJson(List<Object?> j) => PickupState(
      id: j[0]! as int,
      x: _asDouble(j[1]),
      y: _asDouble(j[2]),
      weaponIndex: j[3]! as int,
      respawnTicks: j[4]! as int,
      ammo: j[5]! as int,
      kind: PickupKind.values[j[6]! as int],
    );

/// id, shooter, x, y, vx, vy, damage, lifetime, radius.
List<Object?> _shotToJson(ProjectileState pr) => <Object?>[
      pr.id,
      pr.shooterId,
      pr.x,
      pr.y,
      pr.vx,
      pr.vy,
      pr.damage,
      pr.lifetime,
      pr.radius,
      pr.kind.index,
      pr.fuseTicks,
      pr.blastRadius,
    ];

ProjectileState _shotFromJson(List<Object?> j) => ProjectileState(
      id: j[0]! as int,
      shooterId: j[1]! as int,
      x: _asDouble(j[2]),
      y: _asDouble(j[3]),
      vx: _asDouble(j[4]),
      vy: _asDouble(j[5]),
      damage: j[6]! as int,
      lifetime: j[7]! as int,
      radius: _asDouble(j[8]),
      kind: ProjectileKind.values[j[9]! as int],
      fuseTicks: j[10]! as int,
      blastRadius: _asDouble(j[11]),
    );

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  throw const FormatException('expected a number');
}
