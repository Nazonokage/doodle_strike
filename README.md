# Doodle Strike

A fast 2D dual-stick jetpack shooter inspired by Mini Militia. Local Wi-Fi multiplayer first, online later. Flutter + Flame on top of a pure-Dart simulation. (Codename only; final name TBD.)

## Status

**Phase 1 offline combat is playable.** Local Wi-Fi (Phase 2) is not built yet.

| Part | State |
|---|---|
| `packages/sim` | 60 Hz tick, jetpack, combat, four data-driven weapons, spawn shield, state hash |
| `packages/protocol` | Versioned packets, JSON codec, `Transport`, `InMemoryTransport`. Tests in the package |
| `lib/` | Flame view, keyboard/mouse, dual sticks, HUD, kill feed. One bot via `InputCommand` |
| Weapons | `assets/data/weapons.json` (rifle, pistol, shotgun, SMG) |
| Phase 2 | Host/client, prediction, lobby: not started |

## Documents

| File | Covers |
|---|---|
| [PLAN.md](PLAN.md) | Goals, locked decisions, roadmap, risks |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Packages, sim API, netcode, transport, testing |
| [docs/SKILLS_DIRECTORY.md](docs/SKILLS_DIRECTORY.md) | Which AI skills to load and where they live |
| [.claude/skills/doodle-strike/](.claude/skills/doodle-strike/SKILL.md) | Project skill that encodes the rules for AI-assisted work |

## Layout

```
doodle_strike/
├── pubspec.yaml            Flutter + Flame game root
├── lib/                    Flame game view, input, and UI HUD
├── android/                Android platform
├── ios/                    iOS platform
├── web/                    Web platform
├── windows/                Windows desktop platform
├── assets/                 images, audio, maps
├── packages/
│   ├── sim/                pure Dart game logic (no Flutter, Flame, dart:math)
│   └── protocol/           messages, codec, versions, Transport interface
├── tools/                  trig table generator, sim purity check
├── docs/
└── .claude/skills/         project skill
```

Rule of thumb: gameplay logic goes in `packages/sim`; Flame only draws it.

## Getting Started

Requires a recent Flutter SDK (Dart 3.6+).

```bash
# 1. Resolve dependencies
flutter pub get

# 2. Run the tests
cd packages/sim && dart test && cd ../..
cd packages/protocol && dart test && cd ../..

# 3. Check sim purity (no banned math/platform calls)
bash tools/check_sim_purity.sh

# 4. Run the game directly
flutter run
# or run in browser:
flutter run -d chrome
```

## Rules of the road

- `packages/sim` imports no Flutter, Flame, `dart:io`, `dart:ui` or `dart:math`. CI enforces it.
- Time in the sim is integer ticks (60 Hz). No wall clock.
- Inputs are quantized integers (`InputCommand`).
- No trig functions in the sim; use `Trig` (checked-in lookup table).
- Changing sim behavior or tuning changes the golden hash in `simulation_test.dart`. Update it deliberately and say why.
- Weapons and maps are data, not code.

## Roadmap

| Phase | Goal |
|---|---|
| 0 | Monorepo, tick loop, state hashing, determinism tests |
| 1 | Offline core feel through the sim pipeline, with a bot (**playable**) |
| 2 | Two devices on Wi-Fi: host/client, prediction, lobby |
| 3 | 6 players, more weapons and maps, polish |
| 4 | Online: headless Dart server, matchmaking, accounts |
| 5 | Content and live ops |

## Known limits

- Web is a client only (cannot host or use mDNS).
- On iOS, hosting pauses when the app is backgrounded.
- LAN transport will be WebSocket (TCP); UDP is planned behind the same interface.

## License

TBD.
