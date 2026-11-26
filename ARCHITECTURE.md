# Doodle Strike – Architecture

Technical reference for the decisions in [PLAN.md](PLAN.md). If this file and the code disagree, fix one of them.

---

## 1. Principles

1. **One simulation, everywhere.** The same pure-Dart `sim` package runs on the phone host, on clients (for prediction), and later on a headless server.
2. **Flame is a view.** It renders `WorldState` and captures input. It never owns gameplay state.
3. **Host is authoritative.** Clients send inputs only, never state.
4. **Fixed timestep.** The sim advances in whole ticks, never by variable `dt`.
5. **Transport is swappable.** Game code talks to an interface, not to WebSockets.
6. **Data over code.** Weapons and maps are data files.

---

## 2. Repository Layout

```
doodle_strike/
├── pubspec.yaml            # workspace root (Dart pub workspaces)
├── packages/
│   ├── sim/                # pure Dart, no Flutter/Flame imports
│   │   └── lib/src/
│   │       ├── world_state.dart
│   │       ├── simulation.dart
│   │       ├── entities/       # player, projectile, pickup
│   │       ├── physics/        # tile/AABB collision, jetpack, gravity
│   │       ├── commands/       # InputCommand
│   │       ├── weapons/        # data-driven weapon defs
│   │       ├── bots/           # bot controllers (emit InputCommands)
│   │       └── math/           # sin/cos lookup tables, fixed-point helpers
│   └── protocol/           # pure Dart
│       └── lib/src/
│           ├── messages.dart
│           ├── codec.dart      # JSON first, binary later
│           ├── version.dart
│           └── transport/      # Transport interface + InMemoryTransport (shared with server)
├── app/                    # Flutter + Flame
│   └── lib/
│       ├── main.dart
│       ├── game/           # Flame components (views), camera, effects
│       ├── input/          # joysticks -> InputCommand
│       ├── networking/     # NetworkManager, WebSocket/simulated transports, prediction
│       ├── ui/             # menus, lobby, HUD, settings
│       └── services/       # audio, storage, settings
├── server/                 # headless Dart host (Phase 4)
├── assets/
│   ├── maps/               # Tiled files
│   └── data/weapons.json
└── tools/                  # map converter, net simulator, replay runner
```

**Dependency rules (enforce in CI):**

```
app    -> sim, protocol
server -> sim, protocol
protocol -> (nothing, or sim types only if needed)
sim    -> (nothing)
```

`sim` must never import `dart:ui`, Flutter, Flame, or `dart:io`.

---

## 3. Data Flow

```
Touch input
   │
   ▼
InputCommand (tick, moveX, moveY, aim, buttons)
   │
   ├── local client: apply to predicted sim immediately
   └── send to host (unreliable, last 3 inputs batched)
                         │
                         ▼
               Host: Simulation.step(tick, inputs)
                         │
                         ▼
                 WorldState (authoritative)
                         │
        every 3rd tick   ▼
           WorldSnapshot ──► clients (unreliable)
                         │
                         ▼
       Client: reconcile local player, interpolate others
                         │
                         ▼
                 Flame renders latest state
```

Offline mode is the same pipeline with the host and the single client in one process and an in-memory transport.

---

## 4. Simulation Package

### 4.1 Core API

```dart
class Simulation {
  Simulation(this.map, this.weapons);

  int get tick;
  WorldState get state;

  /// Advance exactly one tick (1/60 s). Missing inputs repeat the last known.
  void step(Map<PlayerId, InputCommand> inputs);

  /// For prediction: copy and restore full state.
  WorldState snapshot();
  void restore(WorldState s);

  /// Stable hash of the full state for determinism tests and desync checks.
  int hash();
}
```

### 4.2 InputCommand

```dart
class InputCommand {
  final int tick;
  final int moveX;      // -127..127 (quantized joystick)
  final int moveY;      // -127..127
  final int aim;        // 0..65535 (angle as a 16-bit integer)
  final int buttons;    // bitmask: fire, jet, melee, swap, reload
  final int weaponId;
}
```

Inputs are quantized integers so they serialize small and behave identically everywhere.

### 4.3 Determinism rule (D2)

Doubles are fine: IEEE 754 `+ - * /` and `sqrt` give identical results on ARM, x86, and Dart-on-web. What is **not** guaranteed identical across platforms is `sin`, `cos`, `atan2`, `pow`, `exp`.

So inside `sim`:

- Aim is a 16-bit integer angle. Direction vectors come from a precomputed **sin/cos lookup table** that is either **checked in as constants** (generated once by a tool script) or computed with a series using only `+ - * /`. Do not build it at startup with `dart:math` `sin`/`cos`, since that reintroduces the platform differences this rule exists to avoid.
- No `dart:math` import at all in the sim (write `min`/`max` inline). `tools/check_sim_purity.sh` enforces this in CI.
- No iteration over unordered collections where order affects results (use lists or sorted ids).
- No `DateTime`, `Random()` without a seed. Use a seeded PRNG stored in `WorldState`.
- Every test run computes `hash()` per tick; golden hashes are compared across platforms in CI.

If hash tests ever show drift anyway, switch hot paths to fixed-point. The state hash makes that a measured decision, not a guess.

### 4.4 Physics

- Map is a tile grid of solid/empty/one-way tiles.
- Players are AABBs. Move axis by axis, resolve against tiles.
- Jetpack: upward acceleration while held, fuel drains and recharges, capped velocity.
- Projectiles: point or small AABB, stepped per tick, swept against tiles to avoid tunneling.
- Grenades: seeded pickup positions, a 90-tick fuse, tile bounce, radial damage and knockback.
- Unarmed fire punches in the aim direction; airborne targets receive stronger knockback.
- Shield pickups add damage-absorbing shield energy, separate from spawn protection.
- All constants (gravity, thrust, max speed) live in one `PhysicsConfig`.

### 4.5 Weapons (data-driven)

```json
{
  "id": 1,
  "name": "Pistol",
  "damage": 12,
  "fireIntervalTicks": 12,
  "projectileSpeed": 14.0,
  "lifetimeTicks": 90,
  "spreadUnits": 0,
  "magazine": 12,
  "reloadTicks": 90,
  "automatic": false
}
```

Times are in ticks, not seconds, so the sim never touches wall-clock time.

---

## 5. Game Loop (client and host)

```dart
const dt = 1 / 60;
double accumulator = 0;

void onFrame(double frameDt) {
  accumulator += frameDt.clamp(0, 0.25);   // avoid spiral of death
  while (accumulator >= dt) {
    final cmd = input.sample(tick);
    predict(cmd);                           // client: apply locally + send
    sim.step(inputsForThisTick);            // host: authoritative step
    accumulator -= dt;
  }
  final alpha = accumulator / dt;
  render(interpolate(prevState, currState, alpha));
}
```

---

## 5a. Networking

### 5a.1 Rates

| Item | Value |
|---|---|
| Sim | 60 Hz |
| Input send | every tick, last 3 inputs per packet |
| Snapshot | 20 Hz (every 3rd tick) |
| Remote interpolation delay | ~100 ms (2 snapshots) |

### 5a.2 Message channels

| Message | Channel |
|---|---|
| InputCommand, WorldSnapshot | Unreliable (latest wins) |
| JoinRoom, LeaveRoom, Ready, GameStart, GameEnd, PlayerJoined/Left, Kill, Respawn | Reliable |

All packets carry: protocol version, ruleset version, sequence number. Mismatches are rejected at join.

### 5a.3 Transport interface

```dart
abstract class Transport {
  Stream<TransportEvent> get events;   // connected, disconnected, data
  Future<void> start();
  Future<void> stop();

  void sendReliable(PeerId to, Uint8List data);
  void sendUnreliable(PeerId to, Uint8List data);
  void broadcastReliable(Uint8List data);
  void broadcastUnreliable(Uint8List data);
}
```

Implementations:
- `InMemoryTransport` (in `packages/protocol`): offline play and tests
- `WebSocketTransport`: LAN MVP. Both channels ride TCP; unreliable sends drop stale snapshots by sequence number
- `SimulatedTransport`: wraps any transport and adds latency, jitter, loss, reordering
- `UdpTransport` / online: later

### 5a.4 Prediction and reconciliation

1. Client stamps input with tick `t`, applies it to its local sim immediately, stores `(input, predictedState)` in a ring buffer.
2. Snapshot arrives containing `lastProcessedInputTick` for this client.
3. Drop buffered entries up to that tick. Compare the predicted state at that tick with the server state for the local player.
4. If error exceeds epsilon: `restore(serverState)`, then replay remaining buffered inputs.
5. Visual correction: small errors blend over ~100 ms; large errors snap.
6. Only the local player is predicted. Everyone else is interpolated.

Damage, deaths, and pickups are host-decided and never predicted. A predicted cosmetic muzzle flash or tracer is fine.

Lag compensation (rewinding targets for hit checks) is not needed on LAN; revisit for online.

### 5a.5 Discovery and joining

Order of preference:
1. **QR code** containing host IP, port, room id
2. **Room code** (short, resolved on the LAN by the host's lobby broadcast or by entering IP)
3. **Manual IP**
4. **mDNS/NSD** as an automatic bonus, never the only path

Platform requirements:
- iOS: local-network usage description and Bonjour service types in `Info.plist`
- Android: Wi-Fi multicast lock, nearby/Wi-Fi permissions by OS version

---

## 6. Flame Layer

- `GameWidget` hosts a `DoodleGame`.
- `WorldView` reads the latest (interpolated) `WorldState` each frame and updates lightweight view components: `PlayerView`, `ProjectileView`, `PickupView`.
- Views hold only render data (sprite, animation, particle state). Position and health come from the state.
- Camera follows the local player with a slight zoom-out proportional to speed.
- Effects (muzzle flash, hit sparks, jetpack flame) are cosmetic and may be spawned from sim **events**, not from view-owned logic.
- Input widgets (dual joysticks) produce `InputCommand`s; each joystick tracks its own pointer id so both work at once.

---

## 7. Maps

- Authored in **Tiled**; tools convert to a compact collision grid plus spawn points and pickup spawns.
- The sim loads only the grid and point data. Art layers are loaded by the app only.
- Map files carry a version and checksum; the host sends the checksum in the room info so clients can verify they match.

---

## 8. Testing and Debug Tooling

| Tool | Purpose |
|---|---|
| Unit tests on `sim` | Movement, jetpack, projectile, damage, respawn |
| Determinism tests | Same inputs, same per-tick hashes; golden hashes across platforms |
| Replay runner | Record input streams; replay to reproduce a desync |
| Bots | Input-emitting players; allow solo testing and soak tests |
| Network simulator | Latency, jitter, loss, reorder via `SimulatedTransport` |
| Debug overlay | Ping, tick, snapshot size, prediction error, rewind count, entity counts |
| Real-device checklist | Multi-touch dual stick, permission prompts, background behavior |

---

## 9. Online Path (Phase 4)

- `server/` is a headless Dart executable (`dart compile exe`) that runs `Simulation` with `WebSocketTransport` (or UDP).
- The protocol is unchanged. A client connects to a server the same way it connects to a phone host.
- Add: matchmaking, auth, rooms, server-side input validation (rate and range checks), leaderboards.
- Colyseus/Nakama are optional and only for matchmaking/accounts, never for gameplay.

---

## 10. Known Limits

- Web cannot host or use mDNS; it is a client only.
- iOS host pauses when backgrounded.
- TCP head-of-line blocking is accepted for LAN MVP.
- No lag compensation until online.
- Max 6 players in MVP.
