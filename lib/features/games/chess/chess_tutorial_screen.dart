import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../../../generated/l10n.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ChessImmersiveTutorialScreen extends StatefulWidget {
  const ChessImmersiveTutorialScreen({super.key});

  @override
  State<ChessImmersiveTutorialScreen> createState() =>
      _ChessImmersiveTutorialScreenState();
}

class _ChessImmersiveTutorialScreenState
    extends State<ChessImmersiveTutorialScreen> with WidgetsBindingObserver {
  late ChessBoardController _controller;

  bool _showPieceSelector = true;
  String? _selectedPiece;
  int _currentStep = 0;
  String _previousFen = '';
  bool _waitingForMove = false;
  bool _isScreenKeepOnActive = false;


  Map<String, Map<String, dynamic>> _buildTutorials(S s) => {
    'pawn': {
      'name': s.chessPiecePawn,
      'icon': '♟',
      'color': Colors.brown,
      'steps': [
        {
          'title': s.pawnStep1Title,
          'description': s.pawnStep1Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/8/4P3/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          'from': 'e2',
          'to': 'e3',
          'highlights': ['e2', 'e3'],
        },
        {
          'title': s.pawnStep2Title,
          'description': s.pawnStep2Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1',
          'from': 'd2',
          'to': 'd4',
          'highlights': ['d2', 'd3', 'd4'],
        },
        {
          'title': s.pawnStep3Title,
          'description': s.pawnStep3Desc,
          'initialFen': 'rnbqkbnr/pp2pppp/8/2p5/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2',
          'targetFen': 'rnbqkbnr/pp2pppp/8/2P5/8/8/PPP1PPPP/RNBQKBNR b KQkq - 0 2',
          'from': 'd4',
          'to': 'c5',
          'highlights': ['d4', 'c5'],
        },
      ],
    },
    'knight': {
      'name': s.chessPieceKnight,
      'icon': '♞',
      'color': Colors.indigo,
      'steps': [
        {
          'title': s.knightStep1Title,
          'description': s.knightStep1Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1',
          'from': 'g1',
          'to': 'f3',
          'highlights': ['g1', 'f3'],
        },
        {
          'title': s.knightStep2Title,
          'description': s.knightStep2Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/8/2N5/PPPPPPPP/R1BQKBNR b KQkq - 1 1',
          'from': 'b1',
          'to': 'c3',
          'highlights': ['b1', 'c3'],
        },
      ],
    },
    'bishop': {
      'name': s.chessPieceBishop,
      'icon': '♝',
      'color': Colors.purple,
      'steps': [
        {
          'title': s.bishopStep1Title,
          'description': s.bishopStep1Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/8/3P4/PPP1PPPP/RNBQKBNR b KQkq - 0 1',
          'from': 'd2',
          'to': 'd3',
          'highlights': ['d2', 'd3'],
        },
        {
          'title': s.bishopStep2Title,
          'description': s.bishopStep2Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/3P4/PPP1PPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/5B2/3P4/PPP1PPPP/RN1QKBNR b KQkq - 1 1',
          'from': 'c1',
          'to': 'f4',
          'highlights': ['c1', 'f4'],
        },
      ],
    },
    'rook': {
      'name': s.chessPieceRook,
      'icon': '♜',
      'color': Colors.red,
      'steps': [
        {
          'title': s.rookStep1Title,
          'description': s.rookStep1Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/P7/8/1PPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/P7/R7/1PPPPPPP/1NBQKBNR b KQkq - 1 1',
          'from': 'a1',
          'to': 'a3',
          'highlights': ['a1', 'a3'],
        },
        {
          'title': s.rookStep2Title,
          'description': s.rookStep2Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/P7/R7/1PPPPPPP/1NBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/P7/4R3/1PPPPPPP/1NBQKBNR b KQkq - 1 1',
          'from': 'a3',
          'to': 'e3',
          'highlights': ['a3', 'b3', 'c3', 'd3', 'e3'],
        },
      ],
    },
    'queen': {
      'name': s.chessPieceQueen,
      'icon': '♛',
      'color': Colors.pink,
      'steps': [
        {
          'title': s.queenStep1Title,
          'description': s.queenStep1Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/8/8/4P3/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          'from': 'e2',
          'to': 'e3',
          'highlights': ['e2', 'e3'],
        },
        {
          'title': s.queenStep2Title,
          'description': s.queenStep2Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/8/8/4P3/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/7Q/8/4P3/PPPP1PPP/RNB1KBNR b KQkq - 1 1',
          'from': 'd1',
          'to': 'h5',
          'highlights': ['d1', 'e2', 'f3', 'g4', 'h5'],
        },
        {
          'title': s.queenStep3Title,
          'description': s.queenStep3Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/7Q/8/4P3/PPPP1PPP/RNB1KBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppppppp/8/3Q4/8/4P3/PPPP1PPP/RNB1KBNR b KQkq - 1 1',
          'from': 'h5',
          'to': 'd5',
          'highlights': ['h5', 'g5', 'f5', 'e5', 'd5'],
        },
        {
          'title': s.queenStep4Title,
          'description': s.queenStep4Desc,
          'initialFen': 'rnbqkbnr/pppppppp/8/3Q4/8/4P3/PPPP1PPP/RNB1KBNR w KQkq - 0 1',
          'targetFen': 'rnbqkbnr/pppQpppp/8/8/8/4P3/PPPP1PPP/RNB1KBNR b KQkq - 0 1',
          'from': 'd5',
          'to': 'd7',
          'highlights': ['d5', 'd6', 'd7'],
        },
      ],
    },
    'king': {
      'name': s.chessPieceKing,
      'icon': '♚',
      'color': Colors.amber,
      'steps': [
        {
          'title': s.kingStep1Title,
          'description': s.kingStep1Desc,
          'initialFen': '8/8/8/8/3K4/8/8/8 w - - 0 1',
          'targetFen': '8/8/8/8/4K3/8/8/8 b - - 1 1',
          'from': 'd4',
          'to': 'e4',
          'highlights': ['c3', 'c4', 'c5', 'd3', 'd5', 'e3', 'e4', 'e5'],
        },
        {
          'title': s.kingStep2Title,
          'description': s.kingStep2Desc,
          'initialFen': '8/8/8/8/4K3/8/8/8 w - - 0 1',
          'targetFen': '8/8/8/4K3/8/8/8/8 b - - 1 1',
          'from': 'e4',
          'to': 'e5',
          'highlights': ['d3', 'd4', 'd5', 'e3', 'e5', 'f3', 'f4', 'f5'],
        },
        {
          'title': s.kingStep3Title,
          'description': s.kingStep3Desc,
          'initialFen': '8/8/8/4K3/8/8/8/8 w - - 0 1',
          'targetFen': '8/8/3K4/8/8/8/8/8 b - - 1 1',
          'from': 'e5',
          'to': 'd6',
          'highlights': ['d4', 'd5', 'd6', 'e4', 'e6', 'f4', 'f5', 'f6'],
        },
        {
          'title': s.kingStep4Title,
          'description': s.kingStep4Desc,
          'initialFen': '8/8/3K4/8/8/8/8/8 w - - 0 1',
          'targetFen': '8/8/8/2K5/8/8/8/8 b - - 1 1',
          'from': 'd6',
          'to': 'c5',
          'highlights': ['c5', 'c6', 'c7', 'd5', 'd7', 'e5', 'e6', 'e7'],
        },
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ChessBoardController();
    _enableWakeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isScreenKeepOnActive) {
          _enableWakeLock();
        }
        break;
      case AppLifecycleState.paused:
        _disableWakeLock();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = true;
          });
        }
        if (kDebugMode) {
          print('WakeLock enabled - screen will stay on');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling WakeLock: $e');
      }
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) {
          setState(() {
            _isScreenKeepOnActive = false;
          });
        }
        if (kDebugMode) {
          print('WakeLock disabled - screen can turn off normally');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disabling WakeLock: $e');
      }
    }
  }

  void _selectPiece(String piece) {
    setState(() {
      _selectedPiece = piece;
      _showPieceSelector = false;
      _currentStep = 0;
      _waitingForMove = false;
    });
    _setupBoardForStep();
  }

  void _setupBoardForStep() {
    if (_selectedPiece == null) return;

    final steps = _buildTutorials(S.of(context))[_selectedPiece]!['steps'] as List;
    if (_currentStep >= steps.length) return;

    final step = steps[_currentStep];
    final initialFen = step['initialFen'] as String;

    _controller.loadFen(initialFen);

    setState(() {
      _previousFen = initialFen;
      _waitingForMove = true;
    });
  }

  void _checkMove() {
    if (!_waitingForMove || _selectedPiece == null) return;

    final currentFen = _controller.getFen();

    if (currentFen == _previousFen) return;

    final steps = _buildTutorials(S.of(context))[_selectedPiece]!['steps'] as List;
    final step = steps[_currentStep];
    final targetFen = step['targetFen'] as String;

    final currentPosition = currentFen.split(' ')[0];
    final targetPosition = targetFen.split(' ')[0];

    if (currentPosition == targetPosition) {
      _showSnack( S.of(context).correctMove, isSuccess: true);
      setState(() {
        _waitingForMove = false;
      });
      Future.delayed(const Duration(seconds: 2), _nextStep);
    } else {
      _showSnack(
        S.of(context).incorrectMove,
          isSuccess: false
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        _setupBoardForStep();
      });
    }
  }

  void _nextStep() {
    if (_selectedPiece == null) return;

    final steps = _buildTutorials(S.of(context))[_selectedPiece]!['steps'] as List;

    if (_currentStep < steps.length - 1) {
      setState(() {
        _currentStep++;
        _waitingForMove = false;
      });
      _setupBoardForStep();
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title:  Text(S.of(context).congratulationsShort),
        content: Text(
          '${S.of(context).tutorialCompleted} ${_buildTutorials(S.of(context))[_selectedPiece]!['name']}!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showPieceSelector = true;
                _selectedPiece = null;
                _currentStep = 0;
              });
            },
            child:  Text(S.of(context).chooseAnotherPiece),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child:  Text(S.of(context).exit),
          ),
        ],
      ),
    );
  }

  void _demoMove() async {
    if (_selectedPiece == null) return;

    final steps = _buildTutorials(S.of(context))[_selectedPiece]!['steps'] as List;
    final step = steps[_currentStep];

    _setupBoardForStep();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() {
      _waitingForMove = false;
    });

    _controller.makeMove(
      from: step['from'] as String,
      to: step['to'] as String,
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    _setupBoardForStep();

    _showSnack(S.of(context).nowYouTry, isSuccess: true);
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isSuccess ? 2 : 3),
      ),
    );
  }

  Widget _buildPieceSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            S.of(context).selectPieceToLearn,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _buildTutorials(S.of(context)).length,
              itemBuilder: (context, index) {
                final pieceKey = _buildTutorials(S.of(context)).keys.elementAt(index);
                final piece = _buildTutorials(S.of(context))[pieceKey]!;

                return Card(
                  elevation: 4,
                  child: InkWell(
                    onTap: () => _selectPiece(pieceKey),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            piece['color'].withOpacity(0.1),
                            piece['color'].withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            piece['icon'],
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            piece['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: piece['color'],
                            ),
                          ),
                          Text(
                            '${(piece['steps'] as List).length} ${S.of(context).exercise}${(piece['steps'] as List).length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorial() {
    if (_selectedPiece == null) return const SizedBox();

    final pieceData = _buildTutorials(S.of(context))[_selectedPiece]!;
    final steps = pieceData['steps'] as List;
    final step = steps[_currentStep];
    final total = steps.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    pieceData['icon'],
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          S.of(context).exerciseOf(_currentStep + 1, total),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.1),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step['description'],
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildColorLegend(Colors.green, 'Origen'),
                  const SizedBox(width: 16),
                  _buildColorLegend(Colors.deepOrange, 'Destino'),
                  const SizedBox(width: 16),
                  _buildColorLegend(Colors.yellow, 'Camino'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  ChessBoard(
                    controller: _controller,
                    boardColor: BoardColor.brown,
                    boardOrientation: PlayerColor.white,
                    enableUserMoves: true,
                    onMove: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _checkMove();
                      });
                    },
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: SquareHighlightPainter(
                        step['highlights'] as List<String>? ?? [],
                        targetSquare: step['to'] as String?,
                        fromSquare: step['from'] as String?,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botones de control (sin cambios)
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPieceSelector = true;
                    _selectedPiece = null;
                    _currentStep = 0;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                label:  Text(S.of(context).back),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _demoMove,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(S.of(context).demo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _setupBoardForStep,
                icon: const Icon(Icons.refresh, size: 20),
                label:  Text(S.of(context).reset),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorLegend(ui.Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
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
          _showPieceSelector
              ? S.of(context).tutorialChessTitle
              : '${S.of(context).tutorialShort}: ${_buildTutorials(S.of(context))[_selectedPiece]?['name'] ?? ''}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_showPieceSelector && _selectedPiece != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentStep + 1}/${(_buildTutorials(S.of(context))[_selectedPiece]!['steps'] as List).length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _showPieceSelector ? _buildPieceSelector() : _buildTutorial(),
      ),
    );
  }
}

class SquareHighlightPainter extends CustomPainter {
  final List<String> highlights;
  final String? targetSquare;
  final String? fromSquare;

  SquareHighlightPainter(this.highlights, {this.targetSquare, this.fromSquare});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final squareSize = size.width / 8;

    for (String square in highlights) {
      if (square.length != 2) continue;

      try {
        final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final rank = int.parse(square[1]) - 1; // 0-7

        if (file < 0 || file > 7 || rank < 0 || rank > 7) continue;

        final x = file * squareSize;
        final y = (7 - rank) * squareSize;
        final center = Offset(x + squareSize / 2, y + squareSize / 2);

        final paint = Paint()
          ..color = Colors.yellow.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(center, squareSize * 0.2, paint);
      } catch (e) {
        continue;
      }
    }

    if (fromSquare != null && fromSquare!.length == 2) {
      try {
        final file = fromSquare!.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final rank = int.parse(fromSquare![1]) - 1;

        if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
          final x = file * squareSize;
          final y = (7 - rank) * squareSize;
          final center = Offset(x + squareSize / 2, y + squareSize / 2);

          final paint = Paint()
            ..color = Colors.green.withValues(alpha: 0.1)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(center, squareSize * 0.3, paint);

          final borderPaint = Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;

          canvas.drawCircle(center, squareSize * 0.3, borderPaint);
        }
      } catch (e) {
        // Ignorar errores
      }
    }

    if (targetSquare != null && targetSquare!.length == 2) {
      try {
        final file = targetSquare!.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final rank = int.parse(targetSquare![1]) - 1;

        if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
          final x = file * squareSize;
          final y = (7 - rank) * squareSize;
          final center = Offset(x + squareSize / 2, y + squareSize / 2);

          final paint = Paint()
            ..color = Colors.deepOrange.withValues(alpha: 0.1)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(center, squareSize * 0.35, paint);


          final borderPaint = Paint()
            ..color = Colors.deepOrange.shade800
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4;

          canvas.drawCircle(center, squareSize * 0.35, borderPaint);

          final centerDot = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

          canvas.drawCircle(center, squareSize * 0.1, centerDot);
        }
      } catch (e) {
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}