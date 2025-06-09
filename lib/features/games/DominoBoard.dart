

import '../../core/models/DominoTile.dart';

class DominoBoard {
  List<DominoTile> tiles = [];

  bool canPlay(DominoTile tile) {
    if (tiles.isEmpty) return true;
    int leftEnd = tiles.first.left;
    int rightEnd = tiles.last.right;
    return tile.matches(leftEnd) || tile.matches(rightEnd);
  }

  bool playTile(DominoTile tile) {
    if (tiles.isEmpty) {
      tiles.add(tile);
      return true;
    }

    int leftEnd = tiles.first.left;
    int rightEnd = tiles.last.right;

    if (tile.right == leftEnd) {
      tiles.insert(0, tile);
      return true;
    } else if (tile.left == leftEnd) {
      tiles.insert(0, tile.flipped());
      return true;
    } else if (tile.left == rightEnd) {
      tiles.add(tile);
      return true;
    } else if (tile.right == rightEnd) {
      tiles.add(tile.flipped());
      return true;
    }

    return false;
  }
}
