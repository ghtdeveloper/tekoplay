import 'package:flutter/material.dart';

import '../../../core/models/domino_tile.dart';
import '../../../generated/l10n.dart';
import '../../adds/banner_ad_widget.dart';


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

  static const Color _tableColor = Color(0xFF1B5E20);
  static const Color _tableDark = Color(0xFF1A4C1C);
  static const Color _tileColor = Color(0xFFFFF8E1);
  static const Color _tileBorder = Color(0xFF4A3728);
  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final total = _steps.length;

    return Scaffold(
      backgroundColor: _tableColor,
      appBar: AppBar(
        backgroundColor: _tableDark,
        elevation: 0,
        title: Text(
          S.of(context).dominoTutorial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentStep + 1} / $total',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const BannerAdWidget(),
            _buildInstructionCard(step),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 1.5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
                        ),
                        child: _buildPlayArea(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: _tableDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: _buildPlayerTiles(),
                    ),
                  ],
                ),
              ),
            ),
            _buildNavBar(context, total),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> step) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tableDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step['title']!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            step['description']!,
            style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _demoMove,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(S.of(context).watchMovement, style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _resetStepForStep,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(S.of(context).resetPassed, style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _currentStep--);
                _resetStepForStep();
              },
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
              label: Text(S.of(context).back, style: const TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: Icon(_currentStep == total - 1 ? Icons.check : Icons.chevron_right),
            label: Text(_currentStep == total - 1 ? S.of(context).finish : S.of(context).next),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayArea(BuildContext context) {
    return Stack(
      children: [
        if (_controller.playedTiles.isNotEmpty) ...[
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(true),
              child: Container(
                width: 48,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 16),
                    SizedBox(height: 4),
                    Text('IZQ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _onPlayAreaTapped(false),
              child: Container(
                width: 48,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                    SizedBox(height: 4),
                    Text('DER', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
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
                width: 90,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentOrange, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.white70, size: 28),
                    SizedBox(height: 4),
                    Text('Colocar', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),

        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _controller.playedTiles.map((tile) => _buildChainTile(tile)).toList(),
            ),
          ),
        ),

        if (_controller.playedTiles.isNotEmpty)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${S.of(context).extremes}: ${_controller.leftEnd}  —  ${_controller.rightEnd}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerTiles() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      children: _controller.playerTiles.map((tile) {
        final isSelected = _selectedTile == tile;
        return GestureDetector(
          onTap: () => _onTileSelected(tile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            transform: isSelected ? (Matrix4.identity()..translate(0.0, -6.0)) : Matrix4.identity(),
            child: _buildHandTile(tile, isSelected: isSelected),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHandTile(DominoTile tile, {bool isSelected = false}) {
    return Container(
      width: 44,
      height: 88,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF176) : _tileColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? _accentOrange : _tileBorder,
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? _accentOrange.withValues(alpha: 0.4) : Colors.black45,
            blurRadius: isSelected ? 8 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: _buildPipArea(tile.left)),
          Container(height: 1.5, color: _tileBorder),
          Expanded(child: _buildPipArea(tile.right)),
        ],
      ),
    );
  }

  Widget _buildChainTile(DominoTile tile) {
    return Container(
      width: 72,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _tileColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _tileBorder, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 1))],
      ),
      child: Row(
        children: [
          Expanded(child: _buildPipArea(tile.left)),
          Container(width: 1.5, color: _tileBorder),
          Expanded(child: _buildPipArea(tile.right)),
        ],
      ),
    );
  }

  Widget _buildPipArea(int count) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: CustomPaint(
        painter: _PipPainter(count),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int count;
  _PipPainter(this.count);

  static const _positions = {
    0: <List<double>>[],
    1: [[0.5, 0.5]],
    2: [[0.25, 0.25], [0.75, 0.75]],
    3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
    4: [[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]],
    5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
    6: [[0.25, 0.2], [0.75, 0.2], [0.25, 0.5], [0.75, 0.5], [0.25, 0.8], [0.75, 0.8]],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1A1A1A);
    final radius = (size.shortestSide * 0.18).clamp(2.0, 5.0);
    for (final pos in (_positions[count] ?? [])) {
      canvas.drawCircle(Offset(size.width * pos[0], size.height * pos[1]), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) => old.count != count;
}