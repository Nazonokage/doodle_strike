import '../commands/input_command.dart';
import '../math/trig.dart';
import '../world_state.dart';

enum BotDifficulty { chill, standard, sharp }

/// Simple deterministic AI bot controller.
///
/// Bots emit standard [InputCommand]s through the same pipeline as human
/// players, without touching internal simulation state directly.
class BotController {
  const BotController(
      {required this.botId, this.difficulty = BotDifficulty.standard});

  final int botId;
  final BotDifficulty difficulty;

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

    final dx = target.x - me.x;
    final dy = target.y - me.y;

    final aimLeadTicks = switch (difficulty) {
      BotDifficulty.chill => 0,
      BotDifficulty.standard => 2,
      BotDifficulty.sharp => 7,
    };
    final aim = Trig.angleBetween(
      me.x,
      me.y,
      target.x + target.vx * aimLeadTicks,
      target.y + target.vy * aimLeadTicks,
    );

    var moveX = 0;
    final moveSpeed = switch (difficulty) {
      BotDifficulty.chill => 58,
      BotDifficulty.standard => 85,
      BotDifficulty.sharp => 112,
    };
    if (dx > 1.2) {
      moveX = moveSpeed;
    } else if (dx < -1.2) {
      moveX = -moveSpeed;
    } else if (difficulty != BotDifficulty.chill && nearestDistSq < 100) {
      // Close-range strafe keeps the bot from standing still in a duel.
      final strafePeriod = difficulty == BotDifficulty.sharp ? 32 : 48;
      moveX = (tick ~/ strafePeriod).isEven ? moveSpeed : -moveSpeed;
    }

    var buttons = 0;
    var moveY = 0;

    // Jetpack if target is higher than bot, or burst intermittently for vertical combat.
    if (dy < -0.8 && me.fuel > 10) {
      buttons |= InputCommand.btnJet;
      moveY = -90;
    } else if (me.fuel > 120 && _usesJetThisTick(tick)) {
      buttons |= InputCommand.btnJet;
    }

    // Each level gets a distinct engagement range.
    final fireRangeSq = switch (difficulty) {
      BotDifficulty.chill => 225.0,
      BotDifficulty.standard => 484.0,
      BotDifficulty.sharp => 784.0,
    };
    if (nearestDistSq < fireRangeSq) {
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

  bool _usesJetThisTick(int tick) => switch (difficulty) {
        BotDifficulty.chill => tick % 100 < 18,
        BotDifficulty.standard => tick % 70 < 30,
        BotDifficulty.sharp => tick % 60 < 38,
      };
}
