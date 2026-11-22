import 'dart:convert';
import 'dart:typed_data';

import 'package:sim/sim.dart';

import 'messages.dart';
import 'version.dart';

/// Thrown when a packet comes from a peer with an incompatible protocol or
/// ruleset version. Hosts should refuse the join.
class VersionMismatch implements Exception {
  const VersionMismatch({required this.theirProtocol, required this.theirRuleset});

  final int theirProtocol;
  final int theirRuleset;

  @override
  String toString() =>
      'VersionMismatch(protocol $theirProtocol vs $protocolVersion, '
      'ruleset $theirRuleset vs $rulesetVersion)';
}

/// JSON codec for the MVP. Swap for a binary codec later without touching
/// callers: they only see Uint8List in and out.
Uint8List encodeJsonMap(Map<String, Object?> map) =>
    Uint8List.fromList(utf8.encode(jsonEncode(map)));

Map<String, Object?> decodeJsonMap(Uint8List data) =>
    jsonDecode(utf8.decode(data)) as Map<String, Object?>;

PacketHeader headerFromMap(Map<String, Object?> map) {
  final header = PacketHeader.fromJson(map['h']! as Map<String, Object?>);
  if (header.protocol != protocolVersion || header.ruleset != rulesetVersion) {
    throw VersionMismatch(theirProtocol: header.protocol, theirRuleset: header.ruleset);
  }
  return header;
}

/// `in` for inputs, `snap` for world snapshots.
String packetKind(Map<String, Object?> map) {
  final kind = map['k'];
  if (kind is! String) {
    throw const FormatException('packet is missing kind');
  }
  return kind;
}

Uint8List encodeInputPacket(InputPacket p) {
  return encodeJsonMap(<String, Object?>{
    'k': 'in',
    'h': p.header.toJson(),
    'id': p.playerId,
    'in': <Object?>[for (final c in p.inputs) inputToJson(c)],
  });
}

InputPacket decodeInputPacket(Uint8List data) {
  final map = decodeJsonMap(data);
  if (packetKind(map) != 'in') {
    throw const FormatException('expected an input packet');
  }
  final header = headerFromMap(map);
  final raw = map['in']! as List<Object?>;
  return InputPacket(
    header: header,
    playerId: map['id']! as int,
    inputs: <InputCommand>[for (final e in raw) inputFromJson(e)],
  );
}
