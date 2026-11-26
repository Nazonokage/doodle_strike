import 'dart:math' as math;
import 'dart:ui';

class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.maxLife,
  }) : life = maxLife;

  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double life;
  double maxLife;

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    life -= dt;
    return life > 0;
  }
}

class FloatingText {
  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    this.maxLife = 0.8,
  }) : life = maxLife;

  final String text;
  double x;
  double y;
  final Color color;
  double life;
  final double maxLife;

  bool update(double dt) {
    y -= 1.2 * dt;
    life -= dt;
    return life > 0;
  }
}

class MuzzleFlash {
  MuzzleFlash({
    required this.x,
    required this.y,
    required this.angle,
    this.life = 0.06,
  });

  double x;
  double y;
  double angle;
  double life;

  bool update(double dt) {
    life -= dt;
    return life > 0;
  }
}

class VfxManager {
  final List<Particle> particles = <Particle>[];
  final List<FloatingText> floatingTexts = <FloatingText>[];
  final List<MuzzleFlash> muzzleFlashes = <MuzzleFlash>[];
  final math.Random _rng = math.Random();

  double shakeMagnitude = 0.0;
  double _shakePhase = 0.0;

  /// View-only. The sim never reads this.
  bool screenShake = true;

  void addScreenShake(double amount) {
    if (!screenShake) return;
    if (shakeMagnitude <= 0) _shakePhase = 0;
    shakeMagnitude = math.min(shakeMagnitude + amount, 5.0);
  }

  void spawnMuzzleFlash(double x, double y, double angle) {
    muzzleFlashes.add(MuzzleFlash(x: x, y: y, angle: angle));
  }

  void spawnWallHitSparks(double x, double y) {
    for (var i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 3.0 + _rng.nextDouble() * 5.0;
      particles.add(Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color:
            _rng.nextBool() ? const Color(0xFFFFD54F) : const Color(0xFFFF7043),
        size: 2.0 + _rng.nextDouble() * 2.5,
        maxLife: 0.2 + _rng.nextDouble() * 0.2,
      ));
    }
  }

  void spawnPlayerHitBlood(double x, double y, int damage) {
    floatingTexts.add(FloatingText(
      text: '-$damage',
      x: x,
      y: y - 0.5,
      color: const Color(0xFFFF5252),
    ));

    for (var i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 2.0 + _rng.nextDouble() * 4.0;
      particles.add(Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: const Color(0xFFFF1744),
        size: 2.5 + _rng.nextDouble() * 2.0,
        maxLife: 0.25 + _rng.nextDouble() * 0.2,
      ));
    }
  }

  void spawnDeathExplosion(double x, double y, {required bool shake}) {
    if (shake) addScreenShake(8.0);
    floatingTexts.add(FloatingText(
      text: 'KILLED!',
      x: x,
      y: y - 1.0,
      color: const Color(0xFFFFD700),
      maxLife: 1.2,
    ));

    for (var i = 0; i < 25; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 4.0 + _rng.nextDouble() * 8.0;
      particles.add(Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color:
            _rng.nextBool() ? const Color(0xFFFF9100) : const Color(0xFFFF1744),
        size: 3.0 + _rng.nextDouble() * 3.5,
        maxLife: 0.4 + _rng.nextDouble() * 0.4,
      ));
    }
  }

  void spawnGrenadeExplosion(double x, double y) {
    for (var i = 0; i < 20; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 3.0 + _rng.nextDouble() * 7.0;
      particles.add(Particle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color:
            _rng.nextBool() ? const Color(0xFFFFA726) : const Color(0xFFFFE082),
        size: 2.5 + _rng.nextDouble() * 3.0,
        maxLife: 0.3 + _rng.nextDouble() * 0.3,
      ));
    }
  }

  void spawnJetFlame(double x, double y) {
    if (particles.length > 160) return;
    for (var i = 0; i < 2; i++) {
      final vx = (_rng.nextDouble() - 0.5) * 1.5;
      final vy = 3.0 + _rng.nextDouble() * 4.0; // blowing downwards
      particles.add(Particle(
        x: x + (_rng.nextDouble() - 0.5) * 0.2,
        y: y,
        vx: vx,
        vy: vy,
        color:
            _rng.nextBool() ? const Color(0xFF00E5FF) : const Color(0xFFFFAB40),
        size: 2.0 + _rng.nextDouble() * 2.0,
        maxLife: 0.15 + _rng.nextDouble() * 0.15,
      ));
    }
  }

  void update(double dt) {
    particles.removeWhere((p) => !p.update(dt));
    if (particles.length > 180) {
      particles.removeRange(0, particles.length - 180);
    }
    floatingTexts.removeWhere((t) => !t.update(dt));
    muzzleFlashes.removeWhere((m) => !m.update(dt));

    if (shakeMagnitude > 0) {
      shakeMagnitude -= 18.0 * dt;
      _shakePhase += dt * math.pi * 2 * 7;
      if (shakeMagnitude < 0) shakeMagnitude = 0;
    }
  }

  ({double x, double y}) getShakeOffset() {
    if (!screenShake || shakeMagnitude <= 0) return (x: 0.0, y: 0.0);
    return (
      x: math.sin(_shakePhase) * shakeMagnitude,
      y: math.sin(_shakePhase * 0.78 + 0.9) * shakeMagnitude * 0.55,
    );
  }
}
