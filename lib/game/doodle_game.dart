import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:sim/sim.dart';

import '../input/game_input.dart';
import 'vfx.dart';

/// Phase 1 Combat Arena View for Doodle Strike.
///
/// Flame owns zero gameplay state: it only samples input, advances the
/// deterministic 60 Hz simulation, and renders the latest [WorldState].
class KillFeedLine {
  KillFeedLine(this.text) : remaining = 4;

  final String text;
  double remaining;
}

class DoodleGame extends FlameGame {
  DoodleGame({required this.input, required List<WeaponConfig> weapons})
      : _sim = Simulation(
          map: TileMap.fromRows(arenaMap),
          weapons: weapons,
        ) {
    // Add Player 1 (Local Human) and Player 2 (AI Bot)
    _sim.addPlayer(1);
    _sim.addPlayer(2);
  }

  final GameInput input;
  final Simulation _sim;
  final BotController _bot = const BotController(botId: 2);
  final VfxManager vfx = VfxManager();
  final List<KillFeedLine> killFeed = <KillFeedLine>[];

  static const double _tickSeconds = 1 / 60;
  double _accumulator = 0;

  /// State before the latest simulated tick. Rendering lerps from this toward
  /// the current state by [_alpha], which is leftover frame time.
  WorldState? _previous;
  double _alpha = 1;

  // Camera state
  double cameraX = 20.0;
  double cameraY = 12.0;
  double tileSize = 32.0;

  // Color palettes
  final Paint _bgPaint = Paint()..color = const Color(0xFF161622);
  final Paint _tilePaint = Paint()..color = const Color(0xFF282A3A);
  final Paint _tileTopPaint = Paint()..color = const Color(0xFF4C506D);

  final Paint _p1BodyPaint = Paint()..color = const Color(0xFF1E88E5);
  final Paint _headPaint = Paint()..color = const Color(0xFFFFCC80);
  final Paint _p1BandanaPaint = Paint()..color = const Color(0xFF0D47A1);

  final Paint _p2BodyPaint = Paint()..color = const Color(0xFFE53935);
  final Paint _p2BandanaPaint = Paint()..color = const Color(0xFFB71C1C);

  final Paint _gunPaint = Paint()
    ..color = const Color(0xFF424242)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;

  final Paint _laserPaint = Paint()
    ..color = const Color(0x55FF1744)
    ..strokeWidth = 1.5;

  final Paint _bulletPaint = Paint()..color = const Color(0xFFFFEE58);
  final Paint _bulletGlowPaint = Paint()..color = const Color(0x88FFB300);

  final Paint _barBg = Paint()..color = const Color(0xAA000000);
  final Paint _healthPaint = Paint()..color = const Color(0xFF00E676);
  final Paint _fuelPaint = Paint()..color = const Color(0xFF00E5FF);

  Simulation get sim => _sim;

  Offset? getPlayer1ScreenPos() {
    final p1 = _sim.state.playerById(1);
    if (p1 == null) return null;
    final view = _viewPlayer(p1);
    return Offset(
      size.x / 2 + (view.x - cameraX) * tileSize,
      size.y / 2 + (view.y - cameraY) * tileSize,
    );
  }

  static const List<String> arenaMap = <String>[
    '########################################',
    '#......................................#',
    '#..S................................S..#',
    '#......######................######....#',
    '#..................####................#',
    '#.............##..........##...........#',
    '#..#####.........................#####.#',
    '#......................................#',
    '#........###................###........#',
    '#..............############............#',
    '#......................................#',
    '#.....######..................######...#',
    '#..S...............####.............S..#',
    '#........##....................##......#',
    '#......................................#',
    '#.............##############...........#',
    '#...#####........................#####.#',
    '#......................................#',
    '#..........###............###..........#',
    '#...##............................##...#',
    '#......................................#',
    '#..S................................S..#',
    '#........#####............#####........#',
    '########################################',
  ];

  @override
  void update(double dt) {
    super.update(dt);

    vfx.update(dt);
    for (final line in killFeed) {
      line.remaining -= dt;
    }
    killFeed.removeWhere((line) => line.remaining <= 0);

    _accumulator += math.min(dt, 0.25);
    while (_accumulator >= _tickSeconds) {
      _previous = _sim.snapshot();
      final p1Cmd = input.sample(_sim.tick);
      final botCmd = _bot.computeInput(_sim.state, _sim.tick);

      _sim.step(<int, InputCommand>{
        1: p1Cmd,
        2: botCmd,
      });

      _processSimEvents();
      _accumulator -= _tickSeconds;
    }
    _alpha = _previous == null ? 1 : (_accumulator / _tickSeconds).clamp(0.0, 1.0);

    final p1 = _sim.state.playerById(1);
    if (p1 != null && p1.alive && p1.input.wantsJet && p1.fuel > 0) {
      vfx.spawnJetFlame(p1.x, p1.y + _sim.config.halfHeight);
    }
    final bot = _sim.state.playerById(2);
    if (bot != null && bot.alive && bot.input.wantsJet && bot.fuel > 0) {
      vfx.spawnJetFlame(bot.x, bot.y + _sim.config.halfHeight);
    }

    _followCamera(p1);
  }

  void _followCamera(PlayerState? p1) {
    if (size.x < 2 || size.y < 2) return;

    tileSize = math.max(28.0, math.min(size.x / 22.0, size.y / 14.0));
    if (p1 != null) {
      final view = _viewPlayer(p1);
      var targetCamX = view.x;
      var targetCamY = view.y;
      if (p1.alive) {
        final speed = p1.vx.abs() + p1.vy.abs();
        final zoom = 1 + (speed / _sim.config.maxFall).clamp(0.0, 1.0) * 0.12;
        tileSize = math.max(24.0, tileSize / zoom);

        final dir = Trig.direction(p1.input.aim);
        targetCamX += dir.x * 2.2;
        targetCamY += dir.y * 1.4;
      }
      // A respawn jumps many tiles. Snap instead of panning across the map.
      final gapX = targetCamX - cameraX;
      final gapY = targetCamY - cameraY;
      final gain = gapX.abs() + gapY.abs() > 6 ? 1.0 : 0.12;
      cameraX += gapX * gain;
      cameraY += gapY * gain;
    }

    final halfVisibleTilesX = (size.x / tileSize) / 2;
    final halfVisibleTilesY = (size.y / tileSize) / 2;
    cameraX = _clampCamera(cameraX, halfVisibleTilesX, _sim.map.width - halfVisibleTilesX, _sim.map.width / 2);
    cameraY = _clampCamera(cameraY, halfVisibleTilesY, _sim.map.height - halfVisibleTilesY, _sim.map.height / 2);
  }

  /// Centers the view when the screen shows more of the map than exists,
  /// which happens in portrait where a naive clamp would throw.
  static double _clampCamera(double value, double min, double max, double center) {
    if (min >= max) return center;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  ({double x, double y}) _viewPlayer(PlayerState player) {
    final previous = _previous?.playerById(player.id);
    return (
      x: _blend(previous?.x, player.x),
      y: _blend(previous?.y, player.y),
    );
  }

  ({double x, double y}) _viewShot(ProjectileState shot) {
    ProjectileState? previous;
    final prior = _previous?.projectiles;
    if (prior != null) {
      for (final candidate in prior) {
        if (candidate.id == shot.id) {
          previous = candidate;
          break;
        }
      }
    }
    return (
      x: _blend(previous?.x, shot.x),
      y: _blend(previous?.y, shot.y),
    );
  }

  /// A gap of more than a few tiles is a teleport (respawn or a new shot).
  double _blend(double? from, double to) {
    if (from == null) return to;
    final delta = to - from;
    if (delta.abs() > 2.5) return to;
    return from + delta * _alpha;
  }

  void _processSimEvents() {
    for (final e in _sim.events) {
      switch (e) {
        case ShotFiredEvent():
          vfx.spawnMuzzleFlash(e.x, e.y, (e.aim / 65536.0) * 2 * math.pi);
          if (e.shooterId == 1) {
            vfx.addScreenShake(1.2);
          }
        case ProjectileHitEvent():
          if (e.hitPlayerId != null) {
            vfx.spawnPlayerHitBlood(e.x, e.y, e.damage);
          } else {
            vfx.spawnWallHitSparks(e.x, e.y);
          }
        case PlayerDiedEvent():
          vfx.spawnDeathExplosion(e.x, e.y);
          final killer = e.killerId == 1 ? 'YOU' : 'BOT';
          final victim = e.victimId == 1 ? 'YOU' : 'BOT';
          killFeed.insert(0, KillFeedLine('$killer  >  $victim'));
          if (killFeed.length > 4) killFeed.removeLast();
        case PlayerRespawnedEvent():
          vfx.spawnWallHitSparks(e.x, e.y);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Apply camera transform and screen shake
    final shake = vfx.getShakeOffset();
    canvas.save();
    canvas.translate(size.x / 2 + shake.x, size.y / 2 + shake.y);

    // Background fill
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x * 2, height: size.y * 2),
      _bgPaint,
    );

    _renderMap(canvas);
    _renderVfx(canvas);

    // Render Projectiles
    _renderProjectiles(canvas);

    // Render Players
    _renderPlayers(canvas);

    canvas.restore();
  }

  void _renderMap(Canvas canvas) {
    final map = _sim.map;

    for (var ty = 0; ty < map.height; ty++) {
      for (var tx = 0; tx < map.width; tx++) {
        if (!map.isSolid(tx, ty)) continue;

        final rx = (tx - cameraX) * tileSize;
        final ry = (ty - cameraY) * tileSize;

        // Skip off-screen tiles
        if (rx < -size.x / 2 - tileSize || rx > size.x / 2 + tileSize) continue;
        if (ry < -size.y / 2 - tileSize || ry > size.y / 2 + tileSize) continue;

        final rect = Rect.fromLTWH(rx, ry, tileSize, tileSize);
        canvas.drawRect(rect, _tilePaint);

        // Highlight top surface of platform
        if (ty == 0 || !map.isSolid(tx, ty - 1)) {
          canvas.drawRect(Rect.fromLTWH(rx, ry, tileSize, 4.0), _tileTopPaint);
        }
      }
    }
  }

  void _renderPlayers(Canvas canvas) {
    final cfg = _sim.config;

    for (final p in _sim.state.players) {
      final view = _viewPlayer(p);
      final px = (view.x - cameraX) * tileSize;
      final py = (view.y - cameraY) * tileSize;

      if (!p.alive) {
        // Render respawn indicator
        final respawnSecs = (p.respawnTimer / 60.0).toStringAsFixed(1);
        final tp = TextPainter(
          text: TextSpan(
            text: 'RESPAWN IN ${respawnSecs}s',
            style: const TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px - tp.width / 2, py - 10));
        continue;
      }

      final isP1 = p.id == 1;
      final bodyPaint = isP1 ? _p1BodyPaint : _p2BodyPaint;
      final bandanaPaint = isP1 ? _p1BandanaPaint : _p2BandanaPaint;

      // Laser Sight for local player
      if (isP1) {
        final dir = Trig.direction(p.input.aim);
        canvas.drawLine(
          Offset(px, py),
          Offset(px + dir.x * tileSize * 15, py + dir.y * tileSize * 15),
          _laserPaint,
        );
      }

      // Jetpack backpack on back
      final facingLeft = p.input.aim > 16384 && p.input.aim < 49152;
      final packOffsetX = facingLeft ? 10.0 : -10.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(px + packOffsetX, py), width: 8.0, height: 18.0),
          const Radius.circular(3.0),
        ),
        Paint()..color = const Color(0xFF607D8B),
      );

      // Body (Mini Militia Soldier torso)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(px, py + 3), width: 18.0, height: 20.0),
          const Radius.circular(6.0),
        ),
        bodyPaint,
      );

      if (p.shieldTicks > 0) {
        canvas.drawCircle(
          Offset(px, py),
          22,
          Paint()
            ..color = const Color(0x6600E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // Head
      canvas.drawCircle(Offset(px, py - 12), 9.0, _headPaint);

      // Helmet / Bandana
      canvas.drawArc(
        Rect.fromCircle(center: Offset(px, py - 13), radius: 10.0),
        math.pi,
        math.pi,
        true,
        bandanaPaint,
      );

      // Gun Arm rotating towards aim direction
      final aimRad = (p.input.aim / 65536.0) * 2 * math.pi;
      final gunEndX = px + math.cos(aimRad) * 22.0;
      final gunEndY = py + math.sin(aimRad) * 22.0;
      canvas.drawLine(Offset(px, py), Offset(gunEndX, gunEndY), _gunPaint);

      // Overhead HUD: Mini Health Bar & Fuel Bar
      final barW = 32.0;
      final barH = 3.5;
      final barY = py - 28.0;

      // Health bar
      canvas.drawRect(Rect.fromLTWH(px - barW / 2, barY, barW, barH), _barBg);
      canvas.drawRect(
        Rect.fromLTWH(
          px - barW / 2,
          barY,
          barW * (p.health / cfg.healthMax).clamp(0.0, 1.0),
          barH,
        ),
        _healthPaint,
      );

      // Fuel bar
      canvas.drawRect(Rect.fromLTWH(px - barW / 2, barY + barH + 1, barW, 2.5), _barBg);
      canvas.drawRect(
        Rect.fromLTWH(
          px - barW / 2,
          barY + barH + 1,
          barW * (p.fuel / cfg.fuelMax).clamp(0.0, 1.0),
          2.5,
        ),
        _fuelPaint,
      );

      // Player Tag
      final tagText = isP1 ? 'YOU' : 'BOT';
      final tagTp = TextPainter(
        text: TextSpan(
          text: tagText,
          style: TextStyle(
            color: isP1 ? const Color(0xFF64B5F6) : const Color(0xFFE57373),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tagTp.paint(canvas, Offset(px - tagTp.width / 2, barY - 11));
    }
  }

  void _renderProjectiles(Canvas canvas) {
    for (final pr in _sim.state.projectiles) {
      final view = _viewShot(pr);
      final px = (view.x - cameraX) * tileSize;
      final py = (view.y - cameraY) * tileSize;

      // Bullet trail
      canvas.drawLine(
        Offset(px - pr.vx * tileSize * 1.5, py - pr.vy * tileSize * 1.5),
        Offset(px, py),
        _bulletGlowPaint..strokeWidth = 3.0,
      );

      // Bullet core
      canvas.drawCircle(Offset(px, py), 3.5, _bulletPaint);
    }
  }

  void _renderVfx(Canvas canvas) {
    // Render particles
    for (final p in vfx.particles) {
      final px = (p.x - cameraX) * tileSize;
      final py = (p.y - cameraY) * tileSize;
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }

    // Render muzzle flashes
    for (final mf in vfx.muzzleFlashes) {
      final px = (mf.x - cameraX) * tileSize;
      final py = (mf.y - cameraY) * tileSize;
      canvas.drawCircle(
        Offset(px, py),
        6.0,
        Paint()..color = const Color(0xFFFFF176),
      );
    }

    // Render floating text numbers
    for (final ft in vfx.floatingTexts) {
      final px = (ft.x - cameraX) * tileSize;
      final py = (ft.y - cameraY) * tileSize;
      final alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withValues(alpha: alpha),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py));
    }
  }
}
