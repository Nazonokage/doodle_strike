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
