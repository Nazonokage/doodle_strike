# Doodle Strike – Project Plan v1.2

**Stack:** Flutter + Flame (rendering only), pure-Dart simulation
**Priority:** Local Wi-Fi PvP first, online PvP later
**Platforms:** Android + iOS (host and client), Web (client only), Desktop later
**Status:** Phase 1 gameplay prototype complete (playable in browser & on mobile)

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical detail and [README.md](README.md) for setup.

---

## 1. Vision

A fast, responsive 2D dual-stick shooter inspired by Mini Militia: jetpack movement, weapon variety, tight local multiplayer on the same Wi-Fi, and a clean path to online play. One codebase for all platforms.

### Measurable MVP criteria

| Criterion | Target |
|---|---|
| Frame rate | 60 fps on the reference mid-range phones (one Android, one iPhone, chosen in Phase 0) |
| Input latency (LAN) | Local visual response under 50 ms (prediction); perceived end-to-end under 100 ms |
| Match stability | 6 players, 10-minute deathmatch, zero desync events |
| Snapshot size | Under 1.5 KB at 6 players (before delta compression) |
| Sim cost | One sim step under 2 ms on the reference phone |
| Resilience | A client disconnect never freezes the other players |

---

## 2. Locked Decisions (v1.2)

| # | Decision | Choice | Revisit if |
|---|---|---|---|
| D1 | Tick model | 60 Hz sim, 20 Hz snapshots | Remote players feel choppy, then try 30 Hz |
| D2 | Sim numbers | `double`, with no `sin`/`cos`/`atan2` inside the sim (see ARCHITECTURE.md §4) | State-hash tests show cross-platform drift |
| D3 | Max players | 6 | Snapshot size or map design can't support it |
| D4 | Join flow | QR + room code primary, manual IP fallback, mDNS as a bonus | mDNS proves reliable on both OSes |
| D5 | Physics | Custom tile/AABB, no Forge2D | Never planned |
| D6 | Monorepo tooling | Dart pub workspaces | Package count or CI needs outgrow it (then melos) |
| D7 | Gameplay state | Lives in `sim` only; Flame components are views | Never |
| D8 | Map format | Tiled, converted to a collision grid | Never planned |

**Still open (decide before end of Phase 1):** art style (stickman vs pixel), reference test devices, game name.
**Deferred:** monetization, P2P fallback.

---

## 3. Core Features

### Gameplay (MVP)

| Feature | Priority |
|---|---|
| Dual virtual joysticks (move + aim) | Must |
| Jetpack flight with gravity and fuel | Must |
| Shooting, projectiles, hit detection | Must |
| Health, death, respawn | Must |
| 4–6 data-driven weapons | Must |
| One complete map | Must |
| Camera follow with slight zoom | Must |
| Weapon pickups | Should |
| Kill feed and score | Should |
| Bots (solo testing and filler) | Should |
| Power-ups, melee | Nice |

### Multiplayer

**Local (priority 1):** authoritative host, discovery, QR/code/IP join, ready-up lobby, client-side prediction with reconciliation, interpolation for remote players, graceful disconnects.

**Online (prepared):** same protocol and same `sim` on a headless Dart server, matchmaking, private rooms, leaderboards, accounts, server-side validation.

### Meta

Main menu, settings (sensitivity, audio, graphics), local stats, color/skin choice, accounts later.

---

## 4. Phased Roadmap

### Phase 0 – Foundations
**Status:** sim and protocol skeletons exist with passing tests (VM and JavaScript produce the same golden hash). The Flame demo shell is written but not yet compiled. Reference devices and art style are still undecided.

- Monorepo with Dart workspaces; CI runs `dart test` on `sim` and `protocol`
- Decide art style and reference devices
- Fixed-step tick loop, `InputCommand`, `WorldState`, state hashing
- Determinism test harness (same inputs produce same hash)

### Phase 1 – Core Feel (offline, through the sim pipeline)
**Status:** Complete. Playable offline combat prototype with bot, weapons, full HUD, particles, and multi-input controls running on 60 Hz deterministic sim.
- Dual joysticks (touch) + Keyboard & Mouse (PC/web), jetpack flight, gravity, shooting, combat arena map, smooth follow camera, HUD, death and respawn
- Deterministic AI bot (Player 2) operating through the standard `InputCommand` pipeline, with Chill, Standard, and Sharp difficulty profiles
- Pre-match setup for bot difficulty and 3/5/7 randomized arena weapon pickups
- Grenades, shield-energy pickups, unarmed punches, and stronger punch knockback against airborne opponents
- **Exit:** 30 sim tests green, determinism verified, full combat feel established.

### Phase 2 – Local Multiplayer Foundation
- Host/client roles, room create/join (QR, code, IP), input send, snapshots, prediction, interpolation, lobby
- Network simulator and debug overlay
- **Exit:** two real devices play without visible desync under simulated 100 ms latency and 5% loss

### Phase 3 – Polish Local
- 6-player support, more weapons and pickups, better maps, kill feed, scoreboard, disconnect handling, settings, audio
- **Exit:** the full MVP criteria table is met

### Phase 4 – Online
- Headless Dart server reusing `sim`, matchmaking, private rooms, accounts, leaderboards, server validation, UDP/relay evaluation

### Phase 5 – Content and Live Ops
- More maps and weapons, game modes, cosmetics, seasons

---

## 5. Platform Notes

| Platform | Role | Limits |
|---|---|---|
| Android | Host + client | Needs multicast lock and Wi-Fi/nearby permissions for discovery |
| iOS | Host + client | Local-network permission prompt; hosting pauses when backgrounded, so keep screen awake and warn players |
| Web | Client only | Cannot host or use mDNS/raw sockets |
| Desktop | Later | Easy once mobile works |

---

## 6. Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter |
| Rendering | Flame (view layer only) |
| Physics | Custom, in `packages/sim` |
| Local net | WebSocket (TCP) behind a reliable/unreliable transport interface; UDP later |
| Online | Headless Dart server; Colyseus/Nakama only for matchmaking/accounts if at all |
| UI state | Riverpod (UI only, never gameplay) |
| Storage | Hive or SharedPreferences |
| Audio | flame_audio |
| Maps | Tiled |
| Auth (later) | Supabase or Firebase |

---

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Prediction feels wrong | High | Fixed tick, replay tests, debug overlay early |
| Sim drifts across platforms | High | No trig in sim, state-hash tests on every platform from Phase 0 |
| TCP head-of-line blocking | Medium | Sequence numbers, drop stale snapshots, transport ready for UDP |
| Discovery unreliable | Medium | QR + code + IP; mDNS is optional |
| iOS permissions / background host | Medium | Test in first week of Phase 2, clear UX |
| Multi-touch dual-stick issues | High | Real-device testing in Phase 1 |
| Low-end performance | High | Profile early, entity budgets |
| Scope creep | High | Strict MVP list above |

---

## 8. Tooling Skills (AI-assisted dev)

Keep the set small; each skill costs context.

1. Official Flutter skills and official Dart skills
2. Flame skills (via the package skills CLI once `flame` is a dependency)
3. One custom project skill that encodes decisions D1–D8 and ARCHITECTURE.md
4. Optional: `evanca/flutter-ai-rules`

Skip Three.js/R3F skills and overlapping cursor-rules repos. **Verify every repo and install command yourself before relying on it**; flags are `--skill` and `--agent`, not `- skill`.

---

## 9. Changelog

- **v1.2.1:** Phase 0 scaffold; `dart:math` banned outright in `sim`; `Transport` interface moved into `packages/protocol`.
- **v1.2:** locked D1–D8; added no-trig rule for the sim; Dart workspaces; QR/code primary join; max 6 players; split into PLAN, README, ARCHITECTURE.
- **v1.1:** fixed-tick netcode spec, shared sim package, Forge2D removed, measurable criteria, tooling.
- **v1.0:** initial plan.
