enum GameResultModel {
  win('win', 'Victoria'),
  loss('loss', 'Derrota'),
  draw('draw', 'Empate');

  const GameResultModel(this.id, this.displayName);

  final String id;
  final String displayName;
}
