import 'dart:async';
import 'dart:typed_data';

import 'package:sim/sim.dart';

import 'transport.dart';

/// Wraps a transport and delays, jitters, or drops what this side sends.
///
/// Time only moves when [elapse] is called, so tests stay deterministic.
/// Reliable packets are delayed but never dropped. Incoming packets are
/// forwarded immediately; delay them by wrapping the sender instead.
class SimulatedTransport implements Transport {
  SimulatedTransport(
    this._inner, {
    this.latencyMs = 0,
    this.jitterMs = 0,
    this.lossChance = 0,
    int seed = 1,
  }) : _rng = Rng(seed) {
    _innerSub = _inner.events.listen(_controller.add);
  }

  final Transport _inner;
  final Rng _rng;

  int latencyMs;
  int jitterMs;

  /// Chance in 0..1 that an unreliable send is discarded.
  double lossChance;

  int timeMs = 0;

  /// Sync so latency delivery and forwarded snapshots are visible to listeners
  /// before [elapse] or the inner send returns.
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast(sync: true);
  final List<({int at, void Function() deliver})> _queue = <({int at, void Function() deliver})>[];
  late final StreamSubscription<TransportEvent> _innerSub;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<void> start() => _inner.start();

  @override
  Future<void> stop() async {
    _queue.clear();
    await _inner.stop();
  }

  void dispose() {
    _innerSub.cancel();
  }

  /// Move the clock forward and deliver anything that is due.
  void elapse(int ms) {
    if (ms < 0) return;
    timeMs += ms;
    _flush();
  }

  void _flush() {
    _queue.sort((a, b) => a.at.compareTo(b.at));
    final due = _queue.where((item) => item.at <= timeMs).toList();
    _queue.removeWhere((item) => item.at <= timeMs);
    for (final item in due) {
      item.deliver();
    }
  }

  void _send(void Function(Uint8List data) deliver, Uint8List data, {required bool reliable}) {
    final copy = Uint8List.fromList(data);
    if (!reliable && lossChance > 0) {
      final roll = _rng.nextInt(1000) / 1000.0;
      if (roll < lossChance) return;
    }
    var wait = latencyMs;
    if (jitterMs > 0) wait += _rng.nextInt(jitterMs + 1);
    if (wait <= 0) {
      deliver(copy);
      return;
    }
    _queue.add((at: timeMs + wait, deliver: () => deliver(copy)));
  }

  @override
  void sendReliable(PeerId to, Uint8List data) =>
      _send((bytes) => _inner.sendReliable(to, bytes), data, reliable: true);

  @override
  void sendUnreliable(PeerId to, Uint8List data) =>
      _send((bytes) => _inner.sendUnreliable(to, bytes), data, reliable: false);

  @override
  void broadcastReliable(Uint8List data) =>
      _send(_inner.broadcastReliable, data, reliable: true);

  @override
  void broadcastUnreliable(Uint8List data) =>
      _send(_inner.broadcastUnreliable, data, reliable: false);
}
