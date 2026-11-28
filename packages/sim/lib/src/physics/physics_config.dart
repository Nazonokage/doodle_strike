/// All physics constants in one place. Units: tiles and ticks.
/// One tile is 1.0 unit. Velocities are units per tick, accelerations are
/// units per tick squared. Comments give the per-second equivalent at 60 Hz.
///
/// These values are a starting point for feel tuning in Phase 1. Changing any
/// of them changes every state hash.
class PhysicsConfig {
  const PhysicsConfig({
    this.gravity = 0.011111, // 40 u/s^2
    this.thrust = 0.019444, // 70 u/s^2 (net upward 30 u/s^2 while jetting)
    this.maxRise = 0.2, // 12 u/s
    this.maxFall = 0.416667, // 25 u/s
    this.runSpeed = 0.133333, // 8 u/s at full stick
    this.halfWidth = 0.4,
    this.halfHeight = 0.7,
    this.fuelMax = 180, // 3 s of continuous thrust
    this.fuelDrain = 1, // per tick while jetting
    this.fuelRecharge = 2, // per tick while grounded and not jetting
    this.healthMax = 100,
  });

  final double gravity;
  final double thrust;
  final double maxRise;
  final double maxFall;
  final double runSpeed;
  final double halfWidth;
  final double halfHeight;
  final int fuelMax;
  final int fuelDrain;
  final int fuelRecharge;
  final int healthMax;
}
