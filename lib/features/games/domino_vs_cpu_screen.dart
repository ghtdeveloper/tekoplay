import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/DominoTile.dart';
import '../../generated/l10n.dart';

enum GameState { playerTurn, computerTurn, gameOver }
enum GameResult { playerWins, computerWins, draw, none }

class DominoVsComputerController {
  List<DominoTile> playerTiles = [];
  List<DominoTile> computerTiles = [];
  List<DominoTile> playedTiles = [];
  List<DominoTile> boneyard = [];
  int? leftEnd;
  int? rightEnd;
  GameState gameState = GameState.playerTurn;
  GameResult gameResult = GameResult.none;
  String difficulty = 'muy fácil';

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
    playedTiles.add(tile);
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

  bool playTile(DominoTile tile, {required bool isLeft, required bool isPlayer}) {
    if (!canPlayTile(tile)) return false;

    if (playedTiles.isEmpty) {
      playedTiles.add(tile);
      leftEnd = tile.left;
      rightEnd = tile.right;
    } else {
      if (isLeft) {
        if (tile.right == leftEnd) {
          leftEnd = tile.left;
        } else if (tile.left == leftEnd) {
          leftEnd = tile.right;
        } else {
          return false;
        }
        playedTiles.insert(0, tile);
      } else {
        if (tile.left == rightEnd) {
          rightEnd = tile.right;
        } else if (tile.right == rightEnd) {
          rightEnd = tile.left;
        } else {
          return false;
        }
        playedTiles.add(tile);
      }
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

  bool shouldComputerPlayLeft(DominoTile tile) {
    if (tile.left == leftEnd || tile.right == leftEnd) {
      if (tile.left == rightEnd || tile.right == rightEnd) {
        return Random().nextBool();
      } else {
        return true;
      }
    } else {
      return false;
    }
  }
}

class DominoVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;

  const DominoVsComputerScreen(this.selectedDifficulty,{super.key});

  @override
  State<DominoVsComputerScreen> createState() => _DominoVsComputerScreenState();
}

class _DominoVsComputerScreenState extends State<DominoVsComputerScreen> {
  final DominoVsComputerController _controller = DominoVsComputerController();
  DominoTile? _selectedTile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.initializeGame(selectedDifficulty: widget.selectedDifficulty);
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
      final shouldPlayLeft = _controller.shouldComputerPlayLeft(computerMove);
      _controller.playTile(computerMove, isLeft: shouldPlayLeft, isPlayer: false);
      _controller.gameState = GameState.playerTurn;
    } else {
      if (_controller.drawFromBoneyard(false)) {
        await Future.delayed(const Duration(milliseconds: 300));
        final newMove = _controller.getBestComputerMove();
        if (newMove != null) {
          final shouldPlayLeft = _controller.shouldComputerPlayLeft(newMove);
          _controller.playTile(newMove, isLeft: shouldPlayLeft, isPlayer: false);
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

    setState(() {
      if (_selectedTile == tile) {
        _selectedTile = null;
      } else {
        _selectedTile = tile;
      }
    });
  }

  void _onPlayAreaTapped(bool isLeft) {
    if (_selectedTile == null || _controller.gameState != GameState.playerTurn) return;

    if (_controller.playTile(_selectedTile!, isLeft: isLeft, isPlayer: true)) {
      setState(() {
        _selectedTile = null;
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
            child:  Text(S.of(context).newGame),
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
      _selectedTile = null;
      _isLoading = false;
    });
    _controller.initializeGame(selectedDifficulty: widget.selectedDifficulty);
    _checkComputerTurn();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          'Dominó vs Computadora',
          style: const TextStyle(color: Colors.white),
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
                  _buildPlayerInfo(
                   S.of(context).cpu,
                    _controller.computerTiles.length,
                    _controller.gameState == GameState.computerTurn,
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
                  _buildPlayerInfo(
                    S.of(context).you,
                    _controller.playerTiles.length,
                    _controller.gameState == GameState.playerTurn,
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
                        _controller.boneyard.isNotEmpty ? _drawTile : null,
                    icon: const Icon(Icons.add),
                    label:  Text(S.of(context).stole),
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
                    label:  Text(S.of(context).pass),
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

  Widget _buildPlayerInfo(String name, int tilesCount, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[600] : Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$tilesCount ${S.of(context).tokens}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
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

        if (_controller.playedTiles.isNotEmpty) ...[
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(true),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: _selectedTile != null && _controller.gameState == GameState.playerTurn
                      ? Colors.white24 : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_back, color: Colors.white70),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(false),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: _selectedTile != null && _controller.gameState == GameState.playerTurn
                      ? Colors.white24 : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_forward, color: Colors.white70),
                ),
              ),
            ),
          ),
        ],

        if (_controller.playedTiles.isEmpty && _selectedTile != null)
          Center(
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(true),
              child: Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.white70, size: 30),
                ),
              ),
            ),
          ),


        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _controller.playedTiles.map((tile) =>
                  _buildDominoTile(tile, isInPlay: true)
              ).toList(),
            ),
          ),
        ),

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
      children: _controller.playerTiles.map((tile) =>
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onTileSelected(tile),
              child: _buildDominoTile(tile, isSelected: _selectedTile == tile),
            ),
          ),
      ).toList(),
    );
  }

  Widget _buildDominoTile(DominoTile tile, {bool isSelected = false, bool isInPlay = false}) {
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.yellow[700] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.yellow[900]! : Colors.grey[400]!,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ] : null,
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
      children: dotPositions[number]!.map((alignment) =>
          Align(
            alignment: alignment,
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ).toList(),
    );
  }
}