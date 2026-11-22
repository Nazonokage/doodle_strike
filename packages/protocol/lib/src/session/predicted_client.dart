import 'dart:async';

import 'package:sim/sim.dart';

import '../codec.dart';
import '../messages.dart';
import '../snapshot.dart';
import '../transport/transport.dart';

class _PredictedTick {
  _PredictedTick(this.command, this.stateAfter);

  final InputCommand command;
  final WorldState stateAfter;
}

/// Runs the local player's inputs immediately, then rewinds to the host
/// snapshot and replays anything the host has not acknowledged yet.
///
/// Remote players in [sim] are only correct at a snapshot. Render them from
/// [latestSnapshot], not from the predicted sim.
class PredictedClient {
  PredictedClient({
    required this.sim,
    required this.transport,
    required this.playerId,
    required this.hostPeer,
  }) {
    _sub = transport.events.listen(_onEvent);
  }

  final Simulation sim;
  final Transport transport;
  final int playerId;
  final PeerId hostPeer;

  static const double _positionEpsilon = 0.02;
  static const int _historyCap = 180;

  final List<_PredictedTick> _history = <_PredictedTick>[];
  final List<InputCommand> _outbound = <InputCommand>[];
  WorldSnapshot? latestSnapshot;
  int _seq = 0;
  int _newestSnapshotSeq = -1;
  late final StreamSubscription<TransportEvent> _sub;

  void dispose() {
    _sub.cancel();
  }

  /// Step the local sim with [command] and send it (batched with the previous
  /// two) on the unreliable channel. The command's tick is forced to the
  /// sim tick about to be simulated.
  void submit(InputCommand command) {
    final stamped = command.withTick(sim.tick);
    sim.step(<int, InputCommand>{playerId: stamped});
    _history.add(_PredictedTick(stamped, sim.snapshot()));
    if (_history.length > _historyCap) {
      _history.removeRange(0, _history.length - _historyCap);
    }
    _outbound.add(stamped);
    if (_outbound.length > 3) {
      _outbound.removeRange(0, _outbound.length - 3);
    }
    _seq += 1;
    transport.sendUnreliable(
      hostPeer,
      encodeInputPacket(
        InputPacket(
          header: PacketHeader(seq: _seq),
          playerId: playerId,
          inputs: List<InputCommand>.from(_outbound),
        ),
      ),
    );
  }

  void _onEvent(TransportEvent event) {
    if (event is! DataReceived) return;
    try {
      final map = decodeJsonMap(event.data);
      if (packetKind(map) != 'snap') return;
      final snap = decodeSnapshot(event.data);
      if (snap.header.seq <= _newestSnapshotSeq) return;
      _newestSnapshotSeq = snap.header.seq;
      _reconcile(snap);
    } on FormatException {
      // Drop it. A later snapshot replaces it.
    } on VersionMismatch {
      // Joining code should already have refused this peer.
    }
  }

  void _reconcile(WorldSnapshot snap) {
    latestSnapshot = snap;
    final serverTick = snap.state.tick;
    final serverPlayer = snap.state.playerById(playerId);
    _PredictedTick? predicted;
    for (final entry in _history) {
      if (entry.stateAfter.tick == serverTick) predicted = entry;
    }
    final predictedPlayer = predicted?.stateAfter.playerById(playerId);
    if (serverPlayer != null &&
        predictedPlayer != null &&
        _closeEnough(predictedPlayer, serverPlayer)) {
      _history.removeWhere((entry) => entry.stateAfter.tick <= serverTick);
      return;
    }

    // Inputs stamped for ticks the host already simulated are dropped. Anything
    // newer is replayed on top of the authoritative state.
    final replay = <InputCommand>[
      for (final entry in _history)
        if (entry.command.tick >= serverTick) entry.command,
    ];
    sim.restore(snap.state);
    _history.clear();
    for (final command in replay) {
      sim.step(<int, InputCommand>{playerId: command});
      _history.add(_PredictedTick(command, sim.snapshot()));
    }
  }

  bool _closeEnough(PlayerState predicted, PlayerState server) {
    final dx = predicted.x - server.x;
    final dy = predicted.y - server.y;
    final adx = dx < 0 ? -dx : dx;
    final ady = dy < 0 ? -dy : dy;
    return adx < _positionEpsilon &&
        ady < _positionEpsilon &&
        predicted.health == server.health &&
        predicted.alive == server.alive &&
        predicted.weaponIndex == server.weaponIndex &&
        predicted.ammo == server.ammo;
  }
}
