

class DominoTile {
  final int left;
  final int right;

  DominoTile(this.left, this.right);

  bool matches(int number) => left == number || right == number;

  DominoTile flipped() => DominoTile(right, left);

  @override
  String toString() => "[$left|$right]";
}
