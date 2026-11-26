import 'dart:typed_data';

import 'package:protocol/protocol.dart';
import 'package:sim/sim.dart';
import 'package:test/test.dart';

const List<String> _rows = <String>[
  '####################',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#S.................#',
  '####################',
];

Simulation _sim() {
  final sim = Simulation(map: TileMap.fromRows(_rows), seed: 1);
  sim.addPlayer(1, x: 4, y: 5.2);
  return sim;
}

void main() {
  test('snapshot round trip keeps the hash, including a shot', () {
    final sim = _sim();
    sim.step(<int, InputCommand>{
      1: const InputCommand(tick: 0, buttons: InputCommand.btnFire, aim: 0),
    });
    final snap = WorldSnapshot(
      header: const PacketHeader(seq: 7),
      state: sim.snapshot(),
      lastInputTick: const <int, int>{1: 0},
    );
    final decoded = decodeSnapshot(encodeSnapshot(snap));
    expect(decoded.header.seq, equals(7));
    expect(decoded.lastInputTick[1], equals(0));
    expect(decoded.state.hash(), equals(sim.hash()));
    expect(decoded.state.projectiles.single.radius, equals(sim.state.projectiles.single.radius));
  });

  test('snapshot round trip keeps a gun pickup', () {
    final sim = _sim();
    sim.spawnGunField(count: 2);
    final snap = WorldSnapshot(
      header: const PacketHeader(seq: 1),
      state: sim.snapshot(),
      lastInputTick: const <int, int>{1: 0},
    );
    final decoded = decodeSnapshot(encodeSnapshot(snap));
    expect(decoded.state.pickups.length, equals(2));
    expect(decoded.state.pickups.first.weaponIndex, equals(sim.state.pickups.first.weaponIndex));
    expect(decoded.state.nextPickupId, equals(sim.state.nextPickupId));
    expect(decoded.state.hash(), equals(sim.hash()));
  });

  test('six players and a handful of shots stay under 1.5 KB', () {
    final sim = Simulation(map: TileMap.fromRows(_rows), seed: 3);
    for (var id = 1; id <= 6; id++) {
      sim.addPlayer(id, x: 2.0 + id, y: 5.2);
    }
    sim.step(<int, InputCommand>{
      for (var id = 1; id <= 6; id++)
        id: InputCommand(tick: 0, buttons: InputCommand.btnFire, aim: id * 1000),
    });
    final bytes = encodeSnapshot(
      WorldSnapshot(
        header: const PacketHeader(seq: 1),
        state: sim.snapshot(),
        lastInputTick: <int, int>{for (var id = 1; id <= 6; id++) id: 0},
      ),
    );
    expect(bytes.length, lessThan(1500));
  });

  test('lockstep host and client agree on the local player', () async {
    final pair = InMemoryTransport.pair();
    await pair.host.start();
    await pair.client.start();
    final host = MatchHost(sim: _sim(), transport: pair.host);
    final client = PredictedClient(
      sim: _sim(),
      transport: pair.client,
      playerId: 1,
      hostPeer: 0,
    );

    for (var i = 0; i < 30; i++) {
      final moveX = i.isEven ? 127 : -40;
      client.submit(InputCommand(tick: 0, moveX: moveX, aim: 1000 + i));
      host.stepOnce();
    }

    final hostPlayer = host.sim.state.playerById(1)!;
    final clientPlayer = client.sim.state.playerById(1)!;
    expect(client.sim.tick, equals(host.sim.tick));
    expect(clientPlayer.x, closeTo(hostPlayer.x, 1e-9));
    expect(clientPlayer.y, closeTo(hostPlayer.y, 1e-9));
    expect(client.sim.hash(), equals(host.sim.hash()));

    host.dispose();
    client.dispose();
    await pair.host.stop();
  });

  test('a dropped input stream is corrected by the next snapshot', () async {
    final pair = InMemoryTransport.pair();
    final clientNet = SimulatedTransport(pair.client, lossChance: 1);
    await pair.host.start();
    await clientNet.start();
    final host = MatchHost(sim: _sim(), transport: pair.host);
    final client = PredictedClient(
      sim: _sim(),
      transport: clientNet,
      playerId: 1,
      hostPeer: 0,
    );
    final startX = host.sim.state.playerById(1)!.x;

    for (var i = 0; i < 15; i++) {
      client.submit(const InputCommand(tick: 0, moveX: 127));
      host.stepOnce();
    }

    expect(host.sim.state.playerById(1)!.x, closeTo(startX, 1e-9));
    expect(client.sim.state.playerById(1)!.x, closeTo(startX, 1e-9));
    expect(client.latestSnapshot, isNotNull);

    host.dispose();
    client.dispose();
    clientNet.dispose();
    await pair.host.stop();
  });

  test('latency holds an unreliable packet until the clock catches up', () async {
    final pair = InMemoryTransport.pair();
    final slowed = SimulatedTransport(pair.client, latencyMs: 100, jitterMs: 0);
    final got = <Uint8List>[];
    pair.host.events.listen((event) {
      if (event is DataReceived) got.add(event.data);
    });
    await pair.host.start();
    await slowed.start();

    slowed.sendUnreliable(0, Uint8List.fromList(<int>[9]));
    slowed.elapse(99);
    expect(got, isEmpty);
    slowed.elapse(1);
    expect(got.single.single, equals(9));

    slowed.dispose();
    await pair.host.stop();
  });
}
