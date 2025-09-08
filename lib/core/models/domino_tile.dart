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

  DominoTile copy() {
    return DominoTile(
      left: left,
      right: right,
      id: id,
      isPlayed: isPlayed,
      isSelected: isSelected,
    );
  }

  bool canConnectTo(int number) {
    return left == number || right == number;
  }

  int getOppositeNumber(int connectingNumber) {
    if (left == connectingNumber) return right;
    if (right == connectingNumber) return left;
    throw ArgumentError('Esta ficha no puede conectar con el número $connectingNumber');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DominoTile &&
        other.left == left &&
        other.right == right &&
        other.id == id;
  }

  @override
  int get hashCode => left.hashCode ^ right.hashCode ^ id.hashCode;
}