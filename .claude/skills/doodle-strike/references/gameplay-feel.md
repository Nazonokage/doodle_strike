# Gameplay Feel: Combat, Camera, Audio, VFX, Levels

Adapted for Doodle Strike (2D, Flame, deterministic sim) from the engine-agnostic ideas in the MengTo game-development skills: `design-action-combat`, `build-game-camera-controls`, `build-game-audio-feedback`, `create-game-vfx`, `author-game-levels`. Those skills target Three.js and the browser; the ideas carry over, the implementation details do not.

## Contents
1. Combat
2. Weapon data schema
3. Camera
4. Audio
5. VFX
6. Levels and maps
7. What NOT to copy from the Three.js skills

## 1. Combat

Treat every weapon and action as an explicit tick-based timeline, not an animation guess.

For each action define (in ticks): startup, active window, recovery, cooldown, resource cost (ammo, fuel), contact shape, damage outcome, and the feedback it triggers.

- Outcomes come from sim contact events only. Visuals follow resolved events.
- Resolve each contact once, using stable projectile and target ids.
- Validate state before resolving: shooter alive, target alive, not already hit by this projectile, not in respawn invulnerability.
- Avoid dominant spam: tune fire interval, spread, and ammo so no single weapon wins at every range.
- Reload and weapon swap are vulnerable windows; make that cost visible in feedback.
- Unarmed fire becomes a forward punch: 18 damage, 1.8-tile reach, and a 32-tick recovery. A grounded target gets a small push; an airborne target gets a stronger horizontal and upward impulse.
- A grenade has a 90-tick fuse, bounces off solid tiles, and deals up to 72 damage within a 4.5-tile radius, with damage falling toward the edge.
- Grenade pickups replenish a 3-grenade inventory. Shield pickups add 45 shield energy (100 cap); that energy absorbs incoming damage before health and remains separate from short spawn protection.

Test deterministically: early/late timing boundaries, simultaneous kills, multiple targets in one shot, interrupted reload, fire on cooldown boundary tick, repeated inputs.

## 2. Weapon data schema

All times in ticks (60 per second), distances in sim units.

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
  "automatic": false,
  "recoil": 0.0
}
```

Add fields in the schema and the loader together, and keep unknown-field handling strict so typos fail loudly.

## 3. Camera

The camera is a view concern. It never feeds back into the sim.

- One authoritative target: the local player's interpolated render position.
- Smooth X and Y independently; never bind directly to jittery state.
- Look-ahead toward the aim direction by a small clamped amount so the player sees where they shoot.
- Clamp to map bounds so the void is never shown.
- Slight zoom-out with speed (jetpack), eased, with min and max.
- Shake is a temporary modifier on top of the base camera; scale by distance and honor a reduced-motion setting.
- Verify: tight corners, fast jetpack climbs, respawn jump (snap or quick ease, not a long pan), spectating after death, portrait and landscape.

## 4. Audio

Use `flame_audio`. Audio confirms intent and state, not constant noise.

Cue map to define: input accepted (jet on), fire, hit confirm, damage taken, low health warning, pickup, reload start/end, empty click, death, respawn, kill confirm, match start/end.

- Priority rules so damage-taken and kill-confirm remain audible in crowded fights.
- Cap simultaneous voices; drop or steal the lowest priority.
- Spatial: pan and attenuate remote fire by distance from the local player.
- Respect mute and volume settings; provide visual equivalents for critical cues.
- Cues trigger from sim events, so host and client agree and remote players' sounds are correct.
- Test: first-launch, rapid fire, app backgrounding, headphones plug/unplug, silent switch behavior on iOS.

## 5. VFX

Make gameplay meaning readable first; spectacle second.

For each effect define: trigger event, owner, duration, gameplay meaning, silhouette at normal camera distance, spawn cap, cleanup rule, reduced-motion equivalent.

- Pool short-lived Flame components; reuse sprites and paints; avoid per-frame allocation.
- Cap particles; lower caps on low-quality setting.
- Spawn from sim events (shot fired, projectile hit, death), not from view-side logic.
- Cleanup must be idempotent so respawn, match end, and pause cannot leak effects.
- Jetpack flame, muzzle flash, hit spark, blood/impact, death burst, pickup glow, low-health vignette are the MVP set.

## 6. Levels and maps

Borrow the data discipline from `author-game-levels`, not its flat-plane rule.

Keep layers separate and independently testable:

- authored map data with stable ids (spawn points, pickup spawns, zones)
- art layers (app only, never read by sim)
- collision grid (sim)
- spawn and pickup data (sim)

Rules:
- Never infer collision from decoration.
- Spawn points: choose by distance from enemies, never inside geometry, never overlapping another player; fall back deterministically using the sim PRNG.
- Every pickup and spawn must be reachable with the jetpack; validate in a map test.
- No soft locks: no pocket the jetpack cannot exit; fuel recharge must always be possible.
- Include a map version and checksum; clients verify against the host.
- Readability: platforms and walls must contrast with players and projectiles at phone size.

## 7. What NOT to copy from the Three.js skills

| From the Three.js skill | Why it does not apply |
|---|---|
| "One gameplay plane, no vertical traversal, no platforms or ramps" (`author-game-levels`) | The jetpack makes vertical movement the core of this game |
| Isometric and orbit camera, occlusion fading (`build-game-camera-controls`) | We use a 2D side-view follow camera |
| Browser audio unlock and Web Audio nodes (`build-game-audio-feedback`) | Use `flame_audio` and Flutter platform behavior |
| Three.js materials, shaders, draw-call budgets (`create-game-vfx`) | Use Flame components, sprite batching, and particle caps |
| Lock-on targeting, posture, parry (`design-action-combat`) | Not in MVP; this is a free-aim shooter |
| Local light inventory (`author-game-levels`) | No dynamic local lights in MVP |
