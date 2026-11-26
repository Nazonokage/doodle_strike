import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:sim/sim.dart';

/// Captures user input across Keyboard, Mouse, and Virtual Joysticks
/// to construct quantized [InputCommand]s for the simulation.
class GameInput {
  GameInput() {
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  /// Flame's [GameWidget] focus marks key events handled, so a parent [Focus]
  /// never sees WASD. This handler sits under the widget tree and still does.
  bool _onHardwareKey(KeyEvent event) {
    handleKeyEvent(event);
    return false;
  }

  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
  }

  // Keyboard state
  bool keyLeft = false;
  bool keyRight = false;
  bool keyUp = false;
  bool keyDown = false;
  bool keyJet = false;
  bool keyFire = false;
  bool keyReload = false;
  bool keySwap = false;
  bool keyGrenade = false;

  /// Weapon id to apply for a single tick, then cleared. 0 means no change.
  int pendingWeaponId = 0;

  /// True after the mouse has actually aimed, so a phone does not snap aim
  /// back to the right when the stick is released.
  bool _mouseAimed = false;
  int _latchedAim = 0;
  bool touchAiming = false;

  // Mouse / Pointer state
  bool isPointerFiring = false;
  double aimAngleRad = 0.0; // Radians from player to cursor

  // Virtual Joysticks (Touch)
  double touchMoveX = 0.0; // -1.0 .. 1.0
  double touchMoveY = 0.0; // -1.0 .. 1.0
  double touchAimX = 0.0;
  double touchAimY = 0.0;
  bool touchFiring = false;
  bool touchReload = false;
  bool touchSwap = false;
  bool touchDrop = false;
  bool touchGrenade = false;

  /// Scales how far the move stick must travel before it reaches full speed.
  double moveSensitivity = 1;

  /// Sticks inside this fraction of the pad report as centered.
  double stickDeadZone = 0.12;

  void handleKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyA:
      case LogicalKeyboardKey.arrowLeft:
        keyLeft = isDown;
        break;
      case LogicalKeyboardKey.keyD:
      case LogicalKeyboardKey.arrowRight:
        keyRight = isDown;
        break;
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.arrowUp:
        keyUp = isDown;
        break;
      case LogicalKeyboardKey.keyS:
      case LogicalKeyboardKey.arrowDown:
        keyDown = isDown;
        break;
      case LogicalKeyboardKey.space:
        keyJet = isDown;
        break;
      case LogicalKeyboardKey.keyF:
      case LogicalKeyboardKey.keyJ:
        keyFire = isDown;
        break;
      case LogicalKeyboardKey.keyR:
        if (event is KeyDownEvent) keyReload = true;
        break;
      case LogicalKeyboardKey.keyQ:
        if (event is KeyDownEvent) keySwap = true;
        break;
      case LogicalKeyboardKey.keyG:
        if (event is KeyDownEvent) touchDrop = true;
        break;
      case LogicalKeyboardKey.keyE:
        if (event is KeyDownEvent) keyGrenade = true;
        break;
      case LogicalKeyboardKey.digit1:
        if (event is KeyDownEvent) pendingWeaponId = 1;
        break;
      case LogicalKeyboardKey.digit2:
        if (event is KeyDownEvent) pendingWeaponId = 2;
        break;
    }
  }

  /// Updates mouse aim based on player screen position and cursor screen position.
  void updateMouseAim(double playerScreenX, double playerScreenY,
      double cursorX, double cursorY) {
    final dx = cursorX - playerScreenX;
    final dy = cursorY - playerScreenY;
    aimAngleRad = math.atan2(dy, dx);
    _mouseAimed = true;
  }

  /// Builds the authoritative [InputCommand] for tick [tick].
  InputCommand sample(int tick) {
    _syncHeldKeys();

    // 1. Calculate Move X (-127 .. 127)
    var moveX = 0;
    if (keyLeft) moveX -= 127;
    if (keyRight) moveX += 127;
    final shapedMoveX = _shapeStick(touchMoveX);
    if (shapedMoveX.abs() > 0) {
      moveX = (shapedMoveX * 127).clamp(-127, 127).round();
    }

    // 2. Up input fires the jet. Down remains available as directional input.
    var moveY = 0;
    if (keyUp || keyJet) moveY -= 127;
    if (keyDown) moveY += 127;
    final shapedMoveY = _shapeStick(touchMoveY);
    if (shapedMoveY.abs() > 0) {
      moveY = (shapedMoveY * 127).clamp(-127, 127).round();
    }

    // 3. Aim angle in 16-bit units (0..65535, 0 = right, 16384 = down, 32768 = left, 49152 = up)
    int aim16;
    if (touchAiming) {
      final touchAngle = math.atan2(touchAimY, touchAimX);
      aim16 = _radTo16(touchAngle);
      _latchedAim = aim16;
    } else if (_mouseAimed) {
      aim16 = _radTo16(aimAngleRad);
      _latchedAim = aim16;
    } else {
      aim16 = _latchedAim;
    }

    // 4. Buttons
    var buttons = 0;
    if (keyJet || keyUp || moveY < -InputCommand.jetStickThreshold) {
      buttons |= InputCommand.btnJet;
    }
    if (keyFire || isPointerFiring || touchFiring) {
      buttons |= InputCommand.btnFire;
    }
    if (keyReload || touchReload) {
      buttons |= InputCommand.btnReload;
    }
    if (keySwap || touchSwap) {
      buttons |= InputCommand.btnSwap;
    }
    if (touchDrop) {
      buttons |= InputCommand.btnDrop;
    }
    if (keyGrenade || touchGrenade) {
      buttons |= InputCommand.btnGrenade;
    }

    final weaponId = pendingWeaponId;

    // Reset single-pulse keys so a held key still edges once per sample burst.
    if (keyReload) keyReload = false;
    if (touchReload) touchReload = false;
    if (keySwap) keySwap = false;
    if (touchSwap) touchSwap = false;
    if (touchDrop) touchDrop = false;
    if (keyGrenade) keyGrenade = false;
    if (touchGrenade) touchGrenade = false;
    pendingWeaponId = 0;

    return InputCommand(
      tick: tick,
      moveX: moveX,
      moveY: moveY,
      aim: aim16,
      buttons: buttons,
      weaponId: weaponId,
    );
  }

  /// Held movement comes from the live key set, so a missed key-up cannot stick.
  void _syncHeldKeys() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    keyLeft = keys.contains(LogicalKeyboardKey.keyA) ||
        keys.contains(LogicalKeyboardKey.arrowLeft);
    keyRight = keys.contains(LogicalKeyboardKey.keyD) ||
        keys.contains(LogicalKeyboardKey.arrowRight);
    keyUp = keys.contains(LogicalKeyboardKey.keyW) ||
        keys.contains(LogicalKeyboardKey.arrowUp);
    keyDown = keys.contains(LogicalKeyboardKey.keyS) ||
        keys.contains(LogicalKeyboardKey.arrowDown);
    keyJet = keys.contains(LogicalKeyboardKey.space);
    keyFire = keys.contains(LogicalKeyboardKey.keyF) ||
        keys.contains(LogicalKeyboardKey.keyJ);
  }

  double _shapeStick(double value) {
    final magnitude = value.abs();
    if (magnitude <= stickDeadZone) return 0;
    final span = 1 - stickDeadZone;
    var scaled = span <= 0 ? 1.0 : (magnitude - stickDeadZone) / span;
    scaled *= moveSensitivity;
    if (scaled > 1) scaled = 1;
    return value < 0 ? -scaled : scaled;
  }

  static int _radTo16(double rad) {
    var normalized = rad % (2 * math.pi);
    if (normalized < 0) normalized += 2 * math.pi;
    return ((normalized / (2 * math.pi)) * 65536).round() & 0xFFFF;
  }
}
