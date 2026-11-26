import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen-relative control anchors, sizes, and opacity. Fractions stay put
/// when the window size changes. This never enters the simulation.
class HudLayout {
  const HudLayout({
    required this.anchors,
    required this.scales,
    this.opacity = 0.82,
  });

  final Map<String, Offset> anchors;

  /// 1 is the control's normal size.
  final Map<String, double> scales;
  final double opacity;

  static const move = 'move';
  static const aim = 'aim';
  static const reload = 'reload';
  static const switchWeapon = 'switch';
  static const drop = 'drop';
  static const grenade = 'grenade';

  static const List<String> controlIds = <String>[
    move,
    aim,
    reload,
    switchWeapon,
    drop,
    grenade,
  ];

  static const Map<String, Size> baseSizes = <String, Size>{
    move: Size(140, 140),
    aim: Size(140, 140),
    reload: Size(72, 64),
    switchWeapon: Size(72, 64),
    drop: Size(72, 64),
    grenade: Size(72, 64),
  };

  static const Map<String, String> labels = <String, String>{
    move: 'MOVE',
    aim: 'AIM',
    reload: 'RELOAD',
    switchWeapon: 'SWITCH',
    drop: 'DROP',
    grenade: 'GRENADE',
  };

  static const HudLayout defaults = HudLayout(
    anchors: <String, Offset>{
      move: Offset(0.16, 0.78),
      aim: Offset(0.84, 0.78),
      reload: Offset(0.86, 0.56),
      switchWeapon: Offset(0.20, 0.58),
      drop: Offset(0.90, 0.42),
      grenade: Offset(0.40, 0.58),
    },
    scales: <String, double>{
      move: 1,
      aim: 1,
      reload: 1,
      switchWeapon: 1,
      drop: 1,
      grenade: 1,
    },
  );

  Offset anchorOf(String id) =>
      anchors[id] ?? defaults.anchors[id] ?? const Offset(0.5, 0.5);

  double scaleOf(String id) => scales[id] ?? 1;

  Size baseSize(String id) => baseSizes[id] ?? const Size(64, 64);

  Size placedSize(String id) {
    final base = baseSize(id);
    final scale = scaleOf(id);
    return Size(base.width * scale, base.height * scale);
  }

  HudLayout withAnchor(String id, Offset anchor) {
    final next = Map<String, Offset>.from(defaults.anchors)..addAll(anchors);
    next[id] =
        Offset(_clamp(anchor.dx, 0.06, 0.94), _clamp(anchor.dy, 0.08, 0.92));
    return HudLayout(anchors: next, scales: scales, opacity: opacity);
  }

  HudLayout withScale(String id, double scale) {
    final next = Map<String, double>.from(defaults.scales)..addAll(scales);
    next[id] = _clamp(scale, 0.7, 1.6);
    return HudLayout(anchors: anchors, scales: next, opacity: opacity);
  }

  HudLayout withOpacity(double value) => HudLayout(
      anchors: anchors, scales: scales, opacity: _clamp(value, 0.25, 1));

  Map<String, Object?> toJson() => <String, Object?>{
        'opacity': opacity,
        'controls': <String, Object?>{
          for (final id in controlIds)
            id: <String, double>{
              'x': anchorOf(id).dx,
              'y': anchorOf(id).dy,
              's': scaleOf(id),
            },
        },
      };

  factory HudLayout.fromJson(Map<String, Object?> json) {
    final anchors = Map<String, Offset>.from(defaults.anchors);
    final scales = Map<String, double>.from(defaults.scales);
    final raw = json['controls'];
    if (raw is Map) {
      for (final id in controlIds) {
        final entry = raw[id];
        if (entry is Map) {
          final x = entry['x'];
          final y = entry['y'];
          final scale = entry['s'];
          if (x is num && y is num) {
            if (id == switchWeapon &&
                x.toDouble() == 0.72 &&
                y.toDouble() == 0.62) {
              continue;
            }
            anchors[id] = Offset(_clamp(x.toDouble(), 0.06, 0.94),
                _clamp(y.toDouble(), 0.08, 0.92));
          }
          if (scale is num) scales[id] = _clamp(scale.toDouble(), 0.7, 1.6);
        }
      }
    }
    final opacity = json['opacity'];
    final layout = HudLayout(anchors: anchors, scales: scales);
    if (opacity is num) return layout.withOpacity(opacity.toDouble());
    return layout;
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

class HudLayoutStore {
  static const storageKey = 'doodle_strike.hud_layout';

  Future<HudLayout> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return HudLayout.defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return HudLayout.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)));
      }
    } on Object {
      return HudLayout.defaults;
    }
    return HudLayout.defaults;
  }

  Future<void> save(HudLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(layout.toJson()));
  }
}
