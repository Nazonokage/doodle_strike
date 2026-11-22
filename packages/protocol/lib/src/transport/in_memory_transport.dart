import 'dart:async';
import 'dart:typed_data';

import 'transport.dart';

/// Two linked endpoints in one process. Used for offline play (a host and one
/// local client) and for tests. The host sees the client as peer 1; the
/// client sees the host as peer 0.
class InMemoryTransport implements Transport {
  InMemoryTransport._(this._selfId, this._peerId);

  /// Create a linked (host, client) pair.
  static ({InMemoryTransport host, InMemoryTransport client}) pair() {
    final host = InMemoryTransport._(0, 1);
    final client = InMemoryTransport._(1, 0);
    host._other = client;
    client._other = host;
    return (host: host, client: client);
  }

  final PeerId _selfId;
  final PeerId _peerId;
  late final InMemoryTransport _other;
  /// Sync so a send is visible to the other peer before the caller returns.
  /// The session tests (and a listen-server step) apply that input on the
  /// same tick. An async controller would hold it until a later microtask.
  final StreamController<TransportEvent> _controller =
      StreamController<TransportEvent>.broadcast(sync: true);
  bool _running = false;

  @override
  Stream<TransportEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    _running = true;
    if (_other._running) {
      _controller.add(PeerConnected(_peerId));
      _other._controller.add(PeerConnected(_selfId));
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    if (_other._running) {
      _other._controller.add(PeerDisconnected(_selfId));
    }
  }

  void _deliver(PeerId to, Uint8List data, {required bool reliable}) {
    if (!_running || !_other._running || to != _peerId) return;
    _other._controller.add(DataReceived(_selfId, data, reliable: reliable));
  }

  @override
  void sendReliable(PeerId to, Uint8List data) => _deliver(to, data, reliable: true);

  @override
  void sendUnreliable(PeerId to, Uint8List data) => _deliver(to, data, reliable: false);

  @override
  void broadcastReliable(Uint8List data) => _deliver(_peerId, data, reliable: true);

  @override
  void broadcastUnreliable(Uint8List data) => _deliver(_peerId, data, reliable: false);
}
