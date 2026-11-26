import 'package:flutter/material.dart';

import 'hud_layout.dart';

/// Drag, resize, and fade the on-screen controls. Opened from Settings.
/// Nothing here is sent to the simulation.
class ControlLayoutPage extends StatefulWidget {
  const ControlLayoutPage({super.key});

  @override
  State<ControlLayoutPage> createState() => _ControlLayoutPageState();
}

class _ControlLayoutPageState extends State<ControlLayoutPage> {
  final HudLayoutStore _store = HudLayoutStore();
  HudLayout _layout = HudLayout.defaults;
  String _selected = HudLayout.aim;

  static const _ink = Color(0xFFF3EDE2);
  static const _muted = Color(0xFF9AA0B5);
  static const _panel = Color(0xFF1A1B29);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final layout = await _store.load();
    if (!mounted) return;
    setState(() => _layout = layout);
  }

  void _update(HudLayout layout, {bool save = false}) {
    setState(() => _layout = layout);
    if (save) _store.save(layout);
  }

  @override
  Widget build(BuildContext context) {
    final selectedScale = _layout.scaleOf(_selected);
    return ColoredBox(
      color: const Color(0xFF161622),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screen =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      const Positioned(
                        left: 16,
                        top: 8,
                        right: 16,
                        child: Text(
                          'Drag a control. Aim to fire; use the left pad up to jet.',
                          style: TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final id in HudLayout.controlIds)
                        _preview(id, screen),
                    ],
                  );
                },
              ),
            ),
            Material(
              color: _panel,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${HudLayout.labels[_selected]} size  ${selectedScale.toStringAsFixed(2)}',
                      style: const TextStyle(color: _ink, fontSize: 15),
                    ),
                    Slider(
                      value: selectedScale,
                      min: 0.7,
                      max: 1.6,
                      activeColor: const Color(0xFF1E88E5),
                      label: '${HudLayout.labels[_selected]} size',
                      onChanged: (value) => _update(
                          _layout.withScale(_selected, value),
                          save: true),
                    ),
                    Text(
                      'Opacity  ${(_layout.opacity * 100).round()}%',
                      style: const TextStyle(color: _ink, fontSize: 15),
                    ),
                    Slider(
                      value: _layout.opacity,
                      min: 0.25,
                      max: 1,
                      activeColor: const Color(0xFF1E88E5),
                      label: 'Control opacity',
                      onChanged: (value) =>
                          _update(_layout.withOpacity(value), save: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: TextButton.styleFrom(foregroundColor: _ink),
                          child: const Text('Back'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              _update(HudLayout.defaults, save: true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(String id, Size screen) {
    final placed = _layout.placedSize(id);
    final anchor = _layout.anchorOf(id);
    final selected = id == _selected;
    final aim = id == HudLayout.aim;
    return Positioned(
      left: anchor.dx * screen.width - placed.width / 2,
      top: anchor.dy * screen.height - placed.height / 2,
      width: placed.width,
      height: placed.height,
      child: Opacity(
        opacity: _layout.opacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = id),
          onPanStart: (_) => setState(() => _selected = id),
          onPanUpdate: (details) {
            final current = _layout.anchorOf(id);
            _update(
              _layout.withAnchor(
                id,
                Offset(
                  current.dx + details.delta.dx / screen.width,
                  current.dy + details.delta.dy / screen.height,
                ),
              ),
            );
          },
          onPanEnd: (_) => _store.save(_layout),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: aim ? const Color(0x88FF1744) : const Color(0xCC1E88E5),
              borderRadius: BorderRadius.circular(
                  id == HudLayout.move || id == HudLayout.aim ? 999 : 14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFD54F)
                    : const Color(0x66FFFFFF),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                HudLayout.labels[id] ?? id,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
