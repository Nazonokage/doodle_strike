---
name: doodle-strike
description: Project guide for Doodle Strike, a Mini Militia-style 2D jetpack shooter built with Flutter + Flame on a pure-Dart simulation, with local Wi-Fi multiplayer first and online later. Use this skill whenever working in this repo on gameplay, jetpack/physics, weapons, projectiles, the simulation, InputCommand, game loop or ticks, netcode, prediction, transport, discovery/lobby, protocol messages, maps, camera, HUD, audio, VFX, bots, or sim tests. Use it even if the user does not mention the project name, any time a change could touch packages/sim, packages/protocol, or the Flame layer.
---

# Doodle Strike

Flutter + Flame game. Host-authoritative multiplayer. One shared pure-Dart simulation runs on the phone host, on clients (prediction), and later on a headless Dart server.

Project docs live in the repo root: `PLAN.md` (decisions, roadmap) and `ARCHITECTURE.md` (technical detail). If this skill and those docs disagree, the docs win; tell the user and propose the fix to whichever is stale.

## Non-negotiable rules

1. **Gameplay state lives only in `packages/sim`.** Flame components are views: they read `WorldState` and draw. They never own position, health, ammo, or cooldowns.
2. **`sim` stays pure and deterministic.** No imports of Flutter, Flame, `dart:ui`, or `dart:io`. No `dart:math` import at all (write `min`/`max` inline; this also bans `sin`, `cos`, `atan2`, `pow`, `exp`), no `DateTime`, no unseeded `Random`, no iteration over unordered collections where order affects results. See `references/sim-rules.md`.
3. **Time is ticks.** 60 Hz fixed step. Durations, cooldowns, and lifetimes are integer tick counts, never seconds or wall-clock.
4. **Input is quantized.** Aim is a 16-bit integer angle; sticks are -127..127 integers; buttons are a bitmask.
5. **Host decides outcomes.** Only the local player's movement is predicted. Damage, death, pickups, and kills are never predicted.
6. **Game code talks to the `Transport` interface**, never to WebSocket classes directly. Use `sendReliable` or `sendUnreliable` deliberately.
7. **Weapons and maps are data files**, not hardcoded constants in logic.
8. **Behavior changes in `sim` need a test and a hash check.** If golden state hashes change, say so explicitly and explain why.
9. **Wire or rules changes bump versions** (protocol version, ruleset version) so mismatched clients are refused at join.
10. **Max 6 players.** Do not design anything that assumes more.

Locked tuning: 60 Hz sim, 20 Hz snapshots, doubles with no trig in sim, QR + room code primary join (mDNS is a bonus), Dart pub workspaces, custom tile/AABB physics (no Forge2D).

## Where does this code go?

| If it is... | Put it in |
|---|---|
| Position, velocity, health, ammo, fuel, cooldowns, collision, damage | `packages/sim` |
| Weapon stats, physics constants | data file loaded into `sim` config |
| Message shapes, serialization, versions | `packages/protocol` |
| Joysticks turning touch into `InputCommand` | `app/lib/input` |
| Sprites, animation, particles, camera, shake | `app/lib/game` (reads sim state and sim events) |
| `Transport` interface and `InMemoryTransport` | `packages/protocol` (the server needs them too) |
| Prediction buffer, interpolation, WebSocket/simulated transports | `app/lib/networking` |
| Menus, lobby, HUD, settings | `app/lib/ui` (Riverpod is fine here, never for gameplay state) |
| Headless host | `server/` (imports `sim` and `protocol` only) |

If unsure, ask: "would a headless server need this to compute the correct result?" If yes, it belongs in `sim`.

## Task playbooks

**Add or tune a weapon.** Edit the weapon data file (times in ticks). Check the schema in `references/gameplay-feel.md`. Add or update a sim test covering fire interval, damage, and lifetime. Do not touch Flame for stats.

**Add a new entity type or game rule.** Add it to `WorldState`, include it in `snapshot()`, `restore()`, and `hash()`, advance it in `Simulation.step`, then add it to the snapshot codec and bump the protocol version. Then add the Flame view.

**Change movement or jetpack.** Change constants in `PhysicsConfig` first. If logic changes, update determinism tests and rerun the replay test. Verify feel on a real device, not only in tests.

**Add a network message.** Decide reliable vs unreliable (state events reliable; inputs and snapshots unreliable). Add to `packages/protocol`, bump version, update both the host and client handlers, and add a codec round-trip test. See `references/netcode.md`.

**Add a map.** Author in Tiled, convert with the map tool to a collision grid plus spawn and pickup points. Validate spawns, reachability, and checksum. See `references/gameplay-feel.md`.

**Add feedback (camera, audio, VFX).** Drive it from sim events or resolved state, never from view-side guesses. Pool objects, cap counts, and provide a reduced-motion path. See `references/gameplay-feel.md`.

**Write a bot.** Bots emit `InputCommand`s through the same pipeline as humans. They never poke sim state directly.

## Before you finish any change

- `dart test` passes in `packages/sim` and `packages/protocol` (run from inside each package dir)
- `bash tools/check_sim_purity.sh` passes (no banned imports or calls in `sim`)
- Determinism: same inputs produce the same per-tick hashes
- If netcode was touched: test under simulated latency and loss, not only on a perfect connection
- If it affects feel: say what to check on a real phone (multi-touch dual stick, frame rate, input latency)
- State clearly what you did not verify

## Open decisions (ask, don't assume)

Art style (stickman vs pixel), reference test devices, game name. If a task depends on one of these, ask the user.

## Reference files

- `references/sim-rules.md`: determinism rules, trig table, PRNG, state hashing, test patterns. Read before editing `packages/sim`.
- `references/netcode.md`: tick rates, channels, prediction and reconciliation, transport, join flow, platform limits. Read before touching networking.
- `references/gameplay-feel.md`: combat timing, weapon schema, camera, audio, VFX, level data. Read for gameplay design and polish work.

## Related skills (use alongside, do not duplicate)

General Flutter/Dart conventions come from the official Flutter and Dart skills and `flutter-ai-rules`. The MengTo game-development skills (combat, camera, audio, VFX, levels) are Three.js-oriented; use their ideas as design checklists, and follow `references/gameplay-feel.md` for how they apply here.
