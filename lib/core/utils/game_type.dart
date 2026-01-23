enum GameTypeModel {
  chess('chess', 'Ajedrez'),
  ludo('ludo', 'Ludo'),
  domino('domino', 'Dominó');
  const GameTypeModel(this.id, this.displayName);
  final String id;
  final String displayName;
}