import 'package:doodle_strike/ui/hud_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('layout round trip keeps anchor, scale, and clamps opacity', () {
    final moved = HudLayout.defaults
        .withAnchor(HudLayout.reload, const Offset(0.4, 0.3))
        .withScale(HudLayout.aim, 1.4)
        .withOpacity(0.1);
    final restored = HudLayout.fromJson(moved.toJson());
    expect(restored.anchorOf(HudLayout.reload), const Offset(0.4, 0.3));
    expect(restored.scaleOf(HudLayout.aim), 1.4);
    expect(restored.scaleOf(HudLayout.move), 1);
    expect(restored.placedSize(HudLayout.aim), const Size(196, 196));
    expect(restored.opacity, 0.25);
  });
}
