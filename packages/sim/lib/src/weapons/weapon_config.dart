/// Weapon definition and tuning constants. All times are in ticks.
class WeaponConfig {
  const WeaponConfig({
    this.id = 1,
    this.name = 'Assault Rifle',
    this.damage = 22,
    this.fireIntervalTicks = 8, // ~7.5 shots/sec at 60 Hz
    this.projectileSpeed = 0.65, // ~39 tiles/sec
    this.projectileLifetimeTicks = 60, // 1 second
    this.magazineSize = 30,
    this.reloadTicks = 75, // 1.25 seconds
    this.projectileRadius = 0.15,
    this.automatic = true,
    this.spreadUnits = 0,
    this.pellets = 1,
  });

  final int id;
  final String name;
  final int damage;
  final int fireIntervalTicks;
  final double projectileSpeed;
  final int projectileLifetimeTicks;
  final int magazineSize;
  final int reloadTicks;
  final double projectileRadius;

  /// Held fire keeps shooting. Semi-auto weapons fire on the press only.
  final bool automatic;

  /// Random aim offset, in 16-bit angle units, applied per pellet.
  final int spreadUnits;

  /// Projectiles spawned by one trigger pull.
  final int pellets;
}
