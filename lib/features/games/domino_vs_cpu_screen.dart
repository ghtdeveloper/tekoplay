import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/domino_tile.dart';
import '../../core/service/firestore_service.dart';
import '../../core/utils/game_result.dart';
import '../../core/utils/game_type.dart';
import '../../generated/l10n.dart';

enum GameState { playerTurn, computerTurn, gameOver }
enum GameResult { playerWins, computerWins, draw, none }

class PlayedDominoTile {
  final DominoTile tile;
  final bool isVertical;
  final Offset position;
  final bool isLeftSide;
  PlayedDominoTile({
    required this.tile,
    required this.isVertical,
    required this.position,
    required this.isLeftSide,
  });
}

class DominoVsComputerController {
  List<DominoTile> playerTiles = [];
  List<DominoTile> computerTiles = [];
  List<PlayedDominoTile> playedTiles = [];
  List<DominoTile> boneyard = [];
  int? leftEnd;
  int? rightEnd;
  GameState gameState = GameState.playerTurn;
  GameResult gameResult = GameResult.none;
  String difficulty = 'muy fácil';

  double boardWidth = 0;
  double boardHeight = 0;

  void initializeGame({required String selectedDifficulty}) {
    difficulty = selectedDifficulty;
    _createDominoSet();
    _dealTiles();
    _determineFirstPlayer();
  }

  void _createDominoSet() {
    boneyard.clear();
    playedTiles.clear();
    playerTiles.clear();
    computerTiles.clear();

    int id = 0;
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        boneyard.add(DominoTile(
            left: i,
            right: j,
            id: 'tile_$id'
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

  void _determineFirstPlayer() {
    DominoTile? highestPlayerDouble;
    DominoTile? highestComputerDouble;

    for (var tile in playerTiles) {
      if (tile.isDouble) {
        if (highestPlayerDouble == null || tile.left > highestPlayerDouble.left) {
          highestPlayerDouble = tile;
        }
      }
    }

    for (var tile in computerTiles) {
      if (tile.isDouble) {
        if (highestComputerDouble == null || tile.left > highestComputerDouble.left) {
          highestComputerDouble = tile;
        }
      }
    }

    if (highestPlayerDouble != null &&
        (highestComputerDouble == null ||
            highestPlayerDouble.left > highestComputerDouble.left)) {
      _playFirstTile(highestPlayerDouble, true);
      gameState = GameState.computerTurn;
    } else if (highestComputerDouble != null) {
      _playFirstTile(highestComputerDouble, false);
      gameState = GameState.playerTurn;
    } else {
      gameState = GameState.playerTurn;
    }
  }

  void _playFirstTile(DominoTile tile, bool isPlayer) {
    final centerPosition = Offset(boardWidth / 2, boardHeight / 2);

    playedTiles.add(PlayedDominoTile(
      tile: tile,
      isVertical: false,
      position: centerPosition,
      isLeftSide: false,
    ));

    leftEnd = tile.left;
    rightEnd = tile.right;
    tile.isPlayed = true;

    if (isPlayer) {
      playerTiles.remove(tile);
    } else {
      computerTiles.remove(tile);
    }
  }

  bool canPlayTile(DominoTile tile) {
    if (playedTiles.isEmpty) return true;
    return tile.left == leftEnd || tile.right == leftEnd ||
        tile.left == rightEnd || tile.right == rightEnd;
  }

  bool playTileAutomatically(DominoTile tile, {required bool isPlayer}) {
    if (!canPlayTile(tile)) return false;

    if (playedTiles.isEmpty) {
      _playFirstTile(tile, isPlayer);
    } else {
      _placeTileInBestPosition(tile);
    }

    tile.isPlayed = true;
    if (isPlayer) {
      playerTiles.remove(tile);
    } else {
      computerTiles.remove(tile);
    }

    _checkGameEnd();
    return true;
  }

  void _placeTileInBestPosition(DominoTile tile) {
    bool canPlayLeft = tile.left == leftEnd || tile.right == leftEnd;
    bool canPlayRight = tile.left == rightEnd || tile.right == rightEnd;

    bool playOnLeft = canPlayLeft;
    if (canPlayLeft && canPlayRight) {
      playOnLeft = Random().nextBool();
    }

    if (playOnLeft && canPlayLeft) {
      _placeOnLeftSide(tile);
    } else if (canPlayRight) {
      _placeOnRightSide(tile);
    }
  }

  void _placeOnLeftSide(DominoTile tile) {
    final leftmostTile = _getLeftmostTile();
    final newPosition = _calculateNewPosition(leftmostTile, true);

    bool needsVertical = _shouldPlaceVertical(leftmostTile, true);

    if (tile.right == leftEnd) {
      leftEnd = tile.left;
    } else {
      leftEnd = tile.right;
    }

    playedTiles.insert(0, PlayedDominoTile(
      tile: tile,
      isVertical: needsVertical,
      position: newPosition,
      isLeftSide: true,
    ));
  }

  void _placeOnRightSide(DominoTile tile) {
    final rightmostTile = _getRightmostTile();
    final newPosition = _calculateNewPosition(rightmostTile, false);

    bool needsVertical = _shouldPlaceVertical(rightmostTile, false);

    if (tile.left == rightEnd) {
      rightEnd = tile.right;
    } else {
      rightEnd = tile.left;
    }

    playedTiles.add(PlayedDominoTile(
      tile: tile,
      isVertical: needsVertical,
      position: newPosition,
      isLeftSide: false,
    ));
  }

  PlayedDominoTile _getLeftmostTile() {
    return playedTiles.first;
  }

  PlayedDominoTile _getRightmostTile() {
    return playedTiles.last;
  }

  Offset _calculateNewPosition(PlayedDominoTile referenceTile, bool isLeft) {
    const double tileWidth = 40.0;
    const double tileHeight = 70.0;
    const double spacing = 5.0;

    double newX, newY;

    if (isLeft) {
      if (referenceTile.isVertical) {
        newX = referenceTile.position.dx - tileWidth - spacing;
        newY = referenceTile.position.dy;
      } else {
        newX = referenceTile.position.dx - tileWidth - spacing;
        newY = referenceTile.position.dy;
      }
    } else {
      if (referenceTile.isVertical) {
        newX = referenceTile.position.dx + tileHeight + spacing;
        newY = referenceTile.position.dy;
      } else {
        newX = referenceTile.position.dx + tileWidth + spacing;
        newY = referenceTile.position.dy;
      }
    }

    return Offset(newX, newY);
  }

  bool _shouldPlaceVertical(PlayedDominoTile referenceTile, bool isLeft) {
    return playedTiles.length % 3 == 0;
  }

  bool drawFromBoneyard(bool isPlayer) {
    if (boneyard.isEmpty) return false;

    final drawnTile = boneyard.removeAt(0);
    if (isPlayer) {
      playerTiles.add(drawnTile);
    } else {
      computerTiles.add(drawnTile);
    }
    return true;
  }

  void _checkGameEnd() {
    if (playerTiles.isEmpty) {
      gameResult = GameResult.playerWins;
      gameState = GameState.gameOver;
      return;
    }

    if (computerTiles.isEmpty) {
      gameResult = GameResult.computerWins;
      gameState = GameState.gameOver;
      return;
    }

    bool playerCanPlay = playerTiles.any((tile) => canPlayTile(tile));
    bool computerCanPlay = computerTiles.any((tile) => canPlayTile(tile));

    if (!playerCanPlay && !computerCanPlay && boneyard.isEmpty) {
      int playerPoints = playerTiles.fold(0, (sum, tile) => sum + tile.total);
      int computerPoints = computerTiles.fold(0, (sum, tile) => sum + tile.total);

      if (playerPoints < computerPoints) {
        gameResult = GameResult.playerWins;
      } else if (computerPoints < playerPoints) {
        gameResult = GameResult.computerWins;
      } else {
        gameResult = GameResult.draw;
      }
      gameState = GameState.gameOver;
    }
  }

  DominoTile? getBestComputerMove() {
    List<DominoTile> playableTiles = computerTiles.where((tile) => canPlayTile(tile)).toList();

    if (playableTiles.isEmpty) return null;

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
    playableTiles.sort((a, b) => b.total.compareTo(a.total));
    return playableTiles.first;
  }

  DominoTile _getHardMove(List<DominoTile> playableTiles) {
    var doubles = playableTiles.where((tile) => tile.isDouble).toList();
    if (doubles.isNotEmpty) {
      doubles.sort((a, b) => b.total.compareTo(a.total));
      return doubles.first;
    }
    playableTiles.sort((a, b) => b.total.compareTo(a.total));
    return playableTiles.first;
  }

  void setBoardDimensions(double width, double height) {
    boardWidth = width;
    boardHeight = height;
  }
}

class DominoVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;

  const DominoVsComputerScreen(this.selectedDifficulty, {super.key});

  @override
  State<DominoVsComputerScreen> createState() => _DominoVsComputerScreenState();
}

class _DominoVsComputerScreenState extends State<DominoVsComputerScreen> {
  final DominoVsComputerController _controller = DominoVsComputerController();
  bool _isLoading = false;
  DateTime? _gameStartTime;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGameWithDimensions();
    });
  }

  void _initializeGameWithDimensions() {
    final size = MediaQuery.of(context).size;
    _controller.setBoardDimensions(size.width - 32, 200);
    _controller.initializeGame(selectedDifficulty: widget.selectedDifficulty);
    _gameStartTime = DateTime.now();
    _checkComputerTurn();
  }

  void _checkComputerTurn() async {
    if (_controller.gameState == GameState.computerTurn) {
      await Future.delayed(const Duration(milliseconds: 1000));
      _makeComputerMove();
    }
  }

  void _makeComputerMove() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    final computerMove = _controller.getBestComputerMove();

    if (computerMove != null) {
      _controller.playTileAutomatically(computerMove, isPlayer: false);
      _controller.gameState = GameState.playerTurn;
    } else {
      if (_controller.drawFromBoneyard(false)) {
        await Future.delayed(const Duration(milliseconds: 300));
        final newMove = _controller.getBestComputerMove();
        if (newMove != null) {
          _controller.playTileAutomatically(newMove, isPlayer: false);
        }
      }
      _controller.gameState = GameState.playerTurn;
    }

    setState(() => _isLoading = false);

    if (_controller.gameState == GameState.gameOver) {
      _showGameOverDialog();
    }
  }

  void _onTileSelected(DominoTile tile) {
    if (_controller.gameState != GameState.playerTurn) return;

    if (!_controller.canPlayTile(tile)) {
      _showSnack(S.of(context).notAllowed);
      return;
    }

    if (_controller.playTileAutomatically(tile, isPlayer: true)) {
      setState(() {
        _controller.gameState = GameState.computerTurn;
      });

      if (_controller.gameState != GameState.gameOver) {
        _checkComputerTurn();
      } else {
        _showGameOverDialog();
      }
    } else {
      _showSnack(S.of(context).notAllowed);
    }
  }

  void _drawTile() {
    if (_controller.gameState != GameState.playerTurn) return;

    if (_controller.boneyard.isEmpty) {
      _showSnack(S.of(context).noMoreChips);
      return;
    }

    if (_controller.drawFromBoneyard(true)) {
      setState(() {});
      _showSnack(S.of(context).youStoleChip);
    }
  }

  Future<void> _recordGameResult(GameResult dominoResult) async {
    if (currentUser == null) {
      print('Usuario no autenticado, no se registrará la partida');
      return;
    }

    if (_gameStartTime == null) {
      print('Tiempo de juego no válido, no se registrará la partida');
      return;
    }

    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      GameResultModel gameResultModel;
      int pointsEarned = 0;

      switch (dominoResult) {
        case GameResult.playerWins:
          gameResultModel = GameResultModel.win;
          pointsEarned = 12;
          break;
        case GameResult.computerWins:
          gameResultModel = GameResultModel.loss;
          pointsEarned = -8;
          break;
        case GameResult.draw:
          gameResultModel = GameResultModel.draw;
          pointsEarned = 6;
          break;
        case GameResult.none:
          return;
      }

      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'muy fácil':
          pointsEarned = (pointsEarned * 0.8).round();
          break;
        case 'normal':
          break;
        case 'difícil':
          pointsEarned = (pointsEarned * 1.3).round();
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
          'gameMode': 'vs_computer',
          'tilesRemaining': {
            'player': _controller.playerTiles.length,
            'computer': _controller.computerTiles.length,
          },
          'boneyardRemaining': _controller.boneyard.length,
          'totalTilesPlayed': _controller.playedTiles.length,
          'finalScore': {
            'playerPoints': _controller.playerTiles.fold(0, (sum, tile) => sum + tile.total),
            'computerPoints': _controller.computerTiles.fold(0, (sum, tile) => sum + tile.total),
          },
          'gameEndReason': _getGameEndReason(),
        },
      );

      if (success) {
        print('Partida de dominó registrada exitosamente');
      } else {
        print('Error al registrar la partida en Firestore');
      }
    } catch (e) {
      print('Error al registrar la partida: $e');
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

  String _getGameEndReason() {
    if (_controller.playerTiles.isEmpty) {
      return 'player_finished_tiles';
    } else if (_controller.computerTiles.isEmpty) {
      return 'computer_finished_tiles';
    } else {
      return 'blocked_game';
    }
  }

  void _showGameOverDialog() {
    String title;
    String message;

    switch (_controller.gameResult) {
      case GameResult.playerWins:
        title = S.of(context).congratulations;
        message = S.of(context).youHaveWon;
        break;
      case GameResult.computerWins:
        title = S.of(context).endGame;
        message = S.of(context).cpuWon;
        break;
      case GameResult.draw:
        title = S.of(context).drawMsg;
        message = S.of(context).gameDraw;
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
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: Text(S.of(context).newGame),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(S.of(context).back),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _isLoading = false;
      _gameStartTime = null;
    });
    _initializeGameWithDimensions();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title:  Text(
         S.of(context).dominoVsCpu,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerInfoWithAvatar(
                    S.of(context).cpu,
                    _controller.computerTiles.length,
                    _controller.gameState == GameState.computerTurn,
                    _buildCpuAvatar(),
                  ),
                  Column(
                    children: [
                      Text(
                        '${S.of(context).difficulty}: ${widget.selectedDifficulty}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${S.of(context).well}: ${_controller.boneyard.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  _buildPlayerInfoWithAvatar(
                    currentUser?.displayName ?? S.of(context).you,
                    _controller.playerTiles.length,
                    _controller.gameState == GameState.playerTurn,
                    _buildPlayerAvatar(),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: _buildPlayArea(),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.brown[800],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: _buildPlayerTiles(),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _controller.gameState == GameState.playerTurn &&
                        _controller.boneyard.isNotEmpty
                        ? _drawTile
                        : null,
                    icon: const Icon(Icons.add),
                    label: Text(S.of(context).stole),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_controller.gameState == GameState.playerTurn &&
                          !_controller.playerTiles.any((tile) => _controller.canPlayTile(tile))) {
                        setState(() {
                          _controller.gameState = GameState.computerTurn;
                        });
                        _checkComputerTurn();
                      }
                    },
                    icon: const Icon(Icons.skip_next),
                    label: Text(S.of(context).pass),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfoWithAvatar(String name, int tilesCount, bool isActive, Widget avatar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[600] : Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            '$tilesCount ${S.of(context).tokens}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayArea() {
    return Stack(
      children: [
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        if (_controller.playedTiles.isEmpty)
           Center(
            child: Text(
              S.of(context).tapTileToStart,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),

        ..._controller.playedTiles.map((playedTile) => Positioned(
          left: playedTile.position.dx,
          top: playedTile.position.dy,
          child: _buildDominoTile(
            playedTile.tile,
            isInPlay: true,
            isVertical: playedTile.isVertical,
          ),
        )),

        if (_controller.playedTiles.isNotEmpty) ...[
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${S.of(context).extremes}: ${_controller.leftEnd} - ${_controller.rightEnd}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerTiles() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      children: _controller.playerTiles
          .map((tile) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => _onTileSelected(tile),
          child: _buildDominoTile(tile),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildDominoTile(DominoTile tile, {bool isSelected = false, bool isInPlay = false, bool isVertical = false}) {
    const double tileWidth = 40.0;
    const double tileHeight = 70.0;

    return Transform.rotate(
      angle: isVertical ? pi / 2 : 0,
      child: Container(
        width: tileWidth,
        height: tileHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow[700] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.yellow[900]! : Colors.grey[400]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
            if (isSelected)
              BoxShadow(
                color: Colors.yellow.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Center(
                  child: _buildDots(tile.left),
                ),
              ),
            ),
            Container(
              height: 2,
              color: Colors.grey[600],
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                ),
                child: Center(
                  child: _buildDots(tile.right),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    return Stack(
      children: dotPositions[number]!
          .map((alignment) => Align(
        alignment: alignment,
        child: Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.all(1.5),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ))
          .toList(),
    );
  }
}