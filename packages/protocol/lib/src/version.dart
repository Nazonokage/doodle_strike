/// Bump when the wire format changes in any way.
/// 2: packets carry a kind (`in` or `snap`) and snapshots are on the wire.
/// 3: inputs and snapshot bodies are positional arrays so six players stay
///    under 1.5 KB.
/// 4: snapshots include gun pickups (`gp`, `ng`).
/// 5: players carry two weapon slots (`loadout`, `activeSlot`) and pickups
///    include the rounds left in the gun.
/// 6: snapshots carry shields, grenades, melee cooldowns, knockback, utility
///    pickup types, and grenade projectiles.
const int protocolVersion = 6;

/// Bump when simulation rules or tuning change (physics constants, weapon
/// stats, tick rate). A client and host must agree or the join is refused.
/// 2: walking over a gun pickup equips that weapon and refills its magazine.
/// 3: spawn with a pistol in slot 1 and an empty slot 2. At most two guns.
///    An empty slot fills on contact. Drop swaps with a gun underfoot when
///    both slots are full, otherwise leaves the active gun on the map.
///    `weaponId` 1 and 2 select carried slots, not catalog ids.
/// 4: grenades, energy shields, and unarmed melee are part of combat rules.
const int rulesetVersion = 4;

/// Fixed simulation rate. Locked decision D1.
const int simTickRate = 60;

/// Snapshots go out every Nth tick (60 / 3 = 20 Hz). Locked decision D1.
const int snapshotEveryTicks = 3;

/// Maximum players. Locked decision D3.
const int maxPlayers = 6;
