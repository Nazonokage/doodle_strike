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
      );
}
