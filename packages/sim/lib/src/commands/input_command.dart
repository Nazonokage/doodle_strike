/// One player's input for one tick. All fields are quantized integers so they
/// serialize small and behave identically on every platform.
class InputCommand {
  const InputCommand({
    required this.tick,
    this.moveX = 0,
    this.moveY = 0,
    this.aim = 0,
    this.buttons = 0,
    this.weaponId = 0,
  });

  /// Tick this input is meant for.
  final int tick;

  /// Left stick X, -127..127 (clamped by the sim).
  final int moveX;

  /// Left stick Y, -127..127. Negative is up (screen coordinates).
  final int moveY;

  /// Aim angle, 0..65535 = 0..360 degrees.
  final int aim;

  /// Bitmask of the `btn*` constants below.
  final int buttons;

  /// Carried slot to select, 1 or 2. 0 means keep the current slot.
  final int weaponId;

  static const int btnFire = 1;
  static const int btnJet = 2;
  static const int btnMelee = 4;
  static const int btnSwap = 8;
  static const int btnReload = 16;
  static const int btnDrop = 32;
  static const int btnGrenade = 64;

  /// Stick pushed this far up (out of 127) also fires the jetpack.
  static const int jetStickThreshold = 40;

  bool get firing => (buttons & btnFire) != 0;

  bool get wantsJet => (buttons & btnJet) != 0 || moveY < -jetStickThreshold;

  /// Input with everything released.
  static const InputCommand neutral = InputCommand(tick: 0);

  InputCommand withTick(int newTick) => InputCommand(
        tick: newTick,
        moveX: moveX,
        moveY: moveY,
        aim: aim,
        buttons: buttons,
        weaponId: weaponId,
      );

  @override
  bool operator ==(Object other) =>
      other is InputCommand &&
      other.tick == tick &&
      other.moveX == moveX &&
      other.moveY == moveY &&
      other.aim == aim &&
      other.buttons == buttons &&
      other.weaponId == weaponId;

  @override
  int get hashCode => Object.hash(tick, moveX, moveY, aim, buttons, weaponId);

  @override
  String toString() =>
      'InputCommand(tick: $tick, moveX: $moveX, moveY: $moveY, aim: $aim, '
      'buttons: $buttons, weaponId: $weaponId)';
}
