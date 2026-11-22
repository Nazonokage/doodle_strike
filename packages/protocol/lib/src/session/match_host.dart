import 'dart:async';

import 'package:sim/sim.dart';

import '../codec.dart';
import '../messages.dart';
import '../snapshot.dart';
import '../transport/transport.dart';
import '../version.dart';

/// Authoritative sim on one [Transport]. Applies remote inputs by tick and
/// broadcasts a snapshot every [snapshotEveryTicks] ticks.
class MatchHost {
  MatchHost({required this.sim, required this.transport}) {
    _sub = transport.events.listen(_onEvent);
  }

  final Simulation sim;
  final Transport transport;

  final Map<int, List<InputCommand>> _inbox = <int, List<InputCommand>>{};
  final Map<int, int> lastInputTick = <int, int>{};
  int _seq = 0;
  int _sinceSnapshot = 0;
  late final StreamSubscription<TransportEvent> _sub;

  void dispose() {
    _sub.cancel();
  }

  void _onEvent(TransportEvent event) {
    if (event is! DataReceived) return;
    try {
      final map = decodeJsonMap(event.data);
      if (packetKind(map) != 'in') return;
      final packet = decodeInputPacket(event.data);
      final queue = _inbox.putIfAbsent(packet.playerId, () => <InputCommand>[]);
      queue.addAll(packet.inputs);
      if (queue.length > 12) {
        queue.removeRange(0, queue.length - 12);
      }
    } on FormatException {
      // Ignore a malformed packet. The next good one still applies by tick.
    } on VersionMismatch {
      // A mismatched peer is refused by not stepping their inputs.
    }
  }

  /// Advance one authoritative tick. [localInputs] are players on this
  /// process (a listen-server human, or bots) and win over the network.
  void stepOnce([Map<int, InputCommand> localInputs = const <int, InputCommand>{}]) {
    final tick = sim.tick;
    final inputs = Map<int, InputCommand>.from(localInputs);
    final ids = _inbox.keys.toList()..sort();
    for (final id in ids) {
      if (inputs.containsKey(id)) {
        _inbox[id]!.removeWhere((command) => command.tick <= tick);
        continue;
      }
      final queue = _inbox[id]!;
      InputCommand? match;
      for (final command in queue) {
        if (command.tick == tick) match = command;
      }
      queue.removeWhere((command) => command.tick <= tick);
      if (match != null) inputs[id] = match;
    }
    for (final id in inputs.keys) {
      lastInputTick[id] = tick;
    }
    sim.step(inputs);
    _sinceSnapshot += 1;
    if (_sinceSnapshot >= snapshotEveryTicks) {
      _sinceSnapshot = 0;
      _seq += 1;
      transport.broadcastUnreliable(
        encodeSnapshot(
          WorldSnapshot(
            header: PacketHeader(seq: _seq),
            state: sim.snapshot(),
            lastInputTick: Map<int, int>.from(lastInputTick),
          ),
        ),
      );
    }
  }
}
