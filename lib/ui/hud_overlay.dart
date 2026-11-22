import 'dart:async';
import 'package:flutter/material.dart' hide Simulation;
import 'package:sim/sim.dart';

import '../game/doodle_game.dart';
import '../input/game_input.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.game,
    required this.input,
  });

  final DoodleGame game;
  final GameInput input;

  Simulation get sim => game.sim;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  // Left joystick touch state
  Offset? _leftStart;
  Offset? _leftCurrent;

  // Right joystick touch state
  Offset? _rightStart;
  Offset? _rightCurrent;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // 20 Hz HUD refresh rate (matching snapshot rate)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.sim;
    final state = sim.state;
    final p1 = state.playerById(1);
    final bot = state.playerById(2);
    final gun = p1 == null ? sim.weapon : sim.weaponOf(p1);

    final hp = p1?.health ?? 0;
    final maxHp = sim.config.healthMax;
    final fuel = p1?.fuel ?? 0;
    final maxFuel = sim.config.fuelMax;
    final ammo = p1?.ammo ?? 0;
    final maxAmmo = gun.magazineSize;
    final isReloading = (p1?.reloadCooldown ?? 0) > 0;
    final shielded = (p1?.shieldTicks ?? 0) > 0;

    final p1Kills = p1?.kills ?? 0;
    final botKills = bot?.kills ?? 0;

    return Stack(
      children: [
        // 1. Top HUD Bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Player Status Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1B29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44FFFFFF)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Health Bar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, color: Color(0xFFFF5252), size: 16),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          height: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (hp / maxHp).clamp(0.0, 1.0),
                              backgroundColor: const Color(0x33FF5252),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hp > 30 ? const Color(0xFF00E676) : const Color(0xFFFF1744),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$hp HP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Jetpack Fuel Bar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rocket_launch, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          height: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (fuel / maxFuel).clamp(0.0, 1.0),
                              backgroundColor: const Color(0x3300E5FF),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${((fuel / maxFuel) * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ammo Counter & Reload
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, color: Color(0xFFFFD54F), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          isReloading
                              ? 'RELOADING...'
                              : '${shielded ? 'SHIELD  ' : ''}${gun.name}  $ammo / $maxAmmo',
                          style: TextStyle(
                            color: isReloading ? const Color(0xFFFF9100) : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            widget.input.touchReload = true;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'RELOAD',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scoreboard Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1B29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44FFFFFF)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YOU',
                          style: TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$p1Kills',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(':', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'BOT',
                          style: TextStyle(color: Color(0xFFE57373), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$botKills',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Kill feed
        Positioned(
          top: 92,
          left: 0,
          right: 0,
          child: Column(
            children: [
              for (final line in widget.game.killFeed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Weapon picker
        Positioned(
          bottom: 176,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final weapon in sim.weapons)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _WeaponChip(
                    label: weapon.name,
                    selected: gun.id == weapon.id,
                    onTap: () => widget.input.pendingWeaponId = weapon.id,
                  ),
                ),
            ],
          ),
        ),

        // Controls tip. Touch sticks are always on screen; the sentence
        // switches when there is no room for a keyboard legend.
        Positioned(
          bottom: 12,
          left: 160,
          right: 160,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xAA101018),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Text(
                MediaQuery.sizeOf(context).width < 700
                    ? 'Left stick flies. Right stick aims and fires.'
                    : 'WASD fly  ·  Mouse aim  ·  Click fire  ·  1-4 or Q weapons  ·  R reload',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        // 3. Virtual Touch Joystick Left (Movement & Flight)
        Positioned(
          bottom: 24,
          left: 24,
          width: 140,
          height: 140,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() {
                _leftStart = details.localPosition;
                _leftCurrent = details.localPosition;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _leftCurrent = details.localPosition;
                final offset = _clampStick(_leftCurrent! - _leftStart!, 50);
                widget.input.touchMoveX = offset.dx / 50;
                widget.input.touchMoveY = offset.dy / 50;
              });
            },
            onPanEnd: (_) {
              setState(() {
                _leftStart = null;
                _leftCurrent = null;
                widget.input.touchMoveX = 0;
                widget.input.touchMoveY = 0;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x22FFFFFF),
                border: Border.all(color: const Color(0x44FFFFFF), width: 2),
              ),
              child: Center(
                child: Transform.translate(
                  offset: _clampStick(
                    _leftStart == null || _leftCurrent == null ? Offset.zero : _leftCurrent! - _leftStart!,
                    50,
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x882196F3),
                    ),
                    child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4. Virtual Touch Joystick Right (Aim & Fire)
        Positioned(
          bottom: 24,
          right: 24,
          width: 140,
          height: 140,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() {
                _rightStart = details.localPosition;
                _rightCurrent = details.localPosition;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _rightCurrent = details.localPosition;
                final offset = _clampStick(_rightCurrent! - _rightStart!, 50);
                widget.input.touchAiming = offset.distance > 8;
                widget.input.touchAimX = offset.dx;
                widget.input.touchAimY = offset.dy;
                widget.input.touchFiring = offset.distance > 22;
              });
            },
            onPanEnd: (_) {
              setState(() {
                _rightStart = null;
                _rightCurrent = null;
                widget.input.touchAiming = false;
                widget.input.touchAimX = 0;
                widget.input.touchAimY = 0;
                widget.input.touchFiring = false;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x22FFFFFF),
                border: Border.all(color: const Color(0x44FF1744), width: 2),
              ),
              child: Center(
                child: Transform.translate(
                  offset: _clampStick(
                    _rightStart == null || _rightCurrent == null ? Offset.zero : _rightCurrent! - _rightStart!,
                    50,
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x88FF1744),
                    ),
                    child: const Icon(Icons.gps_fixed, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Offset _clampStick(Offset offset, double radius) {
  final len = offset.distance;
  if (len <= radius || len == 0) return offset;
  return offset * (radius / len);
}

class _WeaponChip extends StatelessWidget {
  const _WeaponChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xCC1E88E5) : const Color(0xCC1A1B29),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF90CAF9) : const Color(0x44FFFFFF)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
