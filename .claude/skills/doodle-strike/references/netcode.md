# Netcode Reference

Read before touching networking, protocol, prediction, or discovery. Full detail is in `ARCHITECTURE.md` section 5a.

## Contents
1. Rates
2. Channels
3. Transport interface
4. Prediction and reconciliation
5. Interpolation
6. Join flow
7. Platform limits
8. Testing under bad networks

## 1. Rates

| Item | Value |
|---|---|
| Sim | 60 Hz fixed |
| Input send | every tick, last 3 inputs batched |
| Snapshot | 20 Hz (every 3rd tick) |
| Remote interpolation delay | about 100 ms |

Do not change these casually; they are locked decisions D1. If a change is needed, measure first and update PLAN.md.

## 2. Channels

| Reliable | Unreliable (latest wins) |
|---|---|
| JoinRoom, LeaveRoom, Ready, GameStart, GameEnd, PlayerJoined/Left, Kill, Respawn | InputCommand, WorldSnapshot |

Every packet has: protocol version, ruleset version, sequence number. Drop snapshots older than the newest seen. Reject mismatched versions at join.

## 3. Transport interface

Game code depends on:

```dart
abstract class Transport {
  Stream<TransportEvent> get events;
  Future<void> start();
  Future<void> stop();
  void sendReliable(PeerId to, Uint8List data);
  void sendUnreliable(PeerId to, Uint8List data);
  void broadcastReliable(Uint8List data);
  void broadcastUnreliable(Uint8List data);
}
```

Implementations: `InMemoryTransport` (offline, tests), `WebSocketTransport` (LAN MVP, TCP), `SimulatedTransport` (wraps another to add latency, jitter, loss, reorder), UDP/online later. Never import a concrete transport from gameplay or UI code.

## 4. Prediction and reconciliation

1. Stamp input with tick `t`, apply locally immediately, store `(input, predictedState)` in a ring buffer.
2. Snapshot includes `lastProcessedInputTick` for this client.
3. Discard buffer entries up to that tick; compare predicted vs authoritative local-player state at that tick.
4. If error exceeds epsilon: `restore(serverState)` then replay remaining buffered inputs.
5. Small error: blend visually over about 100 ms. Large error: snap.

Only the local player is predicted. Never predict damage, death, pickups, or kills. Cosmetic predicted effects (muzzle flash) are fine and must be reconciled or discarded.

## 5. Interpolation

Remote entities render between the two snapshots bracketing `now - interpolationDelay`. If snapshots are missing, hold the last state briefly then extrapolate only a few ticks. Rendering state is separate from sim state; interpolation never writes into the sim.

## 6. Join flow

Preferred order: QR code (host IP, port, room id), room code, manual IP, mDNS/NSD as an automatic bonus. Never make mDNS the only path.

## 7. Platform limits

- Web: client only (no hosting, no mDNS/raw sockets).
- iOS: local-network permission and Bonjour entries in `Info.plist`; hosting pauses when backgrounded, so keep the screen awake and warn players.
- Android: multicast lock and Wi-Fi/nearby permissions by OS version.
- WebSocket is TCP: expect head-of-line blocking; sequence numbers are the mitigation for the MVP.

## 8. Testing under bad networks

Always test with `SimulatedTransport`: 100 ms latency, 30 ms jitter, 5% loss, occasional reordering. Watch: prediction error magnitude, rewind count per second, snapshot size, input buffer growth. Targets live in PLAN.md (MVP criteria).
