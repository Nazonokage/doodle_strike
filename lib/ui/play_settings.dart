/// Touch and feel options for a match. This never enters the simulation.
class PlaySettings {
  const PlaySettings({
    this.lockMoveStick = true,
    this.lockAimStick = true,
    this.moveSensitivity = 1,
    this.aimSensitivity = 1,
    this.stickDeadZone = 0.15,
    this.screenShake = true,
    this.randomGunCount = 5,
  });

  /// Fixed corner pad. Off, the stick appears under the finger on that half.
  final bool lockMoveStick;
  final bool lockAimStick;

  /// 1 is full run speed at the edge of the pad. Higher reaches it sooner.
  final double moveSensitivity;

  /// Higher means a shorter push aims and fires.
  final double aimSensitivity;

  /// Fraction of the pad that still counts as centered.
  final double stickDeadZone;

  final bool screenShake;

  /// Number of randomized weapon pickups placed before the match begins.
  final int randomGunCount;

  PlaySettings copyWith({
    bool? lockMoveStick,
    bool? lockAimStick,
    double? moveSensitivity,
    double? aimSensitivity,
    double? stickDeadZone,
    bool? screenShake,
    int? randomGunCount,
  }) {
    return PlaySettings(
      lockMoveStick: lockMoveStick ?? this.lockMoveStick,
      lockAimStick: lockAimStick ?? this.lockAimStick,
      moveSensitivity: moveSensitivity ?? this.moveSensitivity,
      aimSensitivity: aimSensitivity ?? this.aimSensitivity,
      stickDeadZone: stickDeadZone ?? this.stickDeadZone,
      screenShake: screenShake ?? this.screenShake,
      randomGunCount: randomGunCount ?? this.randomGunCount,
    );
  }
}
