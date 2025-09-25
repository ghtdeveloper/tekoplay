import '../utils/game_result.dart';

class GameCalculator {
  static const int _funModeQuota = 100;
  static const double _winBonus = 0.30; // 30%
  static const double _drawReturn = 0.15; // 15%

  /// Calcula las ganancias según el resultado del juego
  /// [result]: GameResultModel (win, loss, draw)
  /// [isBetMode]: true para apuestas, false para diversión
  /// [betAmount]: cantidad apostada (solo para modo apuesta)
  /// Retorna: int con la ganancia/pérdida
  static int calculate({
    required GameResultModel result,
    required bool isBetMode,
    int? betAmount,
  }) {
    final amount = isBetMode ? (betAmount ?? 0) : _funModeQuota;

    switch (result) {
      case GameResultModel.win:
        return amount + (amount * _winBonus).round();
      case GameResultModel.loss:
        return -amount;
      case GameResultModel.draw:
        if (isBetMode) {
          return -(amount * _winBonus).round();
        } else {
          return (amount * _drawReturn).round();
        }
    }
  }
}