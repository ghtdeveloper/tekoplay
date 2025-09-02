
class DominoTile {
  final int left;
  final int right;
  final String id;
  bool isPlayed;
  bool isSelected;

  DominoTile({
    required this.left,
    required this.right,
    required this.id,
    this.isPlayed = false,
    this.isSelected = false,
  });

  bool get isDouble => left == right;
  int get total => left + right;

  @override
  String toString() => '[$left|$right]';
}
