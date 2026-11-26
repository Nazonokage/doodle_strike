enum PickupKind { weapon, grenade, shield }

/// An item lying on the map. Mutable: the simulation steps respawn in place.
class PickupState {
  PickupState({
    required this.id,
    required this.x,
    required this.y,
    this.kind = PickupKind.weapon,
    this.weaponIndex = -1,
    this.ammo = 0,
    this.respawnTicks = 0,
  });

  final int id;

  /// Center of the pickup, in tiles.
  double x;
  double y;

  final PickupKind kind;

  /// Index into the sim weapon list.
  int weaponIndex;

  /// Rounds in the gun on the ground. A dropped gun keeps what was left.
  int ammo;

  /// 0 means the gun is on the ground. Above 0, it is waiting to reappear.
  int respawnTicks;

  bool get onGround => respawnTicks <= 0;

  PickupState copy() => PickupState(
        id: id,
        x: x,
        y: y,
        kind: kind,
        weaponIndex: weaponIndex,
        ammo: ammo,
        respawnTicks: respawnTicks,
      );
}
