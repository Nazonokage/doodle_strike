import 'package:flutter/material.dart';

import 'control_layout_page.dart';
import 'play_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onBack,
  });

  final PlaySettings settings;
  final ValueChanged<PlaySettings> onChanged;
  final VoidCallback onBack;

  static const _ink = Color(0xFFF3EDE2);
  static const _muted = Color(0xFF9AA0B5);
  static const _blue = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161622),
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onBack,
                    style: TextButton.styleFrom(foregroundColor: _ink),
                    child: const Text('Back'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 0, 4),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                        color: _ink, fontSize: 36, fontWeight: FontWeight.w800),
                  ),
                ),
                const _SectionLabel('Sticks'),
                SwitchListTile(
                  value: settings.lockMoveStick,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(lockMoveStick: value)),
                  activeThumbColor: _blue,
                  title: const Text('Lock move stick',
                      style: TextStyle(color: _ink)),
                  subtitle: const Text(
                    'Fixed in the corner. Off, it appears where your finger lands on the left half.',
                    style: TextStyle(color: _muted),
                  ),
                ),
                SwitchListTile(
                  value: settings.lockAimStick,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(lockAimStick: value)),
                  activeThumbColor: _blue,
                  title: const Text('Lock aim stick',
                      style: TextStyle(color: _ink)),
                  subtitle: const Text(
                    'Fixed in the corner. Off, it appears where your finger lands on the right half.',
                    style: TextStyle(color: _muted),
                  ),
                ),
                _SliderRow(
                  label: 'Move sensitivity',
                  value: settings.moveSensitivity,
                  min: 0.7,
                  max: 1.6,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(moveSensitivity: value)),
                ),
                _SliderRow(
                  label: 'Aim sensitivity',
                  value: settings.aimSensitivity,
                  min: 0.7,
                  max: 1.6,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(aimSensitivity: value)),
                ),
                _SliderRow(
                  label: 'Dead zone',
                  value: settings.stickDeadZone,
                  min: 0.05,
                  max: 0.35,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(stickDeadZone: value)),
                ),
                const _SectionLabel('Controls'),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  title: const Text('Layout, size, and opacity',
                      style: TextStyle(color: _ink)),
                  subtitle: const Text(
                    'Drag the sticks and buttons, then set how big and how see-through they are. The aim stick fires when you hold it.',
                    style: TextStyle(color: _muted),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: _muted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const ControlLayoutPage()),
                    );
                  },
                ),
                const _SectionLabel('Feel'),
                SwitchListTile(
                  value: settings.screenShake,
                  onChanged: (value) =>
                      onChanged(settings.copyWith(screenShake: value)),
                  activeThumbColor: _blue,
                  title:
                      const Text('Screen shake', style: TextStyle(color: _ink)),
                  subtitle: const Text(
                    'Kicks the camera on shots, hits, and deaths.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 0, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9AA0B5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label  ${value.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFFF3EDE2), fontSize: 15),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: const Color(0xFF1E88E5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
