import '../utils/game_result.dart';

class GameCalculator {
  static const int _funModeCoinsQuota    = 100;
  static const int _funModeDiamondsQuota = 25;

  // ── Modo DIVERSIÓN ────────────────────────────────────────────────────────
  // Casa: 30% del pot. Ganador: 70% del pot. Empate: cada uno recupera 15% de su cuota.
  static const double _funWinPct     = 0.70;
  static const double _funDrawReturn = 0.15;

  // ── Modo APUESTA (diamantes) ───────────────────────────────────────────────
  // Lógica: Jugador A apuesta X + Jugador B apuesta X = pot (2X).
  // Casa cobra 10% del pot → ganador recibe 90% del pot.
  // Empate: cada jugador recupera 90% de su propia apuesta (pierde el 10%).
  static const double _betWinPct     = 0.90; // % del pot que recibe el ganador
  static const double _betDrawReturn = 0.90; // % de su apuesta que recupera cada jugador en empate

  /// Calcula las ganancias para el jugador actual.
  /// Retorna el delta neto (positivo = ganancia, negativo = pérdida).
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

  /// Calcula las ganancias para ambos jugadores y la comisión de la casa.
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
        opponentBetAmount ?? 0,
      );
    } else {
      return _calculateFunModeForBoth(playerResult, useDiamonds);
    }
  }

  // ── Modo apuesta (delta para un jugador) ──────────────────────────────────
  static int _calculateBetMode(GameResultModel result, int betAmount) {
    final pot = betAmount * 2; // pot total entre los dos jugadores
    switch (result) {
      case GameResultModel.win:
        // Ganador recibe 90% del pot. Casa cobra el 10% restante.
        return (pot * _betWinPct).floor();
      case GameResultModel.loss:
        return -betAmount;
      case GameResultModel.draw:
        // Cada jugador recupera 90% de su propia apuesta. Casa cobra el 10%.
        return (betAmount * _betDrawReturn).floor() - betAmount;
    }
  }

  // ── Modo diversión (delta para un jugador) ────────────────────────────────
  static int _calculateFunMode(GameResultModel result, bool useDiamonds) {
    final quota = useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;
    final pot = quota * 2;
    switch (result) {
      case GameResultModel.win:
        // Ganador recibe 70% del pot. Casa cobra el 30%.
        return (pot * _funWinPct).floor();
      case GameResultModel.loss:
        return -quota;
      case GameResultModel.draw:
        return (quota * _funDrawReturn).floor();
    }
  }

  // ── Modo apuesta para ambos jugadores ─────────────────────────────────────
  static Map<String, int> _calculateBetModeForBoth(
    GameResultModel playerResult,
    int playerBetAmount,
    int opponentBetAmount,
  ) {
    final pot = playerBetAmount + opponentBetAmount;
    switch (playerResult) {
      case GameResultModel.win:
        // Ganador recibe 90% del pot. Casa cobra el 10%.
        final winnerPrize = (pot * _betWinPct).floor();
        return {
          'player':          winnerPrize,
          'opponent':        -opponentBetAmount,
          'houseCommission': pot - winnerPrize,
        };
      case GameResultModel.loss:
        final winnerPrize = (pot * _betWinPct).floor();
        return {
          'player':          -playerBetAmount,
          'opponent':        winnerPrize,
          'houseCommission': pot - winnerPrize,
        };
      case GameResultModel.draw:
        // Cada jugador recupera 90% de su propia apuesta. Casa cobra el 10%.
        final playerReturn   = (playerBetAmount   * _betDrawReturn).floor();
        final opponentReturn = (opponentBetAmount * _betDrawReturn).floor();
        return {
          'player':          playerReturn   - playerBetAmount,
          'opponent':        opponentReturn - opponentBetAmount,
          'houseCommission': pot - playerReturn - opponentReturn,
        };
    }
  }

  // ── Modo diversión para ambos jugadores ───────────────────────────────────
  static Map<String, int> _calculateFunModeForBoth(
    GameResultModel playerResult,
    bool useDiamonds,
  ) {
    final quota = useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;
    final pot = quota * 2;
    switch (playerResult) {
      case GameResultModel.win:
        // Ganador recibe 70% del pot. Casa cobra el 30%.
        final winnerPrize = (pot * _funWinPct).floor();
        return {
          'player':          winnerPrize,
          'opponent':        -quota,
          'houseCommission': pot - winnerPrize,
        };
      case GameResultModel.loss:
        final winnerPrize = (pot * _funWinPct).floor();
        return {
          'player':          -quota,
          'opponent':        winnerPrize,
          'houseCommission': pot - winnerPrize,
        };
      case GameResultModel.draw:
        final returnAmount = (quota * _funDrawReturn).floor();
        return {
          'player':          returnAmount,
          'opponent':        returnAmount,
          'houseCommission': pot - (returnAmount * 2),
        };
    }
  }

  /// Cuota fija para modo diversión.
  static int getFunModeQuota(bool useDiamonds) =>
      useDiamonds ? _funModeDiamondsQuota : _funModeCoinsQuota;
}