import '../entities/pickup_state.dart';

/// Pure sim events emitted during a step so views can trigger cosmetic
/// feedback (audio, particles, muzzle flash, damage indicators).
///
/// Views read these from Simulation.events after each step.
sealed class SimEvent {
  const SimEvent();
}

class ShotFiredEvent extends SimEvent {
  const ShotFiredEvent({
    required this.shooterId,
    required this.x,
    required this.y,
    required this.aim,
  });

  final int shooterId;
  final double x;
  final double y;
  final int aim;
}

class ProjectileHitEvent extends SimEvent {
  const ProjectileHitEvent({
    required this.x,
    required this.y,
    required this.hitPlayerId,
    this.damage = 0,
  });

  final double x;
  final double y;
  final int? hitPlayerId;
  final int damage;
}

class PlayerDiedEvent extends SimEvent {
  const PlayerDiedEvent({
    required this.victimId,
    required this.killerId,
    required this.x,
    required this.y,
  });

  final int victimId;
  final int killerId;
  final double x;
  final double y;
}

class GunPickedUpEvent extends SimEvent {
  const GunPickedUpEvent({
    required this.playerId,
    required this.weaponIndex,
    required this.x,
    required this.y,
  });

  final int playerId;
  final int weaponIndex;
  final double x;
  final double y;
}

class AmmoPickedUpEvent extends SimEvent {
  const AmmoPickedUpEvent({
    required this.playerId,
    required this.weaponIndex,
    required this.roundsAdded,
    required this.x,
    required this.y,
  });

  final int playerId;
  final int weaponIndex;
  final int roundsAdded;
  final double x;
  final double y;
}

class UtilityPickedUpEvent extends SimEvent {
  const UtilityPickedUpEvent(
      {required this.playerId,
      required this.kind,
      required this.x,
      required this.y});

  final int playerId;
  final PickupKind kind;
  final double x;
  final double y;
}

class MeleeHitEvent extends SimEvent {
  const MeleeHitEvent(
      {required this.playerId,
      required this.targetId,
      required this.x,
      required this.y,
      required this.damage});

  final int playerId;
  final int targetId;
  final double x;
  final double y;
  final int damage;
}

class GrenadeExplodedEvent extends SimEvent {
  const GrenadeExplodedEvent(
      {required this.x, required this.y, required this.radius});

  final double x;
  final double y;
  final double radius;
}

class PlayerRespawnedEvent extends SimEvent {
  const PlayerRespawnedEvent({
    required this.playerId,
    required this.x,
    required this.y,
  });

  final int playerId;
  final double x;
  final double y;
}
