/// Small deterministic PRNG: a 32-bit linear congruential generator.
///
/// Only `*`, `+` and `&` are used and every intermediate stays below 2^53, so
/// results are identical on the VM and on the web. State is a single integer
/// so it is trivial to snapshot, restore and hash.
class Rng {
  Rng(int seed) : state = seed & _mask;

  Rng.fromState(this.state);

  static const int _mask = 0xFFFFFFFF;
  static const int _mul = 1664525;
  static const int _inc = 1013904223;

  /// Current 32-bit state. Part of WorldState hashing.
  int state;

  /// Advance and return the new 32-bit state.
  int nextU32() {
    state = (state * _mul + _inc) & _mask;
    return state;
  }

  /// Uniform-ish int in [0, max). Uses the high 16 bits (low LCG bits are weak).
  int nextInt(int max) {
    assert(max > 0 && max <= 65536);
    return (nextU32() ~/ 65536) % max;
  }

  Rng copy() => Rng.fromState(state);
}
