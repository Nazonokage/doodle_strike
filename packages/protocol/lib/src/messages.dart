import 'package:sim/sim.dart';

import 'version.dart';

/// Header on every packet. [seq] lets receivers drop stale unreliable packets.
class PacketHeader {
  const PacketHeader({
    required this.seq,
    this.protocol = protocolVersion,
    this.ruleset = rulesetVersion,
  });

  final int protocol;
  final int ruleset;
  final int seq;

  Map<String, Object?> toJson() => <String, Object?>{'p': protocol, 'r': ruleset, 's': seq};

  static PacketHeader fromJson(Map<String, Object?> json) => PacketHeader(
        protocol: json['p']! as int,
        ruleset: json['r']! as int,
        seq: json['s']! as int,
      );
}

/// A client's most recent inputs for one player. Batching the last few inputs
/// in each packet tolerates loss on the unreliable channel.
class InputPacket {
  const InputPacket({required this.header, required this.playerId, required this.inputs});

  final PacketHeader header;
  final int playerId;
  final List<InputCommand> inputs;
}

/// `[tick, moveX, moveY, aim, buttons, weaponId]`.
List<Object?> inputToJson(InputCommand c) => <Object?>[
      c.tick,
      c.moveX,
      c.moveY,
      c.aim,
      c.buttons,
      c.weaponId,
    ];

InputCommand inputFromJson(Object? raw) {
  final j = raw! as List<Object?>;
  return InputCommand(
    tick: j[0]! as int,
    moveX: j[1]! as int,
    moveY: j[2]! as int,
    aim: j[3]! as int,
    buttons: j[4]! as int,
    weaponId: j[5]! as int,
  );
}
