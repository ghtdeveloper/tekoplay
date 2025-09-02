enum GameTypeModel {
  chess('chess', 'Ajedrez'),
  domino('domino', 'Dominó');

  const GameTypeModel(this.id, this.displayName);
  final String id;
  final String displayName;
}