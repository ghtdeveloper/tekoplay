import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/ludo_game_match.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../../core/service/firestore_service.dart';
import '../../../generated/l10n.dart';
import 'ludo_board_painter.dart';

class LudoVsCpuScreen extends StatefulWidget {
  final String difficulty;
  final String matchType;
  final int cpuCount;

  const LudoVsCpuScreen({
    Key? key,
    required this.difficulty,
    required this.matchType,
    this.cpuCount = 1,
  }) : super(key: key);

  @override
  State<LudoVsCpuScreen> createState() => _LudoVsCpuScreenState();
}

class _LudoVsCpuScreenState extends State<LudoVsCpuScreen> with TickerProviderStateMixin {
  late LudoGameState _gameState;
  String _currentPlayer = 'yellow';

  late List<String> _activePlayers;
  late List<String> _cpuPlayers;

  int _dice1Value = 0;
  int _dice2Value = 0;
  int _totalDiceValue = 0;
  bool _canRollDice = true;
  bool _gameEnded = false;
  final Random _random = Random();
  DateTime? _gameStartTime;
  double _boardSize = 0;

  String? _selectedPieceColor;
  int? _selectedPieceId;
  final List<int> _validMovePositions = [];
  List<Map<String, dynamic>> _movablePieces = [];

  bool _hasUsedDice1 = false;
  bool _hasUsedDice2 = false;
  bool _waitingForNextMove = false;

  int _consecutiveDoubles = 0;
  int _previousDice1 = 0;
  int _previousDice2 = 0;

  late AnimationController _diceAnimationController;
  late Animation<double> _diceRotation;
  bool _isRollingDice = false;

  final FirestoreService _firestoreService = FirestoreService();

  static const List<_Coord> _boardPath = [
    _Coord(6, 1), _Coord(6, 2), _Coord(6, 3), _Coord(6, 4), _Coord(6, 5),
    _Coord(5, 6), _Coord(4, 6), _Coord(3, 6), _Coord(2, 6), _Coord(1, 6), _Coord(0, 6),
    _Coord(0, 7), _Coord(0, 8),
    _Coord(1, 8), _Coord(2, 8), _Coord(3, 8), _Coord(4, 8), _Coord(5, 8),
    _Coord(6, 9), _Coord(6, 10), _Coord(6, 11), _Coord(6, 12), _Coord(6, 13), _Coord(6, 14),
    _Coord(7, 14), _Coord(8, 14),
    _Coord(8, 13), _Coord(8, 12), _Coord(8, 11), _Coord(8, 10), _Coord(8, 9),
    _Coord(9, 8), _Coord(10, 8), _Coord(11, 8), _Coord(12, 8), _Coord(13, 8), _Coord(14, 8),
    _Coord(14, 7), _Coord(14, 6),
    _Coord(13, 6), _Coord(12, 6), _Coord(11, 6), _Coord(10, 6), _Coord(9, 6),
    _Coord(8, 5), _Coord(8, 4), _Coord(8, 3), _Coord(8, 2), _Coord(8, 1), _Coord(8, 0),
    _Coord(7, 0), _Coord(6, 0),
  ];

  @override
  void initState() {
    super.initState();
    _gameState = LudoGameState.initial();
    _gameStartTime = DateTime.now();
    _setupActivePlayers();

    _diceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _diceRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _diceAnimationController, curve: Curves.easeInOut),
    );
  }

  void _setupActivePlayers() {
    switch (widget.cpuCount) {
      case 1:
        _activePlayers = ['yellow', 'red'];
        _cpuPlayers = ['red'];
        break;
      case 2:
        _activePlayers = ['yellow', 'green', 'red'];
        _cpuPlayers = ['green', 'red'];
        break;
      case 3:
      default:
        _activePlayers = ['yellow', 'green', 'blue', 'red'];
        _cpuPlayers = ['green', 'blue', 'red'];
        break;
    }
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    super.dispose();
  }

  Future<void> _rollDice() async {
    if (!_canRollDice || _gameEnded || _currentPlayer != 'yellow' || _isRollingDice) return;

    setState(() {
      _isRollingDice = true;
      _canRollDice = false;
      _movablePieces.clear();
      _selectedPieceColor = null;
      _selectedPieceId = null;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _waitingForNextMove = false;
    });

    _diceAnimationController.repeat();
    await Future.delayed(const Duration(milliseconds: 600));
    _diceAnimationController.stop();
    _diceAnimationController.reset();

    setState(() {
      _dice1Value = _random.nextInt(6) + 1;
      _dice2Value = _random.nextInt(6) + 1;
      _totalDiceValue = _dice1Value + _dice2Value;
      _isRollingDice = false;
      _updateConsecutiveDoubles(_dice1Value, _dice2Value);
    });

    await Future.delayed(const Duration(milliseconds: 300));
    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay movimientos válidos. Turno perdido.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      _nextTurn();
    }
  }

  void _updateConsecutiveDoubles(int d1, int d2) {
    if (d1 == d2 && d1 == _previousDice1 && d2 == _previousDice2) {
      _consecutiveDoubles++;
    } else if (d1 == d2) {
      _consecutiveDoubles = 1;
    } else {
      _consecutiveDoubles = 0;
    }
    _previousDice1 = d1;
    _previousDice2 = d2;
  }

  void _calculateMovablePieces() {
    _movablePieces.clear();
    final pieces = _gameState.getPiecesByColor(_currentPlayer);

    for (int i = 0; i < pieces.length; i++) {
      final piece = pieces[i];

      if (piece.isFinished) continue;

      if (piece.isHome) {
        if (!_hasUsedDice1 && _dice1Value == 5) {
          _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 1, 'piece': piece});
        }
        if (!_hasUsedDice2 && _dice2Value == 5 && _dice1Value != _dice2Value) {
          _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 2, 'piece': piece});
        }
      } else {
        if (!_hasUsedDice1 && _canMovePieceWithValue(piece, _dice1Value)) {
          _movablePieces.add({'pieceId': i, 'diceValue': _dice1Value, 'diceNumber': 1, 'piece': piece});
        }
        if (!_hasUsedDice2 && _dice1Value != _dice2Value && _canMovePieceWithValue(piece, _dice2Value)) {
          _movablePieces.add({'pieceId': i, 'diceValue': _dice2Value, 'diceNumber': 2, 'piece': piece});
        }
      }
    }
  }

  bool _canMovePieceWithValue(LudoPiece piece, int diceValue) {
    if (piece.isFinished) return false;
    if (piece.isHome) return diceValue == 5;

    final newPos = _calculateNewPosition(piece, diceValue, _currentPlayer);
    if (newPos == null) return false;

    if (_hasBarrierInPath(piece, diceValue, _currentPlayer)) return false;

    return _canLandOn(_currentPlayer, newPos, piece);
  }

  int? _calculateNewPosition(LudoPiece piece, int diceValue, String color) {
    if (piece.isHome) return _getStartPosition(color);

    if (piece.position >= 52) {
      final newPos = piece.position + diceValue;
      if (newPos > 57) return null;
      return newPos;
    }

    final startPos = _getStartPosition(color);
    final stepsFromStart = _stepsFromStart(piece.position, startPos);
    final newSteps = stepsFromStart + diceValue;

    if (newSteps == 51) return 57;

    if (newSteps > 51) {
      final stepsIntoStretch = newSteps - 51;
      if (stepsIntoStretch > 5) return null;
      return 52 + (stepsIntoStretch - 1);
    }

    return (startPos + newSteps) % 52;
  }

  int _stepsFromStart(int position, int startPos) {
    if (position >= startPos) return position - startPos;
    return (52 - startPos) + position;
  }

  bool _hasBarrierInPath(LudoPiece piece, int diceValue, String color) {
    if (piece.isHome || piece.position >= 52) return false;

    final startPos = _getStartPosition(color);

    for (int step = 1; step < diceValue; step++) {
      final stepsFromStart = _stepsFromStart(piece.position, startPos);
      final newSteps = stepsFromStart + step;
      if (newSteps >= 51) break;
      final checkPos = (startPos + newSteps) % 52;
      if (_isEnemyBarrierAt(checkPos, color)) return true;
    }

    return false;
  }

  bool _isEnemyBarrierAt(int position, String movingColor) {
    for (final enemyColor in _activePlayers) {
      if (enemyColor == movingColor) continue;
      final enemyPieces = _gameState.getPiecesByColor(enemyColor);
      int count = 0;
      for (final p in enemyPieces) {
        if (!p.isHome && !p.isFinished && p.position == position) count++;
      }
      if (count >= 2) return true;
    }
    return false;
  }

  bool _canLandOn(String color, int newPos, LudoPiece movingPiece) {
    if (newPos >= 52) return true;

    final myPieces = _gameState.getPiecesByColor(color);
    int myCount = 0;
    for (final p in myPieces) {
      if (p == movingPiece) continue;
      if (!p.isHome && !p.isFinished && p.position == newPos) myCount++;
    }
    return myCount < 2;
  }

  void _handleBoardTap(Offset localPosition) {
    if (_gameEnded || _currentPlayer != 'yellow' || _totalDiceValue == 0 ||
        _boardSize == 0 || _movablePieces.isEmpty) return;

    final squareSize = _boardSize / 15;
    final yellowPieces = _gameState.getPiecesByColor('yellow');
    final tapRadius = squareSize * 0.7;

    for (int i = 0; i < yellowPieces.length; i++) {
      final piece = yellowPieces[i];
      if (!_movablePieces.any((m) => m['pieceId'] == i)) continue;

      final piecePos = _getPieceScreenPosition(piece, 'yellow', squareSize);
      if (piecePos != null && (localPosition - piecePos).distance < tapRadius) {
        _showMovementSelectionDialog(i);
        return;
      }
    }
  }

  void _showMovementSelectionDialog(int pieceId) {
    final options = _movablePieces.where((m) => m['pieceId'] == pieceId).toList();
    if (options.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                options.length == 1 ? 'Mover ficha' : 'Selecciona tu movimiento',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFEC7A34)),
              ),
              const SizedBox(height: 20),
              ...options.map((option) {
                final diceValue = option['diceValue'] as int;
                final diceNumber = option['diceNumber'] as int;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _executePieceMove('yellow', pieceId, diceValue, diceNumber);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEC7A34), Color(0xFFFF9F5A)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFFEC7A34).withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDialogDice(diceValue),
                          const SizedBox(width: 12),
                          Text(
                            options.length == 1 ? 'Mover $diceValue casillas' : 'Dado $diceNumber: $diceValue',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogDice(int value) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(child: CustomPaint(size: const Size(40, 40), painter: DiceDotsPainter(value))),
    );
  }

  Offset? _getPieceScreenPosition(LudoPiece piece, String color, double squareSize) {
    if (piece.isHome) return _getHomeScreenPosition(color, piece.id, squareSize);
    if (piece.isFinished) return null;
    return _getBoardScreenPosition(piece, color, squareSize);
  }

  Offset? _getBoardScreenPosition(LudoPiece piece, String color, double squareSize) {
    final basePos = _getBoardPositionOffset(piece.position, squareSize);
    if (basePos == null) return null;

    final pieces = _gameState.getPiecesByColor(color);
    final piecesAtSamePos = pieces
        .where((p) => !p.isHome && !p.isFinished && p.position == piece.position)
        .toList();

    if (piecesAtSamePos.length <= 1) return basePos;

    final index = piecesAtSamePos.indexOf(piece);
    final offset = squareSize * 0.28;
    return index == 0 ? basePos - Offset(offset, 0) : basePos + Offset(offset, 0);
  }

  Offset _getHomeScreenPosition(String color, int pieceId, double squareSize) {
    const homes = {
      'yellow': _Coord(3, 3),
      'green': _Coord(12, 3),
      'blue': _Coord(3, 12),
      'red': _Coord(12, 12),
    };

    final base = homes[color]!;
    const off = 0.8;
    final positions = [
      Offset((base.col - off) * squareSize, (base.row - off) * squareSize),
      Offset((base.col + off) * squareSize, (base.row - off) * squareSize),
      Offset((base.col - off) * squareSize, (base.row + off) * squareSize),
      Offset((base.col + off) * squareSize, (base.row + off) * squareSize),
    ];
    return positions[pieceId];
  }

  Offset? _getBoardPositionOffset(int position, double squareSize) {
    if (position >= 0 && position < _boardPath.length) {
      final c = _boardPath[position];
      return Offset((c.col + 0.5) * squareSize, (c.row + 0.5) * squareSize);
    }
    return null;
  }

  void _executePieceMove(String color, int pieceId, int diceValue, int diceNumber) {
    if (color != _currentPlayer || _gameEnded) return;

    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return;

    final piece = pieces[pieceId];
    final newPosition = _calculateNewPosition(piece, diceValue, color);
    if (newPosition == null) return;
    if (!_canLandOn(color, newPosition, piece)) return;

    bool captured = false;

    if (newPosition < 52 && !_isSafePosition(newPosition)) {
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyPieces = _gameState.getPiecesByColor(enemyColor);
        for (final enemyPiece in enemyPieces) {
          if (!enemyPiece.isHome && !enemyPiece.isFinished && enemyPiece.position == newPosition) {
            setState(() {
              enemyPiece.position = -1;
            });
            captured = true;
          }
        }
      }
    }

    setState(() {
      piece.position = newPosition;
      if (newPosition == 57) piece.isFinished = true;
      if (diceNumber == 1) _hasUsedDice1 = true;
      else if (diceNumber == 2) _hasUsedDice2 = true;
    });

    if (_checkVictory(color)) {
      Future.delayed(const Duration(milliseconds: 500), () => _endGame(color));
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;
    _calculateMovablePieces();

    if (_movablePieces.isNotEmpty && !hadDouble && !captured) {
      setState(() => _waitingForNextMove = true);
      return;
    }

    setState(() {
      _dice1Value = 0;
      _dice2Value = 0;
      _totalDiceValue = 0;
      _movablePieces.clear();
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _waitingForNextMove = false;
    });

    if (hadDouble || captured) {
      setState(() => _canRollDice = true);
      if (_cpuPlayers.contains(color)) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_currentPlayer == color && !_gameEnded && _canRollDice) _playCpuTurn();
        });
      }
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_gameEnded) _nextTurn();
      });
    }
  }

  void _nextTurn() {
    if (_gameEnded) return;

    setState(() {
      final currentIndex = _activePlayers.indexOf(_currentPlayer);
      _currentPlayer = _activePlayers[(currentIndex + 1) % _activePlayers.length];
      _canRollDice = true;
      _dice1Value = 0;
      _dice2Value = 0;
      _totalDiceValue = 0;
      _movablePieces.clear();
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _waitingForNextMove = false;
      _consecutiveDoubles = 0;
      _previousDice1 = 0;
      _previousDice2 = 0;
    });

    if (_cpuPlayers.contains(_currentPlayer)) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!_gameEnded && _canRollDice && _cpuPlayers.contains(_currentPlayer)) {
          _playCpuTurn();
        }
      });
    }
  }

  Future<void> _playCpuTurn() async {
    if (_gameEnded || !_cpuPlayers.contains(_currentPlayer) || !_canRollDice) return;

    await Future.delayed(const Duration(milliseconds: 800));
    if (!_cpuPlayers.contains(_currentPlayer) || _gameEnded) return;

    setState(() {
      _dice1Value = _random.nextInt(6) + 1;
      _dice2Value = _random.nextInt(6) + 1;
      _totalDiceValue = _dice1Value + _dice2Value;
      _canRollDice = false;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _updateConsecutiveDoubles(_dice1Value, _dice2Value);
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!_cpuPlayers.contains(_currentPlayer) || _gameEnded) return;

    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
      await Future.delayed(const Duration(milliseconds: 500));
      if (_cpuPlayers.contains(_currentPlayer) && !_gameEnded) _nextTurn();
      return;
    }

    while (_movablePieces.isNotEmpty && _cpuPlayers.contains(_currentPlayer) && !_gameEnded) {
      final bestMove = _calculateBestCpuMove();
      if (bestMove == null) break;

      await Future.delayed(const Duration(milliseconds: 600));
      if (!_cpuPlayers.contains(_currentPlayer) || _gameEnded) break;

      _executePieceMove(_currentPlayer, bestMove['pieceId'], bestMove['diceValue'], bestMove['diceNumber']);

      if (_checkVictory(_currentPlayer)) break;
      await Future.delayed(const Duration(milliseconds: 400));

      if (_cpuPlayers.contains(_currentPlayer) && !_gameEnded) {
        _calculateMovablePieces();
      } else {
        break;
      }
    }
  }

  Map<String, dynamic>? _calculateBestCpuMove() {
    if (_movablePieces.isEmpty) return null;

    Map<String, dynamic>? bestMove;
    int bestScore = -1000;

    for (final move in _movablePieces) {
      final piece = move['piece'] as LudoPiece;
      int score = 0;

      if (piece.isFinished) continue;
      if (piece.position >= 52) score += 1000;
      if (piece.isHome && move['diceValue'] == 5) score += 500;
      if (!piece.isHome && piece.position < 52) {
        score += _stepsFromStart(piece.position, _getStartPosition(_currentPlayer)) * 10;
      }

      final diceValue = move['diceValue'] as int;
      final newPos = _calculateNewPosition(piece, diceValue, _currentPlayer);
      if (newPos != null && newPos < 52 && !_isSafePosition(newPos)) {
        for (final ec in _activePlayers) {
          if (ec == _currentPlayer) continue;
          for (final e in _gameState.getPiecesByColor(ec)) {
            if (!e.isHome && !e.isFinished && e.position == newPos) {
              score += 300;
              break;
            }
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  int _getStartPosition(String color) {
    switch (color) {
      case 'yellow': return 0;
      case 'blue':   return 13;
      case 'red':    return 26;
      case 'green':  return 39;
      default:       return 0;
    }
  }

  bool _isSafePosition(int position) {
    return position == 0 || position == 13 || position == 26 || position == 39;
  }

  bool _checkVictory(String color) {
    return _gameState.getPiecesByColor(color).every((p) => p.isFinished);
  }

  void _endGame(String winnerColor) {
    if (_gameEnded) return;
    setState(() => _gameEnded = true);

    final result = winnerColor == 'yellow' ? GameResultModel.win : GameResultModel.loss;
    _recordGameResult(result);
    _showGameEndDialog(
      winnerColor == 'yellow' ? '¡Ganaste! 🎉' : '${_getColorName(winnerColor)} ganó 🤖',
    );
  }

  String _getColorName(String color) {
    switch (color) {
      case 'yellow': return 'Amarillo';
      case 'green':  return 'Verde';
      case 'blue':   return 'Azul';
      case 'red':    return 'Rojo';
      default:       return color;
    }
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (_gameStartTime == null) return;
    try {
      final duration = DateTime.now().difference(_gameStartTime!).inMinutes;
      await _firestoreService.recordGameMatch(
        userId: 'current_user_id',
        gameType: GameTypeModel.ludo,
        result: result,
        pointsEarned: result == GameResultModel.win ? 20 : -5,
        durationMinutes: duration > 0 ? duration : 1,
        opponentName: 'CPU x${widget.cpuCount} (${widget.difficulty})',
        additionalData: {
          'difficulty': widget.difficulty,
          'playerColor': 'yellow',
          'matchType': widget.matchType,
          'cpuCount': widget.cpuCount,
        },
      );
    } catch (e) {
      debugPrint('Error recording game: $e');
    }
  }

  void _showGameEndDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              message.contains('Ganaste') ? Icons.emoji_events : Icons.sentiment_neutral,
              color: message.contains('Ganaste') ? Colors.amber : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(S.of(context).gameOver),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
            child: Text(S.of(context).exit),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _gameState = LudoGameState.initial();
                _currentPlayer = 'yellow';
                _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
                _canRollDice = true; _gameEnded = false;
                _gameStartTime = DateTime.now();
                _movablePieces.clear();
                _hasUsedDice1 = false; _hasUsedDice2 = false;
                _waitingForNextMove = false;
                _consecutiveDoubles = 0; _previousDice1 = 0; _previousDice2 = 0;
                _setupActivePlayers();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white),
            child: Text(S.of(context).playAgain),
          ),
        ],
      ),
    );
  }

  Color _getPlayerColor(String color) {
    switch (color) {
      case 'yellow': return const Color(0xFFFFD700);
      case 'green':  return const Color(0xFF00AA00);
      case 'red':    return const Color(0xFFFF3333);
      case 'blue':   return const Color(0xFF3366FF);
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7A34),
        title: Text(
          'Parchís vs ${widget.cpuCount} CPU${widget.cpuCount > 1 ? "s" : ""} - ${widget.difficulty}',
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildPlayersInfo(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: LayoutBuilder(builder: (context, constraints) {
                final size = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                _boardSize = size;

                return Center(
                  child: GestureDetector(
                    onTapUp: (details) => _handleBoardTap(details.localPosition),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: CustomPaint(
                        painter: LudoBoardPainter(
                          gameState: _gameState,
                          highlightedPieceColor: _selectedPieceColor,
                          highlightedPieceId: _selectedPieceId,
                          validMovePositions: _validMovePositions,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildPlayersInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: _activePlayers.map((color) {
          final isPlayer = color == 'yellow';
          final isActive = color == _currentPlayer;
          final pieces = _gameState.getPiecesByColor(color);
          final finishedCount = pieces.where((p) => p.isFinished).length;

          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? _getPlayerColor(color).withOpacity(0.15) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? _getPlayerColor(color) : Colors.grey.shade300,
                width: isActive ? 3 : 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPlayer ? 'Tú (${_getColorName(color)})' : 'CPU (${_getColorName(color)})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? _getPlayerColor(color) : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.flag, color: _getPlayerColor(color), size: 16),
                const SizedBox(width: 2),
                Text('$finishedCount/4', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _canRollDice && _currentPlayer == 'yellow' && !_gameEnded ? _rollDice : null,
                    child: _buildDice(_dice1Value, 0, !_hasUsedDice1),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _canRollDice && _currentPlayer == 'yellow' && !_gameEnded ? _rollDice : null,
                    child: _buildDice(_dice2Value, 1, !_hasUsedDice2),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _getPlayerColor(_currentPlayer).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getPlayerColor(_currentPlayer), width: 3),
                ),
                child: Column(
                  children: [
                    Text('Turno', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text(
                      _currentPlayer == 'yellow' ? 'TÚ' : 'CPU',
                      style: TextStyle(color: _getPlayerColor(_currentPlayer), fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    Text(
                      _getColorName(_currentPlayer),
                      style: TextStyle(color: _getPlayerColor(_currentPlayer), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_totalDiceValue > 0 && _currentPlayer == 'yellow' && _movablePieces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '👆 Toca una ficha amarilla para mover',
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (_consecutiveDoubles >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Text(
                  _consecutiveDoubles == 1 ? '🎲 ¡Dobles! Tira de nuevo' : '🎲🎲 ¡Doble-Doble! Turno extra',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDice(int value, int index, bool isAvailable) {
    final isActive = _canRollDice && _currentPlayer == 'yellow' && !_gameEnded;

    return AnimatedBuilder(
      animation: _diceRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _isRollingDice ? _diceRotation.value + (index * 0.5) : 0,
          child: Opacity(
            opacity: isAvailable ? 1.0 : 0.4,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAvailable
                      ? (isActive ? const Color(0xFFEC7A34) : Colors.grey.shade400)
                      : Colors.grey.shade600,
                  width: isAvailable ? 3 : 2,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: const Color(0xFFEC7A34).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(
                child: value > 0
                    ? CustomPaint(size: const Size(50, 50), painter: DiceDotsPainter(value))
                    : Icon(Icons.casino, size: 36, color: isActive ? const Color(0xFFEC7A34) : Colors.grey.shade500),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Coord {
  final int col;
  final int row;
  const _Coord(this.col, this.row);
}

class DiceDotsPainter extends CustomPainter {
  final int value;
  DiceDotsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final dotRadius = size.width * 0.08;
    final positions = <Offset>[];

    switch (value) {
      case 1:
        positions.add(Offset(size.width / 2, size.height / 2));
        break;
      case 2:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.3),
          Offset(size.width * 0.7, size.height * 0.7),
        ]);
        break;
      case 3:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.3),
          Offset(size.width / 2, size.height / 2),
          Offset(size.width * 0.7, size.height * 0.7),
        ]);
        break;
      case 4:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.3),
          Offset(size.width * 0.7, size.height * 0.3),
          Offset(size.width * 0.3, size.height * 0.7),
          Offset(size.width * 0.7, size.height * 0.7),
        ]);
        break;
      case 5:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.3),
          Offset(size.width * 0.7, size.height * 0.3),
          Offset(size.width / 2, size.height / 2),
          Offset(size.width * 0.3, size.height * 0.7),
          Offset(size.width * 0.7, size.height * 0.7),
        ]);
        break;
      case 6:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.25),
          Offset(size.width * 0.7, size.height * 0.25),
          Offset(size.width * 0.3, size.height * 0.5),
          Offset(size.width * 0.7, size.height * 0.5),
          Offset(size.width * 0.3, size.height * 0.75),
          Offset(size.width * 0.7, size.height * 0.75),
        ]);
        break;
    }

    for (final pos in positions) {
      canvas.drawCircle(pos, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(DiceDotsPainter oldDelegate) => oldDelegate.value != value;
}