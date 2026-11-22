import 'dart:typed_data';

typedef PeerId = int;

/// Events a transport reports. Game code never sees sockets.
sealed class TransportEvent {
  const TransportEvent();
}

class PeerConnected extends TransportEvent {
  const PeerConnected(this.peer);
  final PeerId peer;
}

class PeerDisconnected extends TransportEvent {
  const PeerDisconnected(this.peer);
  final PeerId peer;
}

class DataReceived extends TransportEvent {
  const DataReceived(this.from, this.data, {required this.reliable});
  final PeerId from;
  final Uint8List data;
  final bool reliable;
}

/// Everything gameplay and networking code may know about the network.
///
/// Reliable: joins, readiness, kills, game start/end. Unreliable (latest
/// wins): inputs and snapshots. The LAN MVP runs both over TCP, but callers
/// must still choose deliberately so UDP can slot in later.
abstract class Transport {
  Stream<TransportEvent> get events;

  Future<void> start();
  Future<void> stop();

  void sendReliable(PeerId to, Uint8List data);
  void sendUnreliable(PeerId to, Uint8List data);
  void broadcastReliable(Uint8List data);
  void broadcastUnreliable(Uint8List data);
}
