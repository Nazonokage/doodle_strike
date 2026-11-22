# Simulation Rules (`packages/sim`)

Read before editing anything in `packages/sim`.

## Contents
1. Why determinism matters
2. Banned and allowed
3. Trig without `dart:math`
4. Randomness
5. Ordering
6. Time
7. State, snapshot, restore, hash
8. Test patterns

## 1. Why determinism matters

Prediction rewinds and replays inputs. If the client and host compute different results from the same inputs, players see constant corrections or desyncs. Basic IEEE 754 operations (`+ - * /`, `sqrt`) match across ARM, x86, and Dart-on-web. Transcendental functions do not.

## 2. Banned and allowed

| Banned in `sim` | Use instead |
|---|---|
| Any `dart:math` import (`sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `min`, `max`) | `Trig` lookup table (section 3); write `min`/`max` inline |
| `DateTime`, `Stopwatch`, anything wall-clock | Tick counter |
| `Random()` unseeded | Seeded PRNG stored in `WorldState` |
| Iterating `Set` or `Map` where order affects results | Lists, or sort by stable id first |
| `dart:ui`, `dart:io`, Flutter, Flame imports | Nothing; keep `sim` pure |
| Floating-point equality for logic | Epsilon compare, or integer tick counters |

Allowed: `+ - * /`, `abs`, `floor`, `ceil`, `round`, integer math, inline comparisons. (`sqrt` also lives in `dart:math`; if a square root is ever needed, add a deterministic helper in `sim/math` and cover it with tests.) `tools/check_sim_purity.sh` enforces the ban in CI.

## 3. Trig without `dart:math`

Aim is a 16-bit integer angle (0..65535 = 0..360 degrees). Direction comes from a table.

- **Do not build the table at startup using `dart:math` `sin`.** That reintroduces platform differences.
- Either generate the table once with a tool script and **check it in as constants**, or compute it with a series that uses only `+ - * /` so every platform gets identical values.
- Index the table by `angle >> shift`; interpolate linearly with basic ops if finer resolution is needed.
- Add a test that asserts a handful of table entries against hard-coded expected values.

## 4. Randomness

Store a PRNG state (for example an xorshift32 integer) inside `WorldState`. Advance it only inside `step`. Spread, respawn point choice, and pickup spawns all draw from it in a fixed order. The PRNG state must be part of `snapshot`, `restore`, and `hash`.

## 5. Ordering

Process players, projectiles, and pickups in a stable order (ascending id). Never rely on map iteration order. When removing entities during iteration, collect ids then remove after the loop.

## 6. Time

All durations are integer ticks: fire interval, reload, respawn delay, projectile lifetime, invulnerability, fuel recharge delay. Convert seconds to ticks only in data authoring tools, never in sim logic.

## 7. State, snapshot, restore, hash

Everything that influences future ticks must be in `WorldState`. For every new field:

- included in `snapshot()` and `restore()`
- included in `hash()` in a fixed field order
- included in the network snapshot codec (if clients need it)

If a field is missing from `restore`, prediction replays will diverge in subtle ways. That is the most common bug class here.

Hash recipe: fold fields in fixed order with `h = (h * 33 + v) & 0xFFFFFFFF`. Keep every intermediate below 2^53 so the web gives identical results (it does today; the golden hash is verified on both the VM and compiled JavaScript). Quantize doubles before hashing (for example `(x * 1000).round()`), consistently everywhere.

## 8. Test patterns

- **Unit:** one behavior per test (jetpack thrust, fuel drain, wall collision, projectile tunneling at max speed, damage, respawn).
- **Determinism:** run the same recorded input list twice; assert equal per-tick hashes. Keep golden hashes for key scenarios and compare across platforms in CI.
- **Replay:** record inputs from a session, replay in tests, assert final hash. Use to reproduce desyncs.
- **Snapshot round trip:** `restore(snapshot())` then step; result equals stepping without the round trip.
- **Edge cases to always cover:** simultaneous kills, death on respawn tick, fire on the tick of reload completion, spawn blocked by another player, projectile hitting a wall and a player on the same tick.
