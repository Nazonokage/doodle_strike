import '../commands/input_command.dart';
import '../math/trig.dart';
import '../world_state.dart';

/// Simple deterministic AI bot controller.
///
/// Bots emit standard [InputCommand]s through the same pipeline as human
/// players, without touching internal simulation state directly.
class BotController {
  const BotController({required this.botId});

  final int botId;

  InputCommand computeInput(WorldState state, int tick) {
    final me = state.playerById(botId);
    if (me == null || !me.alive) {
      return InputCommand(tick: tick);
    }

    // Find nearest alive enemy player.
    PlayerState? target;
    double nearestDistSq = 1e9;
    for (final p in state.players) {
      if (p.id == botId || !p.alive) continue;
      final dx = p.x - me.x;
      final dy = p.y - me.y;
      final d = dx * dx + dy * dy;
      if (d < nearestDistSq) {
        nearestDistSq = d;
        target = p;
      }
    }

    if (target == null) {
      return InputCommand(tick: tick);
    }

    final aim = Trig.angleBetween(me.x, me.y, target.x, target.y);
    final dx = target.x - me.x;
    final dy = target.y - me.y;

    var moveX = 0;
    if (dx > 1.2) {
      moveX = 85;
    } else if (dx < -1.2) {
      moveX = -85;
    }

    var buttons = 0;
    var moveY = 0;

    // Jetpack if target is higher than bot, or burst intermittently for vertical combat.
    if (dy < -0.8 && me.fuel > 10) {
      buttons |= InputCommand.btnJet;
      moveY = -90;
    } else if (me.fuel > 120 && (tick % 70 < 30)) {
      buttons |= InputCommand.btnJet;
    }

    // Fire if within range (~22 tiles) and alive
    if (nearestDistSq < 484.0) {
      buttons |= InputCommand.btnFire;
    }

    // Reload if magazine empty
    if (me.ammo <= 0) {
      buttons |= InputCommand.btnReload;
    }

    return InputCommand(
      tick: tick,
      moveX: moveX,
      moveY: moveY,
      aim: aim,
      buttons: buttons,
    );
  }
}
