import 'package:flutter/material.dart';
import 'package:sim/sim.dart';

import 'play_settings.dart';

/// Pre-match setup for the current offline bot match.
class LandingPage extends StatelessWidget {
  const LandingPage({
    super.key,
    required this.settings,
    required this.botDifficulty,
    required this.onSettingsChanged,
    required this.onDifficultyChanged,
    required this.onPlay,
    required this.onSettings,
  });

  final PlaySettings settings;
  final BotDifficulty botDifficulty;
  final ValueChanged<PlaySettings> onSettingsChanged;
  final ValueChanged<BotDifficulty> onDifficultyChanged;
  final VoidCallback onPlay;
  final VoidCallback onSettings;

  static const _ink = Color(0xFFF3EDE2);
  static const _muted = Color(0xFF9AA0B5);
  static const _blue = Color(0xFF1E88E5);
  static const _panel = Color(0xFF1A1B29);
  static const _line = Color(0xFF3A3D52);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161622),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final intro = _intro();
                final setup = _setup();
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 44 : 24,
                    wide ? 34 : 24,
                    wide ? 44 : 24,
                    24,
                  ),
                  children: [
                    _topBar(),
                    SizedBox(height: wide ? 46 : 34),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: intro),
                          const SizedBox(width: 44),
                          Expanded(flex: 9, child: setup),
                        ],
                      )
                    else ...[
                      intro,
                      const SizedBox(height: 30),
                      setup,
                    ],
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'LOCAL MATCH  /  ONE PLAYER + ONE BOT',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: _blue.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.bolt, size: 21, color: _blue),
          ),
          const SizedBox(width: 10),
          const Text(
            'DOODLE STRIKE',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.tune, size: 17),
            label: const Text('Controls'),
            style: TextButton.styleFrom(
                foregroundColor: _muted, minimumSize: const Size(48, 44)),
          ),
        ],
      );

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF66BB6A)),
              SizedBox(width: 8),
              Text(
                'COMBAT LAB  /  OFFLINE',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Doodle\nStrike',
            style: TextStyle(
              color: _ink,
              fontSize: 62,
              height: 0.9,
              fontWeight: FontWeight.w900,
              letterSpacing: -2.8,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Take the arena. Grab a better gun. Stay airborne.',
            style: TextStyle(color: _muted, fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 30),
          const _ModeSummary(),
        ],
      );

  Widget _setup() => DecoratedBox(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MATCH SETUP',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              const Text('Bot level',
                  style: TextStyle(
                      color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Pick how hard it pushes the fight.',
                  style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 12),
              SegmentedButton<BotDifficulty>(
                segments: const [
                  ButtonSegment(
                      value: BotDifficulty.chill, label: Text('Chill')),
                  ButtonSegment(
                      value: BotDifficulty.standard, label: Text('Standard')),
                  ButtonSegment(
                      value: BotDifficulty.sharp, label: Text('Sharp')),
                ],
                selected: {botDifficulty},
                onSelectionChanged: (selection) =>
                    onDifficultyChanged(selection.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  foregroundColor: _muted,
                  selectedForegroundColor: _ink,
                  selectedBackgroundColor: _blue.withValues(alpha: 0.32),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Arena pickups',
                            style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Random guns, new positions each match.',
                            style: TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Text(
                    '${settings.randomGunCount}',
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                value: settings.randomGunCount.toDouble(),
                min: 3,
                max: 7,
                divisions: 2,
                label: '${settings.randomGunCount} guns',
                activeColor: _blue,
                onChanged: (value) => onSettingsChanged(
                  settings.copyWith(randomGunCount: value.round()),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('START MATCH'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: _ink,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                  textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary();

  static const _ink = Color(0xFFF3EDE2);
  static const _muted = Color(0xFF9AA0B5);
  static const _blue = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CURRENT MODE',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.sports_martial_arts, color: _blue, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Practice match',
                      style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('You vs. one bot  ·  Arena 01',
                      style: TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
