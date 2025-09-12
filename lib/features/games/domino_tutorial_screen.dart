import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/models/domino_tile.dart';
import '../../generated/l10n.dart';
import '../adds/BannerAdWidget.dart';

class DominoController {
  List<DominoTile> playerTiles = [];
  List<DominoTile> playedTiles = [];
  int? leftEnd;
  int? rightEnd;

  void resetGame() {
    playerTiles.clear();
    playedTiles.clear();
    leftEnd = null;
    rightEnd = null;
  }

  void initializeTutorialStep(List<DominoTile> tiles, {DominoTile? firstTile}) {
    resetGame();
    playerTiles = tiles;
    if (firstTile != null) {
      playTile(firstTile, isLeft: true);
    }
  }

  bool canPlayTile(DominoTile tile) {
    if (playedTiles.isEmpty) return true;
    return tile.left == leftEnd || tile.right == leftEnd ||
        tile.left == rightEnd || tile.right == rightEnd;
  }

  bool playTile(DominoTile tile, {required bool isLeft}) {
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
    playerTiles.remove(tile);
    return true;
  }

  void undoLastMove() {
    if (playedTiles.isNotEmpty) {
      final lastTile = playedTiles.last;
      playedTiles.removeLast();
      lastTile.isPlayed = false;
      playerTiles.add(lastTile);

      if (playedTiles.isEmpty) {
        leftEnd = null;
        rightEnd = null;
      } else if (playedTiles.length == 1) {
        leftEnd = playedTiles.first.left;
        rightEnd = playedTiles.first.right;
      }
    }
  }
}

class DominoImmersiveTutorialScreen extends StatefulWidget {
  const DominoImmersiveTutorialScreen({super.key});

  @override
  State<DominoImmersiveTutorialScreen> createState() =>
      _DominoImmersiveTutorialScreenState();
}

class _DominoImmersiveTutorialScreenState
    extends State<DominoImmersiveTutorialScreen> {
  final DominoController _controller = DominoController();
  int _currentStep = 0;
  DominoTile? _selectedTile;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Primera Jugada',
      'description': 'Inicia el juego colocando la ficha doble más alta. Toca la ficha [6|6] para colocarla en el centro.',
      'tiles': [
        DominoTile(left: 6, right: 6, id: '6-6'),
        DominoTile(left: 5, right: 3, id: '5-3'),
        DominoTile(left: 2, right: 4, id: '2-4'),
      ],
      'expectedTile': '6-6',
      'targetSide': null,
    },
    {
      'title': 'Conectar Fichas',
      'description': 'Las fichas se conectan por extremos iguales. Conecta [6|3] al extremo derecho del [6|6].',
      'tiles': [
        DominoTile(left: 6, right: 3, id: '6-3'),
        DominoTile(left: 5, right: 2, id: '5-2'),
        DominoTile(left: 1, right: 4, id: '1-4'),
      ],
      'firstTile': DominoTile(left: 6, right: 6, id: '6-6-played'),
      'expectedTile': '6-3',
      'targetSide': 'right',
    },
    {
      'title': 'Lado Izquierdo',
      'description': 'También puedes jugar del lado izquierdo. Coloca [6|1] del lado izquierdo.',
      'tiles': [
        DominoTile(left: 6, right: 1, id: '6-1'),
        DominoTile(left: 3, right: 2, id: '3-2'),
        DominoTile(left: 4, right: 5, id: '4-5'),
      ],
      'previousTiles': [
        DominoTile(left: 6, right: 6, id: '6-6-played'),
        DominoTile(left: 6, right: 3, id: '6-3-played'),
      ],
      'expectedTile': '6-1',
      'targetSide': 'left',
    },
  ];

  @override
  void initState() {
    super.initState();
    _resetStepForStep();
  }

  void _resetStepForStep() {
    final step = _steps[_currentStep];
    final tiles = (step['tiles'] as List<DominoTile>)
        .map((t) => DominoTile(left: t.left, right: t.right, id: t.id))
        .toList();

    if (step.containsKey('previousTiles')) {
      final prevTiles = step['previousTiles'] as List<DominoTile>;
      _controller.resetGame();

      for (var tile in prevTiles) {
        final newTile = DominoTile(left: tile.left, right: tile.right, id: tile.id);
        if (_controller.playedTiles.isEmpty) {
          _controller.playTile(newTile, isLeft: true);
        } else {
          _controller.playTile(newTile, isLeft: false);
        }
      }
      _controller.playerTiles = tiles;
    } else if (step.containsKey('firstTile')) {
      _controller.initializeTutorialStep(tiles, firstTile: step['firstTile']);
    } else {
      _controller.initializeTutorialStep(tiles);
    }

    _selectedTile = null;
    setState(() {});
  }

  void _nextStep() async {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _resetStepForStep();
    } else {
      // Fin del tutorial
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title:  Text(S.of(context).congratulations),
          content: Text(S.of(context).completeDominoTutorial),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text(S.of(context).back),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _onTileSelected(DominoTile tile) {
    setState(() {
      if (_selectedTile == tile) {
        _selectedTile = null;
      } else {
        _selectedTile = tile;
      }
    });
  }

  void _onPlayAreaTapped(bool isLeft) {
    if (_selectedTile == null) return;

    final step = _steps[_currentStep];
    final expectedTileId = step['expectedTile'] as String;
    final targetSide = step['targetSide'] as String?;

    if (_selectedTile!.id != expectedTileId) {
      _showSnack('${S.of(context).incorrectTab} ${step['expectedTile']}');
      return;
    }

    if (targetSide == null) {
      if (_controller.playTile(_selectedTile!, isLeft: isLeft)) {
        _showSnack(S.of(context).wellDone, isSuccess: true);
        _selectedTile = null;
        Future.delayed(const Duration(milliseconds: 600), _nextStep);
      }
      return;
    }

    final correctSide = targetSide == 'left' ? isLeft : !isLeft;
    if (!correctSide) {
      _showSnack('${S.of(context).wrongSide} ${targetSide == 'left' ? S.of(context).left : S.of(context).right}');
      return;
    }

    if (_controller.playTile(_selectedTile!, isLeft: isLeft)) {
      _showSnack(S.of(context).wellDone, isSuccess: true);
      _selectedTile = null;
      Future.delayed(const Duration(milliseconds: 600), _nextStep);
    } else {
      _showSnack(S.of(context).notAllowed);
    }
  }

  void _demoMove() {
    final step = _steps[_currentStep];
    final expectedTileId = step['expectedTile'] as String;
    final targetSide = step['targetSide'] as String?;

    final demoTile = _controller.playerTiles.firstWhere((t) => t.id == expectedTileId);
    final isLeft = targetSide == 'left' || targetSide == null;

    _controller.playTile(demoTile, isLeft: isLeft);
    setState(() {});
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final total = _steps.length;

    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title:  Text(
          S.of(context).dominoTutorial,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${S.of(context).passed} ${_currentStep + 1} / $total',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const BannerAdWidget(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title']!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step['description']!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _demoMove,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(S.of(context).watchMovement),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetStepForStep,
                        icon: const Icon(Icons.replay),
                        label: Text(S.of(context).resetPassed),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
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
                      decoration: BoxDecoration(
                        color: Colors.brown[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: _buildPlayerTiles(),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _currentStep--);
                        _resetStepForStep();
                      },
                      icon: const Icon(Icons.chevron_left),
                      label: Text(S.of(context).back),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.chevron_right),
                    label: Text(_currentStep == total - 1 ? S.of(context).finish : S.of(context).next),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayArea() {
    return Stack(
      children: [
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
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38, width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.arrow_back, color: Colors.white70),
                ),
              ),
            ),
          ),
          // Zona derecha
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(false),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white12,
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