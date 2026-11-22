import 'dart:convert';

import 'weapon_config.dart';

/// Loads weapon definitions from the JSON data file. Unknown keys throw so a
/// typo cannot silently change combat.
class WeaponCatalog {
  static const Set<String> fields = <String>{
    'id',
    'name',
    'damage',
    'fireIntervalTicks',
    'projectileSpeed',
    'lifetimeTicks',
    'spreadUnits',
    'magazine',
    'reloadTicks',
    'automatic',
    'pellets',
    'projectileRadius',
  };

  static List<WeaponConfig> parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('weapon catalog must be a JSON list');
    }
    if (decoded.isEmpty || decoded.length > 6) {
      throw FormatException('expected 1 to 6 weapons, got ${decoded.length}');
    }
    final weapons = <WeaponConfig>[];
    final seen = <int>{};
    for (final entry in decoded) {
      if (entry is! Map) {
        throw const FormatException('each weapon must be a JSON object');
      }
      final map = Map<String, Object?>.from(entry);
      for (final key in map.keys) {
        if (!fields.contains(key)) {
          throw FormatException('unknown weapon field "$key"');
        }
      }
      for (final key in fields) {
        if (!map.containsKey(key)) {
          throw FormatException('weapon is missing "$key"');
        }
      }
      final weapon = WeaponConfig(
        id: _asInt(map['id'], 'id'),
        name: _asString(map['name'], 'name'),
        damage: _asInt(map['damage'], 'damage'),
        fireIntervalTicks: _asInt(map['fireIntervalTicks'], 'fireIntervalTicks'),
        projectileSpeed: _asDouble(map['projectileSpeed'], 'projectileSpeed'),
        projectileLifetimeTicks: _asInt(map['lifetimeTicks'], 'lifetimeTicks'),
        spreadUnits: _asInt(map['spreadUnits'], 'spreadUnits'),
        magazineSize: _asInt(map['magazine'], 'magazine'),
        reloadTicks: _asInt(map['reloadTicks'], 'reloadTicks'),
        automatic: _asBool(map['automatic'], 'automatic'),
        pellets: _asInt(map['pellets'], 'pellets'),
        projectileRadius: _asDouble(map['projectileRadius'], 'projectileRadius'),
      );
      if (weapon.id <= 0 || !seen.add(weapon.id)) {
        throw FormatException('weapon id ${weapon.id} must be a unique positive int');
      }
      if (weapon.damage <= 0 ||
          weapon.fireIntervalTicks <= 0 ||
          weapon.projectileSpeed <= 0 ||
          weapon.projectileLifetimeTicks <= 0 ||
          weapon.spreadUnits < 0 ||
          weapon.magazineSize <= 0 ||
          weapon.reloadTicks <= 0 ||
          weapon.pellets <= 0 ||
          weapon.projectileRadius <= 0) {
        throw FormatException('weapon "${weapon.name}" has a non-positive stat');
      }
      weapons.add(weapon);
    }
    return List<WeaponConfig>.unmodifiable(weapons);
  }

  static int _asInt(Object? value, String key) {
    if (value is int) return value;
    throw FormatException('$key must be an int');
  }

  static double _asDouble(Object? value, String key) {
    if (value is num) return value.toDouble();
    throw FormatException('$key must be a number');
  }

  static String _asString(Object? value, String key) {
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$key must be a non-empty string');
  }

  static bool _asBool(Object? value, String key) {
    if (value is bool) return value;
    throw FormatException('$key must be a bool');
  }
}
