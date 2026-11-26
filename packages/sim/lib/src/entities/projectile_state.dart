enum ProjectileKind { bullet, grenade }

/// One projectile stepped deterministically by the simulation.
class ProjectileState {
  ProjectileState({
    required this.id,
    required this.shooterId,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    required this.lifetime,
    required this.radius,
    this.kind = ProjectileKind.bullet,
    this.fuseTicks = 0,
    this.blastRadius = 0,
  });

  final int id;
  final int shooterId;
  double x;
  double y;
  double vx;
  double vy;
  int damage;
  int lifetime;
  double radius;
  final ProjectileKind kind;
  int fuseTicks;
  final double blastRadius;

  ProjectileState copy() => ProjectileState(
        id: id,
        shooterId: shooterId,
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        damage: damage,
        lifetime: lifetime,
        radius: radius,
        kind: kind,
        fuseTicks: fuseTicks,
        blastRadius: blastRadius,
      );
}
