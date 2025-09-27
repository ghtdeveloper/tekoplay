import '../utils/game_result.dart';

class GameCalculator {
  static const int _funModeCoinsQuota = 100;    // Monedas para modo diversión
  static const int _funModeDiamondsQuota = 25;  // Diamantes para modo diversión
  static const double _houseCommission = 0.30;  // Comisión de la app (30%)
  static const double _winBonus = 0.70;         // Lo que recibe el ganador del oponente (70%)
  static const double _drawReturn = 0.15;       // Retorno en empate (15%)

  /// Calcula las ganancias para el jugador actual
  /// [result]: GameResultModel (win, loss, draw)
  /// [isBetMode]: true para apuestas, false para diversión
  /// [useDiamonds]: true para diamantes, false para monedas (solo en modo diversión)
  /// [betAmount]: cantidad apostada (solo para modo apuesta)
  /// Retorna: int con la ganancia/pérdida
  static int calculate({
    required GameResultModel result,
    required bool isBetMode,
    int? betAmount,
    bool useDiamonds = true,
  }) {
    if (isBetMode) {
      return _calculateBetMode(result, betAmount ?? 0);
    } else {
      return _calculateFunMode(result, useDiamonds);
    }
  }

  /// Calcula las ganancias para ambos jugadores
  /// Retorna un mapa con las ganancias de cada jugador
  static Map<String, int> calculateForBothPlayers({
    required GameResultModel playerResult,
    required bool isBetMode,
    int? playerBetAmount,
    int? opponentBetAmount,
    bool useDiamonds = true,
  }) {
    if (isBetMode) {
      return _calculateBetModeForBoth(
          playerResult,
          playerBetAmount ?? 0,
          opponentBetAmount ?? 0
      );
    } else {
      return _calculateFunModeForBoth(playerResult, useDiamonds);
    }
  }

  // Modo apuesta para un jugador
  static int _calculateBetMode(GameResultModel result, int betAmount) {
    switch (result) {
      case GameResultModel.win:
      // Recupero mi apuesta + 70% de la apuesta del oponente
        return betAmount + (betAmount * _winBonus).round();
      case GameResultModel.loss:
      // Pierdo toda mi apuesta
        return -betAmount;
      case GameResultModel.draw:
      // En empate, cada jugador recibe 15% de su propia apuesta
        return (betAmount * _drawReturn).round() - betAmount;
    }
  }

  // Modo diversión para un jugador
  static int _calculateFunMode(GameResultModel result, bool useDiamonds) {
    final quota = useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;

    switch (result) {
      case GameResultModel.win:
      // Gano la cuota fija + 70% de la cuota del oponente
        return quota + (quota * _winBonus).round();
      case GameResultModel.loss:
      // Pierdo la cuota fija
        return -quota;
      case GameResultModel.draw:
      // En empate, recibo 15% de la cuota
        return (quota * _drawReturn).round();
    }
  }

  // Modo apuesta para ambos jugadores
  static Map<String, int> _calculateBetModeForBoth(
      GameResultModel playerResult,
      int playerBetAmount,
      int opponentBetAmount
      ) {
    switch (playerResult) {
      case GameResultModel.win:
        return {
          'player': playerBetAmount + (opponentBetAmount * _winBonus).round(),
          'opponent': -opponentBetAmount,
          'houseCommission': (opponentBetAmount * _houseCommission).round(),
        };
      case GameResultModel.loss:
        return {
          'player': -playerBetAmount,
          'opponent': opponentBetAmount + (playerBetAmount * _winBonus).round(),
          'houseCommission': (playerBetAmount * _houseCommission).round(),
        };
      case GameResultModel.draw:
        final playerReturn = (playerBetAmount * _drawReturn).round();
        final opponentReturn = (opponentBetAmount * _drawReturn).round();
        return {
          'player': playerReturn - playerBetAmount,
          'opponent': opponentReturn - opponentBetAmount,
          'houseCommission': (playerBetAmount + opponentBetAmount) - (playerReturn + opponentReturn),
        };
    }
  }

  // Modo diversión para ambos jugadores
  static Map<String, int> _calculateFunModeForBoth(
      GameResultModel playerResult,
      bool useDiamonds
      ) {
    final quota = useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;

    switch (playerResult) {
      case GameResultModel.win:
        return {
          'player': quota + (quota * _winBonus).round(),
          'opponent': -quota,
          'houseCommission': (quota * _houseCommission).round(),
        };
      case GameResultModel.loss:
        return {
          'player': -quota,
          'opponent': quota + (quota * _winBonus).round(),
          'houseCommission': (quota * _houseCommission).round(),
        };
      case GameResultModel.draw:
        final returnAmount = (quota * _drawReturn).round();
        return {
          'player': returnAmount,
          'opponent': returnAmount,
          'houseCommission': (quota * 2) - (returnAmount * 2),
        };
    }
  }

  /// Obtiene la cuota fija para el modo diversión
  static int getFunModeQuota(bool useDiamonds) {
    return useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;
  }
}