import 'dart:convert';
import 'dart:typed_data';

import 'package:protocol/protocol.dart';
import 'package:sim/sim.dart';
import 'package:test/test.dart';

void main() {
  group('input packet codec', () {
    const inputs = <InputCommand>[
      InputCommand(tick: 10, moveX: -127, moveY: 127, aim: 65535, buttons: 3, weaponId: 2),
      InputCommand(tick: 11, moveX: 5, moveY: -5, aim: 12345, buttons: 0, weaponId: 0),
    ];

    test('round trips', () {
      const packet = InputPacket(header: PacketHeader(seq: 42), playerId: 3, inputs: inputs);
      final decoded = decodeInputPacket(encodeInputPacket(packet));
      expect(decoded.header.seq, equals(42));
      expect(decoded.playerId, equals(3));
      expect(decoded.inputs, equals(inputs));
    });

    test('rejects a different protocol version', () {
      const packet = InputPacket(
        header: PacketHeader(seq: 1, protocol: protocolVersion + 1),
        playerId: 1,
        inputs: inputs,
      );
      expect(() => decodeInputPacket(encodeInputPacket(packet)), throwsA(isA<VersionMismatch>()));
    });

    test('rejects a different ruleset version', () {
      const packet = InputPacket(
        header: PacketHeader(seq: 1, ruleset: rulesetVersion + 1),
        playerId: 1,
        inputs: inputs,
      );
      expect(() => decodeInputPacket(encodeInputPacket(packet)), throwsA(isA<VersionMismatch>()));
    });
  });

  group('InMemoryTransport', () {
    test('delivers data from client to host and reports connection', () async {
      final pair = InMemoryTransport.pair();
      final hostEvents = <TransportEvent>[];
      pair.host.events.listen(hostEvents.add);

      await pair.host.start();
      await pair.client.start();
      pair.client.sendUnreliable(0, Uint8List.fromList(utf8.encode('hi')));
      await Future<void>.delayed(Duration.zero);

      expect(hostEvents.whereType<PeerConnected>().length, equals(1));
      final data = hostEvents.whereType<DataReceived>().single;
      expect(data.from, equals(1));
      expect(data.reliable, isFalse);
      expect(utf8.decode(data.data), equals('hi'));
    });

    test('broadcast reaches the other side and stop reports a disconnect', () async {
      final pair = InMemoryTransport.pair();
      final clientEvents = <TransportEvent>[];
      pair.client.events.listen(clientEvents.add);

      await pair.host.start();
      await pair.client.start();
      pair.host.broadcastReliable(Uint8List.fromList(<int>[1, 2, 3]));
      await pair.host.stop();
      await Future<void>.delayed(Duration.zero);

      expect(clientEvents.whereType<DataReceived>().single.reliable, isTrue);
      expect(clientEvents.whereType<PeerDisconnected>().length, equals(1));
    });
  });
}
