import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Simulation;
import 'package:sim/sim.dart';

import '../game/doodle_game.dart';
import '../input/game_input.dart';
import 'hud_layout.dart';
import 'play_settings.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({
    super.key,
    required this.game,
    required this.input,
    required this.settings,
    required this.onLeave,
  });

  final DoodleGame game;
  final GameInput input;
  final PlaySettings settings;
  final VoidCallback onLeave;

  Simulation get sim => game.sim;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  Timer? _refreshTimer;
  final HudLayoutStore _store = HudLayoutStore();
  HudLayout _layout = HudLayout.defaults;

  @override
  void initState() {
    super.initState();
    // 20 Hz HUD refresh rate (matching snapshot rate)
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() {});
    });
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final layout = await _store.load();
    if (!mounted) return;
    setState(() => _layout = layout);
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
    final gun = p1 == null ? null : sim.carriedWeapon(p1);
    final gunLabel = gun?.name ?? 'PUNCH';
    final grenades = p1?.grenades ?? 0;
    final shield = p1?.shield ?? 0;

    final hp = p1?.health ?? 0;
    final maxHp = sim.config.healthMax;
    final fuel = p1?.fuel ?? 0;
    final maxFuel = sim.config.fuelMax;
    final ammo = p1?.ammo ?? 0;
    final maxAmmo = gun?.magazineSize ?? 0;
    final isReloading = (p1?.reloadCooldown ?? 0) > 0;
    final shielded = (p1?.shieldTicks ?? 0) > 0;

    final p1Kills = p1?.kills ?? 0;
    final botKills = bot?.kills ?? 0;

    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        if (!widget.settings.lockMoveStick)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: size.width / 2,
            child: _FloatingStick(
              knobColor: const Color(0x882196F3),
              ringColor: const Color(0x44FFFFFF),
              icon: Icons.navigation,
              onChanged: (offset) {
                widget.input.touchMoveX = offset.dx / 50;
                widget.input.touchMoveY = offset.dy / 50;
              },
              onReleased: () {
                widget.input.touchMoveX = 0;
                widget.input.touchMoveY = 0;
              },
            ),
          ),
        if (!widget.settings.lockAimStick)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: size.width / 2,
            child: _FloatingStick(
              knobColor: const Color(0x88FF1744),
              ringColor: const Color(0x44FF1744),
              icon: Icons.gps_fixed,
              onChanged: (offset) => _applyAim(offset),
              onReleased: _releaseAim,
            ),
          ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1B29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44FFFFFF)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 4)),
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
                        const Icon(Icons.favorite,
                            color: Color(0xFFFF5252), size: 16),
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
                                hp > 30
                                    ? const Color(0xFF00E676)
                                    : const Color(0xFFFF1744),
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
                        const Icon(Icons.rocket_launch,
                            color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          height: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (fuel / maxFuel).clamp(0.0, 1.0),
                              backgroundColor: const Color(0x3300E5FF),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00E5FF)),
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
                    if (shield > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield,
                              color: Color(0xFF80DEEA), size: 15),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 140,
                            height: 7,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (shield / PlayerState.maxShield)
                                    .clamp(0.0, 1.0),
                                backgroundColor: const Color(0x3380DEEA),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF80DEEA)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$shield SHIELD',
                            style: const TextStyle(
                              color: Color(0xFF80DEEA),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Ammo Counter & Reload
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on,
                            color: Color(0xFFFFD54F), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          isReloading
                              ? 'RELOADING...'
                              : '${shielded ? 'SPAWN SHIELD  ' : ''}$gunLabel${gun == null ? '' : '  $ammo / $maxAmmo'}',
                          style: TextStyle(
                            color: isReloading
                                ? const Color(0xFFFF9100)
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scoreboard Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1B29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x44FFFFFF)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 4)),
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
                          style: TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$p1Kills',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(':',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'BOT',
                          style: TextStyle(
                              color: Color(0xFFE57373),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$botKills',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: widget.onLeave,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB0B6C8),
                        minimumSize: const Size(48, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Leave',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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

        // Carried slots. Tap a filled slot to bring it to hand.
        Positioned(
          bottom: 176,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var slot = 0; slot < PlayerState.slotCount; slot++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _WeaponChip(
                    label: _slotLabel(p1, slot),
                    selected: p1 != null &&
                        p1.activeSlot == slot &&
                        p1.occupies(slot),
                    onTap: () {
                      if (p1 == null || !p1.occupies(slot)) return;
                      widget.input.pendingWeaponId = slot + 1;
                    },
                  ),
                ),
            ],
          ),
        ),

        // Controls tip. Wide screens get the keyboard legend. Narrow screens
        // describe whichever stick mode is on.
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
                _controlsTip(size.width),
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

        if (widget.settings.lockMoveStick)
          _placed(
            HudLayout.move,
            _StickPad(
              knobColor: const Color(0x882196F3),
              ringColor: const Color(0x44FFFFFF),
              icon: Icons.navigation,
              onChanged: (offset) {
                widget.input.touchMoveX = offset.dx / 50;
                widget.input.touchMoveY = offset.dy / 50;
              },
              onReleased: () {
                widget.input.touchMoveX = 0;
                widget.input.touchMoveY = 0;
              },
            ),
          ),
        if (widget.settings.lockAimStick)
          _placed(
            HudLayout.aim,
            _StickPad(
              knobColor: const Color(0x88FF1744),
              ringColor: const Color(0x44FF1744),
              icon: Icons.gps_fixed,
              onChanged: _applyAim,
              onReleased: _releaseAim,
            ),
          ),
        _placed(
          HudLayout.reload,
          _TapButton(
            label: 'RELOAD',
            color: const Color(0xCCF9A825),
            onTap: () => widget.input.touchReload = true,
          ),
        ),
        _placed(
          HudLayout.switchWeapon,
          _TapButton(
            label: 'SWITCH',
            color: const Color(0xCC1E88E5),
            onTap: () => widget.input.touchSwap = true,
          ),
        ),
        _placed(
          HudLayout.grenade,
          _TapButton(
            label: 'GREN $grenades',
            color: grenades > 0
                ? const Color(0xCCD97732)
                : const Color(0x884A3D35),
            onTap: () => widget.input.touchGrenade = true,
          ),
        ),
        _placed(
          HudLayout.drop,
          _TapButton(
            label: _needsSwap(p1) ? 'SWAP' : 'DROP',
            color: const Color(0xCC6D4C41),
            onTap: () => widget.input.touchDrop = true,
          ),
        ),
      ],
    );
  }

  String _controlsTip(double width) {
    if (width >= 700) {
      return 'A/D move  ·  W/↑ jet  ·  Mouse aim  ·  Click fire  ·  E grenade  ·  Q switch  ·  G drop';
    }
    final move = widget.settings.lockMoveStick
        ? 'Left pad moves; push up to jet'
        : 'Touch the left half; push up to jet';
    final aim = widget.settings.lockAimStick
        ? 'Right stick aims and fires'
        : 'Touch the right half to aim and fire';
    return '$move. $aim. Unarmed? Aim and fire to punch. Grenades are on the left.';
  }

  String _slotLabel(PlayerState? player, int slot) {
    if (player == null || !player.occupies(slot))
      return 'Slot ${slot + 1}  Empty';
    final index = player.loadout[slot];
    if (index < 0 || index >= widget.sim.weapons.length)
      return 'Slot ${slot + 1}  Empty';
    final rounds = player.magAmmo[slot];
    return 'Slot ${slot + 1}  ${widget.sim.weapons[index].name}  $rounds';
  }

  bool _needsSwap(PlayerState? player) {
    if (player == null || player.hasEmptySlot) return false;
    final reachX = widget.sim.config.halfWidth + 0.45;
    final reachY = widget.sim.config.halfHeight + 0.45;
    for (final gun in widget.sim.state.pickups) {
      if (!gun.onGround || gun.kind != PickupKind.weapon) continue;
      final dx = player.x - gun.x;
      final dy = player.y - gun.y;
      final ax = dx < 0 ? -dx : dx;
      final ay = dy < 0 ? -dy : dy;
      if (ax <= reachX && ay <= reachY) return true;
    }
    return false;
  }

  Widget _placed(String id, Widget child) {
    final screen = MediaQuery.sizeOf(context);
    final anchor = _layout.anchorOf(id);
    final base = _layout.baseSize(id);
    final placed = _layout.placedSize(id);
    return Positioned(
      left: anchor.dx * screen.width - placed.width / 2,
      top: anchor.dy * screen.height - placed.height / 2,
      width: placed.width,
      height: placed.height,
      child: Opacity(
        opacity: _layout.opacity,
        child: FittedBox(
          child: SizedBox(width: base.width, height: base.height, child: child),
        ),
      ),
    );
  }

  void _applyAim(Offset offset) {
    final sensitivity = widget.settings.aimSensitivity;
    final dead = 50 * widget.settings.stickDeadZone / sensitivity;
    final fireAt = 28 / sensitivity;
    widget.input.touchAiming = offset.distance > dead;
    widget.input.touchAimX = offset.dx;
    widget.input.touchAimY = offset.dy;
    widget.input.touchFiring = offset.distance > fireAt;
  }

  void _releaseAim() {
    widget.input.touchAiming = false;
    widget.input.touchAimX = 0;
    widget.input.touchAimY = 0;
    widget.input.touchFiring = false;
  }
}

class _StickPad extends StatefulWidget {
  const _StickPad({
    required this.knobColor,
    required this.ringColor,
    required this.icon,
    required this.onChanged,
    required this.onReleased,
  });

  final Color knobColor;
  final Color ringColor;
  final IconData icon;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  @override
  State<_StickPad> createState() => _StickPadState();
}

class _StickPadState extends State<_StickPad> {
  static const double _radius = 50;
  static const Offset _center = Offset(70, 70);

  Offset _knob = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _drag(details.localPosition);
      },
      onPanUpdate: (details) {
        _drag(details.localPosition);
      },
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x22FFFFFF),
          border: Border.all(color: widget.ringColor, width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _knob,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: widget.knobColor),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _drag(Offset local) {
    setState(() => _knob = _clampStick(local - _center, _radius));
    widget.onChanged(_knob);
  }

  void _release() {
    setState(() => _knob = Offset.zero);
    widget.onReleased();
  }
}

/// Touch-only stick that appears under the finger. Mouse clicks pass through
/// so desktop aim and fire still hit the playfield.
class _FloatingStick extends StatefulWidget {
  const _FloatingStick({
    required this.knobColor,
    required this.ringColor,
    required this.icon,
    required this.onChanged,
    required this.onReleased,
  });

  final Color knobColor;
  final Color ringColor;
  final IconData icon;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onReleased;

  @override
  State<_FloatingStick> createState() => _FloatingStickState();
}

class _FloatingStickState extends State<_FloatingStick> {
  static const double _radius = 50;

  Offset? _origin;
  Offset _knob = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.touch) return;
        setState(() {
          _origin = event.localPosition;
          _knob = Offset.zero;
        });
        widget.onChanged(Offset.zero);
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (event.kind != PointerDeviceKind.touch || origin == null) return;
        final knob = _clampStick(event.localPosition - origin, _radius);
        setState(() => _knob = knob);
        widget.onChanged(knob);
      },
      onPointerUp: (event) {
        if (event.kind == PointerDeviceKind.touch) _release();
      },
      onPointerCancel: (event) {
        if (event.kind == PointerDeviceKind.touch) _release();
      },
      child: _origin == null
          ? const SizedBox.expand()
          : Stack(
              children: [
                Positioned(
                  left: _origin!.dx - _radius,
                  top: _origin!.dy - _radius,
                  width: _radius * 2,
                  height: _radius * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x22FFFFFF),
                      border: Border.all(color: widget.ringColor, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  left: _origin!.dx + _knob.dx - 24,
                  top: _origin!.dy + _knob.dy - 24,
                  width: 48,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: widget.knobColor),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
    );
  }

  void _release() {
    setState(() {
      _origin = null;
      _knob = Offset.zero;
    });
    widget.onReleased();
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
          border: Border.all(
              color:
                  selected ? const Color(0xFF90CAF9) : const Color(0x44FFFFFF)),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TapButton extends StatelessWidget {
  const _TapButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onTap(),
        child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14), color: color),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}
