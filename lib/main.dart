import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sim/sim.dart';

import 'game/doodle_game.dart';
import 'input/game_input.dart';
import 'ui/hud_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _DoodleStrikeAppState extends State<DoodleStrikeApp> {
  late final GameInput _input;
  late final DoodleGame _game;

  @override
  void initState() {
    super.initState();
    _input = GameInput();
    _game = DoodleGame(input: _input, weapons: widget.weapons);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doodle Strike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF161622),
      ),
      home: Scaffold(
        body: Stack(
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
                  _input.isPointerFiring = true;
                },
                onPointerUp: (details) {
                  if (details.kind == PointerDeviceKind.mouse) {
                    _input.isPointerFiring = false;
                  }
                },
                onPointerCancel: (details) {
                  if (details.kind == PointerDeviceKind.mouse) {
                    _input.isPointerFiring = false;
                  }
                },
                child: GameWidget(game: _game),
              ),
              HudOverlay(game: _game, input: _input),
          ],
        ),
      ),
    );
  }

  void _updateAim(Offset cursorPosition) {
    final playerScreen = _game.getPlayer1ScreenPos();
    if (playerScreen != null) {
      _input.updateMouseAim(playerScreen.dx, playerScreen.dy, cursorPosition.dx, cursorPosition.dy);
    } else {
      final size = MediaQuery.of(context).size;
      _input.updateMouseAim(size.width / 2, size.height / 2, cursorPosition.dx, cursorPosition.dy);
    }
  }
}
