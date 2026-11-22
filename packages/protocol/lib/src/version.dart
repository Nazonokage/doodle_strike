/// Bump when the wire format changes in any way.
/// 2: packets carry a kind (`in` or `snap`) and snapshots are on the wire.
/// 3: inputs and snapshot bodies are positional arrays so six players stay
///    under 1.5 KB.
const int protocolVersion = 3;

/// Bump when simulation rules or tuning change (physics constants, weapon
/// stats, tick rate). A client and host must agree or the join is refused.
const int rulesetVersion = 1;

/// Fixed simulation rate. Locked decision D1.
const int simTickRate = 60;

/// Snapshots go out every Nth tick (60 / 3 = 20 Hz). Locked decision D1.
const int snapshotEveryTicks = 3;

/// Maximum players. Locked decision D3.
const int maxPlayers = 6;
