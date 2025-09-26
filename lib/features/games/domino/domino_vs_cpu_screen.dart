import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/domino_tile.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../adds/Interstitial_ad_helper.dart';

enum GameState { playerTurn, computerTurn, gameOver, roundEnd }
enum GameResult { playerWins, computerWins, draw, none }
enum Direction { left, right, up, down }
enum RoundResult { playerWon, computerWon, blocked }

class PlayedDominoTile {
  final DominoTile tile;
  final bool isVertical;
  final Offset position;
  final Direction direction;
  final int connectingValue;

  PlayedDominoTile({
    required this.tile,
    required this.isVertical,
    required this.position,
    required this.direction,
    required this.connectingValue,
  });
}

class RoundInfo {
  final int roundNumber;
  final RoundResult result;
  final int playerPoints;
  final int computerPoints;
  final int playerRemainingTiles;
  final int computerRemainingTiles;

  RoundInfo({
    required this.roundNumber,
    required this.result,
    required this.playerPoints,
    required this.computerPoints,
    required this.playerRemainingTiles,
    required this.computerRemainingTiles,
  });
}

class DominoVsComputerController {
  List<DominoTile> playerTiles = [];
  List<DominoTile> computerTiles = [];
  List<PlayedDominoTile> playedTiles = [];
  List<DominoTile> boneyard = [];

  // Valores abiertos en cada dirección
  int? leftEnd;
  int? rightEnd;
  int? topEnd;
  int? bottomEnd;

  GameState gameState = GameState.playerTurn;
  GameResult gameResult = GameResult.none;
  String difficulty = 'muy fácil';

  // Sistema de rondas
  int currentRound = 1;
  int maxRounds = 3;
  int playerRoundWins = 0;
  int computerRoundWins = 0;
  List<RoundInfo> roundHistory = [];

  double boardWidth = 0;
  double boardHeight = 0;

  // Constantes para el tamaño de las fichas (aumentadas para mejor visualización)
  static const double TILE_WIDTH = 50.0; // Aumentar de 45 a 50
  static const double TILE_HEIGHT = 80.0; // Aumentar de 70 a 80
  static const double TILE_SPACING = 4.0; // Aumentar spacing de 3 a 4
  static const double BOARD_MARGIN = 10.0; // Reducir margen de 15 a 10

  // Variables para tracking de bloqueo
  int turnsWithoutPlay = 0;
  bool lastPlayerCouldPlay = true;
  bool lastComputerCouldPlay = true;

  // Control de primera jugada
  bool isFirstMove = true;
  bool canCrossNow = false;

  // Timer variables
  Timer? _turnTimer;
  int timeLeft = 30;
  bool isTimerActive = false;
  Function? onTimeOut;
  Function? onTimeUpdate;

  // Pool variables
  bool canUsePool = true;
  int poolUsageCount = 0;
  int maxPoolUsage = 3; // Máximo 3 usos del pool por ronda

  void initializeGame({required String selectedDifficulty, required int selectedMaxRounds}) {
    difficulty = selectedDifficulty;
    maxRounds = selectedMaxRounds;
    currentRound = 1;
    playerRoundWins = 0;
    computerRoundWins = 0;
    roundHistory.clear();
    gameResult = GameResult.none;
    startNewRound();
  }

  void startNewRound() {
    playerTiles.clear();
    computerTiles.clear();
    playedTiles.clear();
    boneyard.clear();

    turnsWithoutPlay = 0;
    lastPlayerCouldPlay = true;
    lastComputerCouldPlay = true;
    isFirstMove = true;
    canCrossNow = false;
    leftEnd = null;
    rightEnd = null;
    topEnd = null;
    bottomEnd = null;

    // Reset timer and pool
    _stopTimer();
    poolUsageCount = 0;
    canUsePool = true;

    _createDominoSet();
    _dealTiles();

    gameState = _determineFirstPlayer();
  }

  void startTimer() {
    _stopTimer();
    timeLeft = 30;
    isTimerActive = true;

    _turnTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      timeLeft--;
      onTimeUpdate?.call();

      if (timeLeft <= 0) {
        _stopTimer();
        onTimeOut?.call();
      }
    });
  }

  void _stopTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    isTimerActive = false;
  }

  void handleTimeOut() {
    if (gameState == GameState.playerTurn) {
      // Si el jugador no puede jugar, pasa el turno
      if (!hasAvailableMoves(true)) {
        lastPlayerCouldPlay = false;
        turnsWithoutPlay++;
        checkForBlockedGame();

        if (gameState != GameState.gameOver && gameState != GameState.roundEnd) {
          gameState = GameState.computerTurn;
        }
      } else {
        // Si tiene jugadas disponibles pero se quedó sin tiempo, pierde la ronda
        computerRoundWins++;
        _finishRound(RoundResult.computerWon,
            playerTiles.fold(0, (sum, tile) => sum + tile.total),
            computerTiles.fold(0, (sum, tile) => sum + tile.total));
      }
    }
  }

  bool canDrawFromPool() {
    return canUsePool && poolUsageCount < maxPoolUsage && boneyard.isNotEmpty;
  }

  bool drawFromPool() {
    if (!canDrawFromPool()) return false;

    if (boneyard.isNotEmpty) {
      DominoTile drawnTile = boneyard.removeAt(0);
      playerTiles.add(drawnTile);
      poolUsageCount++;

      // Si ya no puede usar más el pool en esta ronda
      if (poolUsageCount >= maxPoolUsage) {
        canUsePool = false;
      }

      return true;
    }
    return false;
  }

  GameState _determineFirstPlayer() {
    DominoTile? playerHighestDouble;
    DominoTile? computerHighestDouble;

    for (var tile in playerTiles) {
      if (tile.isDouble && (playerHighestDouble == null || tile.left > playerHighestDouble.left)) {
        playerHighestDouble = tile;
      }
    }

    for (var tile in computerTiles) {
      if (tile.isDouble && (computerHighestDouble == null || tile.left > computerHighestDouble.left)) {
        computerHighestDouble = tile;
      }
    }

    if (playerHighestDouble != null && computerHighestDouble != null) {
      return playerHighestDouble.left > computerHighestDouble.left
          ? GameState.playerTurn
          : GameState.computerTurn;
    }

    if (playerHighestDouble != null) return GameState.playerTurn;
    if (computerHighestDouble != null) return GameState.computerTurn;

    DominoTile playerHighest = playerTiles.reduce((a, b) => a.total > b.total ? a : b);
    DominoTile computerHighest = computerTiles.reduce((a, b) => a.total > b.total ? a : b);

    return playerHighest.total >= computerHighest.total
        ? GameState.playerTurn
        : GameState.computerTurn;
  }

  void _createDominoSet() {
    boneyard.clear();

    int id = 0;
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        boneyard.add(DominoTile(
            left: i,
            right: j,
            id: 'tile_${currentRound}_$id'
        ));
        id++;
      }
    }

    boneyard.shuffle(Random());
  }

  void _dealTiles() {
    for (int i = 0; i < 7; i++) {
      playerTiles.add(boneyard.removeAt(0));
      computerTiles.add(boneyard.removeAt(0));
    }
  }

  bool canPlayTile(DominoTile tile) {
    if (playedTiles.isEmpty) return true;

    return tile.canConnectTo(leftEnd!) ||
        tile.canConnectTo(rightEnd!) ||
        (topEnd != null && tile.canConnectTo(topEnd!)) ||
        (bottomEnd != null && tile.canConnectTo(bottomEnd!));
  }

  Direction? getBestDirection(DominoTile tile) {
    if (playedTiles.isEmpty) return Direction.left;

    List<Direction> validDirections = [];

    // Verificar conexión izquierda
    if (leftEnd != null && tile.canConnectTo(leftEnd!)) {
      final leftmostTile = _getLeftmostTile();
      final newPosition = _calculateNewPosition(leftmostTile, Direction.left);
      if (_isPositionValid(newPosition, tile.isDouble)) {
        validDirections.add(Direction.left);
      }
    }

    // Verificar conexión derecha
    if (rightEnd != null && tile.canConnectTo(rightEnd!)) {
      final rightmostTile = _getRightmostTile();
      final newPosition = _calculateNewPosition(rightmostTile, Direction.right);
      if (_isPositionValid(newPosition, tile.isDouble)) {
        validDirections.add(Direction.right);
      }
    }

    // Verificar conexiones verticales (simplificado)
    if (canCrossNow && playedTiles.length >= 3) {
      final centerTile = _findCenterDoubleTile();
      if (centerTile != null) {
        // Permitir cualquier ficha que conecte con el doble central
        if (tile.canConnectTo(centerTile.tile.left)) {
          if (topEnd == null) {
            final newPosition = Offset(
                centerTile.position.dx,
                centerTile.position.dy - DominoVsComputerController.TILE_HEIGHT - DominoVsComputerController.TILE_SPACING
            );
            if (_isPositionValid(newPosition, false)) {
              validDirections.add(Direction.up);
            }
          }

          if (bottomEnd == null) {
            final newPosition = Offset(
                centerTile.position.dx,
                centerTile.position.dy + DominoVsComputerController.TILE_HEIGHT + DominoVsComputerController.TILE_SPACING
            );
            if (_isPositionValid(newPosition, false)) {
              validDirections.add(Direction.down);
            }
          }
        }
      }
    }

    if (validDirections.isEmpty) return null;

    // Priorizar direcciones horizontales para mejor flujo de juego
    if (validDirections.contains(Direction.left)) return Direction.left;
    if (validDirections.contains(Direction.right)) return Direction.right;
    if (validDirections.contains(Direction.up)) return Direction.up;
    if (validDirections.contains(Direction.down)) return Direction.down;

    return validDirections.first;
  }

  int _calculatePointsForDirection(DominoTile tile, Direction direction) {
    int? newLeft = leftEnd, newRight = rightEnd, newTop = topEnd, newBottom = bottomEnd;

    switch (direction) {
      case Direction.left:
        newLeft = tile.getOppositeNumber(leftEnd!);
        break;
      case Direction.right:
        newRight = tile.getOppositeNumber(rightEnd!);
        break;
      case Direction.up:
        final centerTile = _findCenterDoubleTile();
        if (centerTile != null) {
          newTop = tile.getOppositeNumber(centerTile.tile.left);
        }
        break;
      case Direction.down:
        final centerTile = _findCenterDoubleTile();
        if (centerTile != null) {
          newBottom = tile.getOppositeNumber(centerTile.tile.left);
        }
        break;
    }

    return _calculatePotentialPoints(newLeft, newRight, newTop, newBottom);
  }

  PlayedDominoTile? _findCenterDoubleTile() {
    for (var tile in playedTiles) {
      if (tile.tile.isDouble &&
          tile.position.dx > boardWidth * 0.3 &&
          tile.position.dx < boardWidth * 0.7) {
        return tile;
      }
    }
    return null;
  }

  int _calculatePotentialPoints(int? left, int? right, int? top, int? bottom) {
    int sum = 0;
    if (left != null) sum += left;
    if (right != null && right != left) sum += right;
    if (top != null) sum += top;
    if (bottom != null) sum += bottom;

    return (sum % 5 == 0 && sum > 0) ? sum : 0;
  }

  bool _isPositionValid(Offset position, bool isVertical) {
    double width = isVertical ? TILE_HEIGHT : TILE_WIDTH;
    double height = isVertical ? TILE_WIDTH : TILE_HEIGHT;

    return position.dx >= BOARD_MARGIN &&
        position.dx + width <= boardWidth - BOARD_MARGIN &&
        position.dy >= BOARD_MARGIN &&
        position.dy + height <= boardHeight - BOARD_MARGIN;
  }

  bool playTileAutomatically(DominoTile tile) {
    if (!canPlayTile(tile)) return false;

    Direction? direction = getBestDirection(tile);
    if (direction == null) return false;

    if (playedTiles.isEmpty) {
      _playFirstTile(tile, true);
    } else {
      _placeTileAtDirection(tile, direction);
    }

    tile.isPlayed = true;
    playerTiles.remove(tile);

    turnsWithoutPlay = 0;
    lastPlayerCouldPlay = true;

    if (playedTiles.length >= 3) {
      canCrossNow = true;
    }

    _checkRoundEnd();
    return true;
  }

  void _playFirstTile(DominoTile tile, bool isPlayer) {
    final centerPosition = Offset(
        (boardWidth / 2) - (TILE_WIDTH / 2),
        (boardHeight / 2) - (TILE_HEIGHT / 2)
    );

    // Aplicar nueva regla: dobles verticales, no dobles horizontales
    bool shouldBeVertical = tile.isDouble;

    playedTiles.add(PlayedDominoTile(
      tile: tile,
      isVertical: shouldBeVertical,
      position: centerPosition,
      direction: Direction.left,
      connectingValue: tile.left,
    ));

    leftEnd = tile.left;
    rightEnd = tile.right;

    if (tile.isDouble) {
      topEnd = null;
      bottomEnd = null;
    }

    tile.isPlayed = true;
    isFirstMove = false;

    if (isPlayer) {
      playerTiles.remove(tile);
    } else {
      computerTiles.remove(tile);
    }
  }

  void _placeTileAtDirection(DominoTile tile, Direction direction) {
    Offset newPosition;
    bool isVertical = false;
    int connectingValue;

    switch (direction) {
      case Direction.left:
        final leftmostTile = _getLeftmostTile();
        newPosition = _calculateNewPosition(leftmostTile, direction);
        connectingValue = leftEnd!;
        leftEnd = tile.getOppositeNumber(connectingValue);
        // Aplicar nueva regla: dobles verticales, no dobles horizontales
        isVertical = tile.isDouble;
        break;

      case Direction.right:
        final rightmostTile = _getRightmostTile();
        newPosition = _calculateNewPosition(rightmostTile, direction);
        connectingValue = rightEnd!;
        rightEnd = tile.getOppositeNumber(connectingValue);
        // Aplicar nueva regla: dobles verticales, no dobles horizontales
        isVertical = tile.isDouble;
        break;

      case Direction.up:
        final centerTile = _findCenterDoubleTile()!;
        newPosition = Offset(
            centerTile.position.dx,
            centerTile.position.dy - TILE_HEIGHT - TILE_SPACING
        );
        connectingValue = centerTile.tile.left;
        topEnd = tile.getOppositeNumber(connectingValue);
        // En dirección vertical siempre son horizontales las fichas conectadas
        isVertical = false;
        break;

      case Direction.down:
        final centerTile = _findCenterDoubleTile()!;
        newPosition = Offset(
            centerTile.position.dx,
            centerTile.position.dy + TILE_HEIGHT + TILE_SPACING
        );
        connectingValue = centerTile.tile.left;
        bottomEnd = tile.getOppositeNumber(connectingValue);
        // En dirección vertical siempre son horizontales las fichas conectadas
        isVertical = false;
        break;
    }

    playedTiles.add(PlayedDominoTile(
      tile: tile,
      isVertical: isVertical,
      position: newPosition,
      direction: direction,
      connectingValue: connectingValue,
    ));
  }

  bool hasAvailableMoves(bool isPlayer) {
    List<DominoTile> tiles = isPlayer ? playerTiles : computerTiles;
    if (tiles.isEmpty) return false;

    for (var tile in tiles) {
      if (canPlayTile(tile)) {
        return true;
      }
    }
    return false;
  }

  void checkForBlockedGame() {
    bool playerCanPlay = hasAvailableMoves(true);
    bool computerCanPlay = hasAvailableMoves(false);

    if (!playerCanPlay && gameState == GameState.playerTurn) {
      lastPlayerCouldPlay = false;
      turnsWithoutPlay++;
    }

    if (!computerCanPlay && gameState == GameState.computerTurn) {
      lastComputerCouldPlay = false;
      turnsWithoutPlay++;
    }

    if (!playerCanPlay && !computerCanPlay) {
      _endBlockedRound();
    }

    if (turnsWithoutPlay >= 2 && !lastPlayerCouldPlay && !lastComputerCouldPlay) {
      _endBlockedRound();
    }
  }

  void _endBlockedRound() {
    int playerPoints = playerTiles.fold(0, (sum, tile) => sum + tile.total);
    int computerPoints = computerTiles.fold(0, (sum, tile) => sum + tile.total);

    RoundResult roundResult;
    if (playerPoints < computerPoints) {
      roundResult = RoundResult.playerWon;
      playerRoundWins++;
    } else if (computerPoints < playerPoints) {
      roundResult = RoundResult.computerWon;
      computerRoundWins++;
    } else {
      roundResult = RoundResult.blocked;
    }

    _finishRound(roundResult, playerPoints, computerPoints);
  }

  void _finishRound(RoundResult result, int playerRemainingPoints, int computerRemainingPoints) {
    _stopTimer(); // Detener timer al finalizar ronda

    roundHistory.add(RoundInfo(
      roundNumber: currentRound,
      result: result,
      playerPoints: playerRemainingPoints,
      computerPoints: computerRemainingPoints,
      playerRemainingTiles: playerTiles.length,
      computerRemainingTiles: computerTiles.length,
    ));

    if (currentRound >= maxRounds || playerRoundWins > maxRounds ~/ 2 || computerRoundWins > maxRounds ~/ 2) {
      _endGame();
    } else {
      gameState = GameState.roundEnd;
    }
  }

  void _endGame() {
    _stopTimer(); // Asegurar que el timer esté detenido

    if (playerRoundWins > computerRoundWins) {
      gameResult = GameResult.playerWins;
    } else if (computerRoundWins > playerRoundWins) {
      gameResult = GameResult.computerWins;
    } else {
      gameResult = GameResult.draw;
    }
    gameState = GameState.gameOver;
  }

  void startNextRound() {
    currentRound++;
    startNewRound();
  }

  PlayedDominoTile _getLeftmostTile() {
    return playedTiles.where((t) => t.direction == Direction.left || t.direction == Direction.right)
        .reduce((a, b) => a.position.dx < b.position.dx ? a : b);
  }

  PlayedDominoTile _getRightmostTile() {
    return playedTiles.where((t) => t.direction == Direction.left || t.direction == Direction.right)
        .reduce((a, b) => a.position.dx > b.position.dx ? a : b);
  }

  Offset _calculateNewPosition(PlayedDominoTile referenceTile, Direction direction) {
    double newX, newY;

    switch (direction) {
      case Direction.left:
      // Ajustar para fichas dobles que pueden ser verticales
        double referenceWidth = referenceTile.isVertical ? TILE_HEIGHT : TILE_WIDTH;
        newX = referenceTile.position.dx - TILE_WIDTH - TILE_SPACING;
        newY = referenceTile.position.dy;
        break;
      case Direction.right:
      // Ajustar para fichas dobles que pueden ser verticales
        double referenceWidth = referenceTile.isVertical ? TILE_HEIGHT : TILE_WIDTH;
        newX = referenceTile.position.dx + referenceWidth + TILE_SPACING;
        newY = referenceTile.position.dy;
        break;
      case Direction.up:
        newX = referenceTile.position.dx;
        newY = referenceTile.position.dy - TILE_HEIGHT - TILE_SPACING;
        break;
      case Direction.down:
        newX = referenceTile.position.dx;
        newY = referenceTile.position.dy + TILE_HEIGHT + TILE_SPACING;
        break;
    }

    return Offset(newX, newY);
  }

  void _checkRoundEnd() {
    if (playerTiles.isEmpty) {
      playerRoundWins++;
      _finishRound(RoundResult.playerWon, 0, computerTiles.fold(0, (sum, tile) => sum + tile.total));
      return;
    }

    if (computerTiles.isEmpty) {
      computerRoundWins++;
      _finishRound(RoundResult.computerWon, playerTiles.fold(0, (sum, tile) => sum + tile.total), 0);
      return;
    }

    checkForBlockedGame();
  }

  DominoTile? getBestComputerMove() {
    List<DominoTile> playableTiles = computerTiles.where((tile) => canPlayTile(tile)).toList();

    if (playableTiles.isEmpty) {
      lastComputerCouldPlay = false;
      turnsWithoutPlay++;
      return null;
    }

    lastComputerCouldPlay = true;
    turnsWithoutPlay = 0;

    switch (difficulty) {
      case 'muy fácil':
        return _getEasyMove(playableTiles);
      case 'normal':
        return _getMediumMove(playableTiles);
      case 'difícil':
        return _getHardMove(playableTiles);
      default:
        return _getMediumMove(playableTiles);
    }
  }

  DominoTile _getEasyMove(List<DominoTile> playableTiles) {
    return playableTiles[Random().nextInt(playableTiles.length)];
  }

  DominoTile _getMediumMove(List<DominoTile> playableTiles) {
    List<DominoTile> scoringTiles = [];

    for (var tile in playableTiles) {
      Direction? direction = getBestDirection(tile);
      if (direction != null) {
        int points = _calculatePointsForDirection(tile, direction);
        if (points > 0) {
          scoringTiles.add(tile);
        }
      }
    }

    if (scoringTiles.isNotEmpty) {
      return scoringTiles[Random().nextInt(scoringTiles.length)];
    }

    // Si no hay fichas que den puntos, jugar la de mayor valor
    playableTiles.sort((a, b) => b.total.compareTo(a.total));
    return playableTiles.first;
  }

  DominoTile _getHardMove(List<DominoTile> playableTiles) {
    DominoTile? bestTile;
    int maxPoints = -1;

    for (var tile in playableTiles) {
      Direction? direction = getBestDirection(tile);
      if (direction != null) {
        int points = _calculatePointsForDirection(tile, direction);
        if (points > maxPoints) {
          maxPoints = points;
          bestTile = tile;
        }
      }
    }

    if (bestTile != null && maxPoints > 0) {
      return bestTile;
    }

    // Priorizar dobles
    var doubles = playableTiles.where((tile) => tile.isDouble).toList();
    if (doubles.isNotEmpty) {
      doubles.sort((a, b) => b.total.compareTo(a.total));
      return doubles.first;
    }

    // Jugar la ficha de mayor valor
    playableTiles.sort((a, b) => b.total.compareTo(a.total));
    return playableTiles.first;
  }

  bool playComputerTile(DominoTile tile) {
    if (!canPlayTile(tile)) return false;

    Direction? direction = getBestDirection(tile);
    if (direction == null) return false;

    if (playedTiles.isEmpty) {
      _playFirstTile(tile, false);
    } else {
      _placeTileAtDirection(tile, direction);
    }

    tile.isPlayed = true;
    computerTiles.remove(tile);

    turnsWithoutPlay = 0;
    lastComputerCouldPlay = true;

    if (playedTiles.length >= 3) {
      canCrossNow = true;
    }

    _checkRoundEnd();
    return true;
  }

  void setBoardDimensions(double width, double height) {
    boardWidth = width;
    boardHeight = height;
  }

  void dispose() {
    _stopTimer();
  }
}

class DominoVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;

  const DominoVsComputerScreen(this.selectedDifficulty, {super.key});

  @override
  State<DominoVsComputerScreen> createState() => _DominoVsComputerScreenState();
}

class _DominoVsComputerScreenState extends State<DominoVsComputerScreen>
    with TickerProviderStateMixin {
  final DominoVsComputerController _controller = DominoVsComputerController();
  bool _isLoading = false;
  DateTime? _gameStartTime;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  late InterstitialAdHelper _interstitialHelper;

  // Animaciones
  late AnimationController _pointsAnimationController;
  late Animation<double> _pointsScaleAnimation;
  late Animation<double> _pointsOpacityAnimation;
  String _animatedPoints = '';
  bool _showPointsAnimation = false;

  @override
  void initState() {
    super.initState();

    _pointsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pointsScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _pointsAnimationController,
      curve: Curves.elasticOut,
    ));

    _pointsOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pointsAnimationController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    // Configurar callbacks del timer
    _controller.onTimeOut = _handleTimeOut;
    _controller.onTimeUpdate = () {
      if (mounted) setState(() {});
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRoundSelectionDialog();
    });
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
  }

  @override
  void dispose() {
    _pointsAnimationController.dispose();
    _interstitialHelper.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTimeOut() {
    if (mounted) {
      _controller.handleTimeOut();

      if (_controller.gameState == GameState.roundEnd) {
        _showRoundEndDialog();
      } else if (_controller.gameState == GameState.gameOver) {
        _showGameOverDialog();
      } else if (_controller.gameState == GameState.computerTurn) {
        _showSnack("Se acabó el tiempo. Turno del CPU", isSuccess: false);
        _checkComputerTurn();
      }

      setState(() {});
    }
  }

  void _showRoundSelectionDialog() {
    _interstitialHelper.showAdIfReady(onComplete: () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Selecciona las rondas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¿Al mejor de cuántas rondas quieres jugar?',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRoundButton(3),
                  _buildRoundButton(5),
                  _buildRoundButton(7),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRoundButton(int rounds) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _initializeGameWithDimensions(rounds);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const ui.Color(0xFFEC7A34),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        'Mejor\nde $rounds',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _initializeGameWithDimensions(int maxRounds) {
    final size = MediaQuery.of(context).size;
    // Aumentar significativamente el área del tablero
    _controller.setBoardDimensions(size.width - 20, 350); // Más ancho y más alto
    _controller.initializeGame(
      selectedDifficulty: widget.selectedDifficulty,
      selectedMaxRounds: maxRounds,
    );
    _gameStartTime = DateTime.now();
    setState(() {});

    if (_controller.gameState == GameState.computerTurn) {
      _checkComputerTurn();
    } else if (_controller.gameState == GameState.playerTurn) {
      _controller.startTimer();
    }
  }

  void _checkComputerTurn() async {
    if (_controller.gameState == GameState.computerTurn) {
      // Delay basado en la dificultad
      int delayMs = 200; // base
      switch (_controller.difficulty) {
        case 'muy fácil':
          delayMs = 200;
          break;
        case 'normal':
          delayMs = 300;
          break;
        case 'difícil':
          delayMs = 400;
          break;
      }
      await Future.delayed(Duration(milliseconds: delayMs));
      _makeComputerMove();
    }
  }

  void _makeComputerMove() async {
    setState(() => _isLoading = true);

    final computerMove = _controller.getBestComputerMove();

    if (computerMove != null) {
      bool played = _controller.playComputerTile(computerMove);

      if (played) {
        setState(() {
          if (_controller.gameState != GameState.roundEnd && _controller.gameState != GameState.gameOver) {
            _controller.gameState = GameState.playerTurn;
            _controller.startTimer(); // Iniciar timer para jugador
          }
        });
      }
    } else {
      _controller.checkForBlockedGame();

      if (_controller.gameState == GameState.roundEnd) {
        _showRoundEndDialog();
      } else if (_controller.gameState == GameState.gameOver) {
        _showGameOverDialog();
      } else if (_controller.gameState != GameState.gameOver) {
        setState(() {
          _controller.gameState = GameState.playerTurn;
          _controller.startTimer(); // Iniciar timer para jugador
        });
        _showSnack("CPU no puede jugar, es tu turno");
      }
    }

    setState(() => _isLoading = false);

    if (_controller.gameState == GameState.roundEnd) {
      _showRoundEndDialog();
    } else if (_controller.gameState == GameState.gameOver) {
      _showGameOverDialog();
    }
  }

  void _onTileSelected(DominoTile tile) {
    if (_controller.gameState != GameState.playerTurn) return;

    // Verificar si la ficha se puede jugar
    if (!_controller.canPlayTile(tile)) {
      // Mostrar mensaje más específico sobre por qué no se puede jugar
      String message = _getCannotPlayMessage(tile);
      _showSnack(message);
      return;
    }

    // Intentar obtener la dirección óptima
    Direction? direction = _controller.getBestDirection(tile);
    if (direction == null) {
      _showSnack("No hay espacio disponible para colocar esta ficha");
      return;
    }

    bool played = _controller.playTileAutomatically(tile);

    if (played) {
      _controller._stopTimer(); // Detener timer del jugador
      setState(() {
        _controller.gameState = GameState.computerTurn;
      });

      if (_controller.gameState == GameState.roundEnd) {
        _showRoundEndDialog();
      } else if (_controller.gameState == GameState.gameOver) {
        _showGameOverDialog();
      } else {
        _checkComputerTurn();
      }
    } else {
      _showSnack("Error interno al colocar la ficha. Intenta otra.");
    }
  }

  String _getCannotPlayMessage(DominoTile tile) {
    if (_controller.playedTiles.isEmpty) {
      return "Puedes jugar cualquier ficha para empezar";
    }

    List<int> availableEnds = [];
    if (_controller.leftEnd != null) availableEnds.add(_controller.leftEnd!);
    if (_controller.rightEnd != null) availableEnds.add(_controller.rightEnd!);
    if (_controller.topEnd != null) availableEnds.add(_controller.topEnd!);
    if (_controller.bottomEnd != null) availableEnds.add(_controller.bottomEnd!);

    return "Esta ficha (${tile.left}|${tile.right}) no conecta con los extremos disponibles: ${availableEnds.join(', ')}";
  }


  void _drawFromPool() {
    if (!_controller.canDrawFromPool()) {
      if (_controller.poolUsageCount >= _controller.maxPoolUsage) {
        _showSnack("Ya usaste el pool ${_controller.maxPoolUsage} veces en esta ronda");
      } else {
        _showSnack("No hay fichas en el pool");
      }
      return;
    }

    bool drawn = _controller.drawFromPool();
    if (drawn) {
      setState(() {});
      _showSnack("Ficha tomada del pool. Usos restantes: ${_controller.maxPoolUsage - _controller.poolUsageCount}",
          isSuccess: true);
    }
  }

  void _passTurn() {
    if (_controller.gameState != GameState.playerTurn) return;

    if (!_controller.hasAvailableMoves(true)) {
      _controller._stopTimer(); // Detener timer del jugador
      setState(() {
        _controller.lastPlayerCouldPlay = false;
        _controller.turnsWithoutPlay++;
        _controller.checkForBlockedGame();

        if (_controller.gameState == GameState.roundEnd) {
          _showRoundEndDialog();
        } else if (_controller.gameState == GameState.gameOver) {
          _showGameOverDialog();
        } else if (_controller.gameState != GameState.gameOver) {
          _controller.gameState = GameState.computerTurn;
          _showSnack("Turno pasado al CPU");
          _checkComputerTurn();
        }
      });
    } else {
      _showSnack("Tienes jugadas disponibles");
    }
  }

  void _showRoundEndDialog() {
    _controller._stopTimer(); // Asegurar que el timer esté detenido
    final lastRound = _controller.roundHistory.last;
    String title;
    String message;

    switch (lastRound.result) {
      case RoundResult.playerWon:
        title = "¡Ronda ganada!";
        message = 'Has ganado la ronda ${lastRound.roundNumber}\n'
            'Puntos restantes: Tú ${lastRound.playerPoints} - CPU ${lastRound.computerPoints}\n'
            'Marcador: ${_controller.playerRoundWins} - ${_controller.computerRoundWins}';
        break;
      case RoundResult.computerWon:
        title = "Ronda perdida";
        message = 'El CPU ganó la ronda ${lastRound.roundNumber}\n'
            'Puntos restantes: CPU ${lastRound.computerPoints} - Tú ${lastRound.playerPoints}\n'
            'Marcador: ${_controller.playerRoundWins} - ${_controller.computerRoundWins}';
        break;
      case RoundResult.blocked:
        title = "Ronda empatada";
        message = 'Ronda ${lastRound.roundNumber} bloqueada\n'
            'Puntos iguales: ${lastRound.playerPoints}\n'
            'Marcador: ${_controller.playerRoundWins} - ${_controller.computerRoundWins}';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (_controller.currentRound < _controller.maxRounds &&
              _controller.playerRoundWins <= _controller.maxRounds ~/ 2 &&
              _controller.computerRoundWins <= _controller.maxRounds ~/ 2)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _controller.startNextRound();
                  if (_controller.gameState == GameState.computerTurn) {
                    _checkComputerTurn();
                  } else if (_controller.gameState == GameState.playerTurn) {
                    _controller.startTimer();
                  }
                });
              },
              child: Text("Siguiente ronda"),
            ),
          if (_controller.currentRound >= _controller.maxRounds ||
              _controller.playerRoundWins > _controller.maxRounds ~/ 2 ||
              _controller.computerRoundWins > _controller.maxRounds ~/ 2)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showGameOverDialog();
              },
              child: Text("Ver resultado final"),
            ),
        ],
      ),
    );
  }

  Future<void> _recordGameResult(GameResult dominoResult) async {
    if (currentUser == null) {
      return;
    }

    if (_gameStartTime == null) {
      return;
    }

    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      GameResultModel gameResultModel;
      int pointsEarned = 0;

      switch (dominoResult) {
        case GameResult.playerWins:
          gameResultModel = GameResultModel.win;
          pointsEarned = 20 + (_controller.playerRoundWins * 5);
          break;
        case GameResult.computerWins:
          gameResultModel = GameResultModel.loss;
          pointsEarned = -8 + (_controller.playerRoundWins * 2);
          break;
        case GameResult.draw:
          gameResultModel = GameResultModel.draw;
          pointsEarned = 10;
          break;
        case GameResult.none:
          return;
      }

      // Ajustar puntos según dificultad
      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'muy fácil':
          pointsEarned = (pointsEarned * 0.7).round();
          break;
        case 'normal':
          break;
        case 'difícil':
          pointsEarned = (pointsEarned * 1.4).round();
          break;
      }

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.domino,
        result: gameResultModel,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: 'CPU (${widget.selectedDifficulty})',
        additionalData: {
          'difficulty': widget.selectedDifficulty,
          'gameMode': 'vs_computer_rounds',
          'totalRounds': _controller.maxRounds,
          'roundsWon': _controller.playerRoundWins,
          'roundsLost': _controller.computerRoundWins,
          'roundHistory': _controller.roundHistory.map((r) => {
            'round': r.roundNumber,
            'result': r.result.toString(),
            'playerPoints': r.playerPoints,
            'computerPoints': r.computerPoints,
            'playerTiles': r.playerRemainingTiles,
            'computerTiles': r.computerRemainingTiles,
          }).toList(),
        },
      );

    } catch (e) {
      if (kDebugMode) {
        print('Error al registrar la partida: $e');
      }
      if (mounted && currentUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el resultado de la partida'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showGameOverDialog() {
    _controller._stopTimer(); // Asegurar que el timer esté detenido
    String title;
    String message;

    switch (_controller.gameResult) {
      case GameResult.playerWins:
        title = "¡Felicidades!";
        message = '¡Has ganado el juego!\n'
            'Marcador final: ${_controller.playerRoundWins} - ${_controller.computerRoundWins}\n'
            'Total de rondas: ${_controller.roundHistory.length}';
        break;
      case GameResult.computerWins:
        title = "Fin del juego";
        message = 'El CPU ha ganado el juego\n'
            'Marcador final: ${_controller.computerRoundWins} - ${_controller.playerRoundWins}\n'
            'Total de rondas: ${_controller.roundHistory.length}';
        break;
      case GameResult.draw:
        title = "¡Empate!";
        message = 'Juego empatado\n'
            'Marcador final: ${_controller.playerRoundWins} - ${_controller.computerRoundWins}\n'
            'Total de rondas: ${_controller.roundHistory.length}';
        break;
      default:
        return;
    }

    _recordGameResult(_controller.gameResult);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 16),
            Text('Historial de rondas:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ..._controller.roundHistory.map((round) {
              String resultText;
              Color resultColor;
              switch (round.result) {
                case RoundResult.playerWon:
                  resultText = 'Ganaste';
                  resultColor = Colors.green;
                  break;
                case RoundResult.computerWon:
                  resultText = 'Perdiste';
                  resultColor = Colors.red;
                  break;
                case RoundResult.blocked:
                  resultText = 'Empate';
                  resultColor = Colors.orange;
                  break;
              }
              return Text(
                'Ronda ${round.roundNumber}: $resultText (${round.playerPoints}-${round.computerPoints})',
                style: TextStyle(color: resultColor, fontSize: 12),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showRoundSelectionDialog();
            },
            child: Text("Nueva partida"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("Volver"),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    if (currentUser?.photoURL != null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(currentUser!.photoURL!),
        onBackgroundImageError: (exception, stackTrace) {},
        child: currentUser!.photoURL == null
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : null,
      );
    } else {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white,
        child: const Icon(Icons.person, color: Colors.black, size: 20),
      );
    }
  }

  Widget _buildCpuAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[700],
      child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
    );
  }

  Widget _buildTimerWidget() {
    if (!_controller.isTimerActive) return SizedBox.shrink();

    Color timerColor = _controller.timeLeft <= 10 ? Colors.red :
    _controller.timeLeft <= 20 ? Colors.orange : Colors.green;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: timerColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            '${_controller.timeLeft}s',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          'Dominó - Estilo Domino Go',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _showRoundSelectionDialog(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Timer
            if (_controller.gameState == GameState.playerTurn && _controller.isTimerActive)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(child: _buildTimerWidget()),
              ),

            // Marcador de rondas mejorado
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Ronda ${_controller.currentRound} de ${_controller.maxRounds}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildScoreDisplay(
                        'CPU',
                        _controller.computerRoundWins,
                        _controller.gameState == GameState.computerTurn,
                        _buildCpuAvatar(),
                        true,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const ui.Color(0xFFEC7A34),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildScoreDisplay(
                        currentUser?.displayName ?? 'Tú',
                        _controller.playerRoundWins,
                        _controller.gameState == GameState.playerTurn,
                        _buildPlayerAvatar(),
                        true,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fichas restantes: ',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        'CPU ${_controller.computerTiles.length}',
                        style: TextStyle(fontSize: 12, color: Colors.red[600]),
                      ),
                      Text(' - ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(
                        'Tú ${_controller.playerTiles.length}',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Pool info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_in_ar, size: 16, color: Colors.black54),
                      SizedBox(width: 4),
                      Text(
                        'Pool: ${_controller.boneyard.length} fichas',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.casino, size: 16, color: Colors.black54),
                      SizedBox(width: 4),
                      Text(
                        'Usos pool: ${_controller.poolUsageCount}/${_controller.maxPoolUsage}',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dificultad: ${widget.selectedDifficulty}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Área de juego expandida
            Expanded(
              flex: 3, // Cambiar de 2 a 3 para más espacio
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10), // Reducir margen para más espacio
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[900]!, Colors.green[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white38, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _buildPlayArea(),
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón de pool
                  if (_controller.gameState == GameState.playerTurn)
                    ElevatedButton.icon(
                      onPressed: _controller.canDrawFromPool() ? _drawFromPool : null,
                      icon: Icon(Icons.casino),
                      label: Text('Pool'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _controller.canDrawFromPool() ? Colors.blue[700] : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),

                  // Botón de pasar turno
                  if (_controller.gameState == GameState.playerTurn &&
                      !_controller.hasAvailableMoves(true))
                    ElevatedButton.icon(
                      onPressed: _passTurn,
                      icon: Icon(Icons.skip_next),
                      label: Text('Pasar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Fichas del jugador con altura reducida
            Container(
              height: 100, // Reducir de 110 a 100 para dar más espacio al tablero
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown[900]!, Colors.brown[700]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white38, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _buildPlayerTiles(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDisplay(String name, int score, bool isActive, Widget avatar, bool isRounds) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(colors: [Colors.green[200]!, Colors.green[100]!])
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: Colors.green, width: 3) : null,
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            isRounds ? '$score rondas' : '$score pts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 4,
              ),
            ),

          if (_controller.playedTiles.isEmpty && !_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white70,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    _controller.gameState == GameState.playerTurn
                        ? 'Selecciona una ficha para jugar'
                        : 'Esperando jugada del CPU...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Fichas jugadas
          ..._controller.playedTiles.map((playedTile) => Positioned(
            left: playedTile.position.dx,
            top: playedTile.position.dy,
            child: _buildDominoTile(
              playedTile.tile,
              isInPlay: true,
              isVertical: playedTile.isVertical,
            ),
          )),

          // Indicador de estado del juego
          if (_controller.gameState == GameState.playerTurn &&
              !_controller.hasAvailableMoves(true) &&
              _controller.playedTiles.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.red[500]!],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    const Text(
                      'Sin jugadas - Pasa turno',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerTiles() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      children: _controller.playerTiles
          .map((tile) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: GestureDetector(
          onTap: () => _onTileSelected(tile),
          child: _buildDominoTile(tile),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildDominoTile(DominoTile tile, {bool isInPlay = false, bool isVertical = false}) {
    const double tileWidth = 50.0; // Actualizar aquí también
    const double tileHeight = 80.0; // Actualizar aquí también

    Color baseColor = const Color(0xFFF5F5DC); // Color beige como en la imagen
    Color borderColor = const Color(0xFFD2691E); // Borde marrón
    Color shadowColor = Colors.black54;

    // Efecto de hover para fichas jugables
    bool isPlayable = _controller.gameState == GameState.playerTurn &&
        _controller.canPlayTile(tile) &&
        !isInPlay;

    if (isPlayable) {
      baseColor = const Color(0xFFE6FFE6); // Verde muy claro cuando es jugable
      borderColor = Colors.green[600]!;
      shadowColor = Colors.green.withValues(alpha: 0.5);
    }

    Widget tileWidget = Container(
      width: isVertical ? tileHeight : tileWidth,
      height: isVertical ? tileWidth : tileHeight,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor,
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isPlayable ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isPlayable ? 8 : 4,
            offset: Offset(2, 2),
            spreadRadius: isPlayable ? 1 : 0,
          ),
          if (isPlayable)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      child: isVertical
          ? Row(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
              ),
              child: Center(
                child: _buildDots(tile.left),
              ),
            ),
          ),
          Container(
            width: 1.5,
            margin: EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
              ),
              child: Center(
                child: _buildDots(tile.right),
              ),
            ),
          ),
        ],
      )
          : Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              ),
              child: Center(
                child: _buildDots(tile.left),
              ),
            ),
          ),
          Container(
            height: 1.5,
            margin: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
              ),
              child: Center(
                child: _buildDots(tile.right),
              ),
            ),
          ),
        ],
      ),
    );

    return tileWidget;
  }

  Widget _buildDots(int number) {
    const dotPositions = {
      0: <Alignment>[],
      1: [Alignment.center],
      2: [Alignment.topLeft, Alignment.bottomRight],
      3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
      4: [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight],
      5: [Alignment.topLeft, Alignment.topRight, Alignment.center, Alignment.bottomLeft, Alignment.bottomRight],
      6: [Alignment.topLeft, Alignment.topRight, Alignment.centerLeft, Alignment.centerRight, Alignment.bottomLeft, Alignment.bottomRight],
    };

    // Colores de puntos más similares a la imagen
    List<Color> dotColors = [
      Colors.transparent,
      const Color(0xFF8B0000), // Rojo oscuro
      const Color(0xFF0000CD), // Azul medio
      const Color(0xFF228B22), // Verde bosque
      const Color(0xFF4B0082), // Índigo
      const Color(0xFFFF8C00), // Naranja oscuro
      const Color(0xFF008B8B), // Turquesa oscuro
    ];

    Color finalDotColor = number == 0 ? Colors.transparent : dotColors[number];

    return Stack(
      children: dotPositions[number]!
          .map((alignment) => Align(
        alignment: alignment,
        child: Container(
          width: 8, // Aumentar puntos de 7 a 8 píxeles
          height: 8,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: finalDotColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: finalDotColor == Colors.transparent ? Colors.transparent : Colors.white,
              width: 0.5,
            ),
            boxShadow: finalDotColor != Colors.transparent ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 1,
                offset: Offset(0.5, 0.5),
              ),
            ] : [],
          ),
        ),
      ))
          .toList(),
    );
  }
}