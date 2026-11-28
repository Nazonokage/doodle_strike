import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sim/sim.dart';

import 'game/doodle_game.dart';
import 'input/game_input.dart';
import 'ui/hud_overlay.dart';
import 'ui/landing_page.dart';
import 'ui/play_settings.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final raw = await rootBundle.loadString('assets/data/weapons.json');
  final weapons = WeaponCatalog.parse(raw);
  runApp(DoodleStrikeApp(weapons: weapons));
}

class DoodleStrikeApp extends StatefulWidget {
  const DoodleStrikeApp({super.key, required this.weapons});

  final List<WeaponConfig> weapons;

  @override
  State<DoodleStrikeApp> createState() => _DoodleStrikeAppState();
}

enum _Shell { menu, settings, playing }

class _DoodleStrikeAppState extends State<DoodleStrikeApp> {
  _Shell _shell = _Shell.menu;
  PlaySettings _settings = const PlaySettings();
  BotDifficulty _botDifficulty = BotDifficulty.standard;
  GameInput? _input;
  DoodleGame? _game;

  @override
  void dispose() {
    _input?.dispose();
    super.dispose();
  }

  void _play() {
    _input?.dispose();
    final input = GameInput()
      ..moveSensitivity = _settings.moveSensitivity
      ..stickDeadZone = _settings.stickDeadZone;
    setState(() {
      _input = input;
      _game = DoodleGame(
        input: input,
        weapons: widget.weapons,
        screenShake: _settings.screenShake,
        botDifficulty: _botDifficulty,
        randomGunCount: _settings.randomGunCount,
        seed: _matchSeed(),
      );
      _shell = _Shell.playing;
    });
  }

  /// A new seed each Play so the guns land somewhere else. The sim itself
  /// stays deterministic once that seed is chosen.
  int _matchSeed() {
    final seed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    return seed == 0 ? 1 : seed;
  }

  void _leave() {
    _input?.dispose();
    setState(() {
      _input = null;
      _game = null;
      _shell = _Shell.menu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doodle Strike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF161622),
      ),
      home: OrientationBuilder(
        builder: (context, orientation) => orientation == Orientation.portrait
            ? const _LandscapeRequired()
            : Scaffold(body: _body()),
      ),
    );
  }

  Widget _body() {
    final game = _game;
    final input = _input;
    switch (_shell) {
      case _Shell.menu:
        return LandingPage(
          settings: _settings,
          botDifficulty: _botDifficulty,
          onSettingsChanged: (value) => setState(() => _settings = value),
          onDifficultyChanged: (value) =>
              setState(() => _botDifficulty = value),
          onPlay: _play,
          onSettings: () => setState(() => _shell = _Shell.settings),
        );
      case _Shell.settings:
        return SettingsPage(
          settings: _settings,
          onChanged: (value) => setState(() => _settings = value),
          onBack: () => setState(() => _shell = _Shell.menu),
        );
      case _Shell.playing:
        if (game == null || input == null) {
          return LandingPage(
            settings: _settings,
            botDifficulty: _botDifficulty,
            onSettingsChanged: (value) => setState(() => _settings = value),
            onDifficultyChanged: (value) =>
                setState(() => _botDifficulty = value),
            onPlay: _play,
            onSettings: () => setState(() => _shell = _Shell.settings),
          );
        }
        return Stack(
          children: [
            // Mouse aim and fire stay on the playfield. Touch sticks live
            // in the overlay, so dragging them does not also click-fire.
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: (details) {
                if (details.kind == PointerDeviceKind.mouse) {
                  _updateAim(details.position);
                }
              },
              onPointerMove: (details) {
                if (details.kind == PointerDeviceKind.mouse) {
                  _updateAim(details.position);
                }
              },
              onPointerDown: (details) {
                if (details.kind != PointerDeviceKind.mouse) return;
                _updateAim(details.position);
                input.isPointerFiring = true;
              },
              onPointerUp: (details) {
                if (details.kind == PointerDeviceKind.mouse) {
                  input.isPointerFiring = false;
                }
              },
              onPointerCancel: (details) {
                if (details.kind == PointerDeviceKind.mouse) {
                  input.isPointerFiring = false;
                }
              },
              child: GameWidget(game: game),
            ),
            HudOverlay(
              game: game,
              input: input,
              settings: _settings,
              onLeave: _leave,
            ),
          ],
        );
    }
  }

  void _updateAim(Offset cursorPosition) {
    final game = _game;
    final input = _input;
    if (game == null || input == null) return;
    final playerScreen = game.getPlayer1ScreenPos();
    if (playerScreen != null) {
      input.updateMouseAim(playerScreen.dx, playerScreen.dy, cursorPosition.dx,
          cursorPosition.dy);
    } else {
      final size = MediaQuery.of(context).size;
      input.updateMouseAim(size.width / 2, size.height / 2, cursorPosition.dx,
          cursorPosition.dy);
    }
  }
}

class _LandscapeRequired extends StatelessWidget {
  const _LandscapeRequired();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF161622),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, color: Color(0xFF64B5F6), size: 52),
              SizedBox(height: 16),
              Text(
                'Rotate to landscape',
                style: TextStyle(
                  color: Color(0xFFF3EDE2),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Doodle Strike is built for wide-screen play.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9AA0B5), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
