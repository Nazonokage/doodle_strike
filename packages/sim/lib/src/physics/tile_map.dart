/// Solid/empty tile grid used for collision. One tile is 1.0 unit; tile
/// (tx, ty) covers [tx, tx+1) x [ty, ty+1). +y is down.
///
/// Anything outside the grid counts as solid so players cannot leave the map.
class TileMap {
  TileMap(
      {required this.width,
      required this.height,
      required List<int> tiles,
      List<({double x, double y})>? spawnPoints})
      : assert(tiles.length == width * height),
        _tiles = List<int>.unmodifiable(tiles),
        spawnPoints = List<({double x, double y})>.unmodifiable(
            spawnPoints ?? const <({double x, double y})>[]);

  /// Build from text rows. `#` is solid, `S` is a spawn (empty tile), anything
  /// else is empty. All rows must have equal length.
  factory TileMap.fromRows(List<String> rows, {double halfHeight = 0.7}) {
    assert(rows.isNotEmpty);
    final w = rows.first.length;
    final tiles = <int>[];
    final spawns = <({double x, double y})>[];
    for (var ty = 0; ty < rows.length; ty++) {
      final row = rows[ty];
      assert(row.length == w, 'row $ty has length ${row.length}, expected $w');
      for (var tx = 0; tx < w; tx++) {
        final c = row[tx];
        tiles.add(c == '#' ? 1 : 0);
        if (c == 'S') {
          // Player center so that feet rest on the bottom edge of this tile.
          spawns.add((x: tx + 0.5, y: ty + 1.0 - halfHeight));
        }
      }
    }
    return TileMap(
        width: w, height: rows.length, tiles: tiles, spawnPoints: spawns);
  }

  final int width;
  final int height;
  final List<({double x, double y})> spawnPoints;
  final List<int> _tiles;

  bool isSolid(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= width || ty >= height) return true;
    return _tiles[ty * width + tx] != 0;
  }
}
