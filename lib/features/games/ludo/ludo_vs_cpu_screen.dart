import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/models/ludo_game_match.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../../core/service/firestore_service.dart';
import 'ludo_board_painter.dart';

class LudoVsCpuScreen extends StatefulWidget {
  final String difficulty;
  final String matchType;
  final int cpuCount;

  const LudoVsCpuScreen({
    super.key,
    required this.difficulty,
    required this.matchType,
    this.cpuCount = 1,
  });

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

  bool _bonusSelectionActive = false;
  bool _bonusHadDouble = false;

  int _consecutiveDoubles = 0;

  Timer? _moveTimer;
  int _moveTimerSeconds = 0;
  static const int _moveTimeoutSeconds = 15;

  late AnimationController _diceAnimationController;
  late Animation<double> _diceRotation;
  bool _isRollingDice = false;

  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late AnimationController _turnOverlayController;

  late Animation<double> _bounceAnim;
  late Animation<double> _turnOverlayAnim;

  bool _showTurnOverlay = false;
  String _turnOverlayText = '';
  Color _turnOverlayColor = Colors.orange;

  String _toastMessage = '';
  bool _showToast = false;
  late AnimationController _toastController;
  late Animation<double> _toastAnim;

  final FirestoreService _firestoreService = FirestoreService();

  // RECORRIDO ANTIHORARIO:
  // Pos  0: Verde  sale col=6,row=1  → baja
  // Pos 13: Rojo   sale col=1,row=8  → va derecha
  // Pos 26: Azul   sale col=8,row=13 → sube
  // Pos 39: Amarillo sale col=13,row=6→ va izquierda
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

    _diceAnimationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _diceRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _diceAnimationController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);

    _bounceController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));

    _turnOverlayController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _turnOverlayAnim = CurvedAnimation(parent: _turnOverlayController, curve: Curves.easeOut);

    _toastController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _toastAnim = CurvedAnimation(parent: _toastController, curve: Curves.easeOut);
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
    _moveTimer?.cancel();
    _diceAnimationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _turnOverlayController.dispose();
    _toastController.dispose();
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
    _bounceController.forward(from: 0);

    if (_consecutiveDoubles >= 3) {
      await Future.delayed(const Duration(milliseconds: 500));
      _applyTripleDoublesPenalty(_currentPlayer);
      setState(() {
        _consecutiveDoubles = 0;
        _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      _nextTurn();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      _showEventToast('Sin movimientos válidos. Turno perdido.');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_gameEnded && mounted) _nextTurn();
    } else {
      _startMoveTimer();
    }
  }

  void _updateConsecutiveDoubles(int d1, int d2) {
    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }
  }

  void _showEventToast(String message, {Color color = Colors.orange}) {
    if (!mounted) return;
    setState(() { _toastMessage = message; _showToast = true; });
    _toastController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _toastController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  void _showTurnBanner(String color) {
    final isHuman = color == 'yellow';
    setState(() {
      _turnOverlayText = isHuman ? '¡TU TURNO!' : '${_getColorName(color).toUpperCase()} (CPU)';
      _turnOverlayColor = _getPlayerColor(color);
      _showTurnOverlay = true;
    });
    _turnOverlayController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _turnOverlayController.reverse().then((_) {
          if (mounted) setState(() => _showTurnOverlay = false);
        });
      }
    });
  }

  void _startMoveTimer() {
    _moveTimer?.cancel();
    if (!mounted) return;
    setState(() => _moveTimerSeconds = _moveTimeoutSeconds);
    _moveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _gameEnded || _currentPlayer != 'yellow') {
        timer.cancel();
        return;
      }
      setState(() => _moveTimerSeconds--);
      if (_moveTimerSeconds <= 0) {
        timer.cancel();
        _autoMove();
      }
    });
  }

  void _cancelMoveTimer() {
    _moveTimer?.cancel();
    _moveTimer = null;
    if (mounted) setState(() => _moveTimerSeconds = 0);
  }

  void _autoMove() {
    if (_movablePieces.isEmpty || _gameEnded) return;
    final best = _movablePieces.reduce((a, b) {
      final pa = a['piece'] as LudoPiece;
      final pb = b['piece'] as LudoPiece;
      if (pa.isHome && !pb.isHome) return b;
      if (!pa.isHome && pb.isHome) return a;
      final stA = pa.isHome ? -1 : _stepsFromStart(pa.position, _getStartPosition('yellow'));
      final stB = pb.isHome ? -1 : _stepsFromStart(pb.position, _getStartPosition('yellow'));
      return stA >= stB ? a : b;
    });
    _executePieceMove('yellow', best['pieceId'] as int, best['diceValue'] as int, best['diceNumber'] as int);
  }

  void _calculateMovablePieces() {
    _movablePieces.clear();
    final pieces = _gameState.getPiecesByColor(_currentPlayer);

    for (int i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.isFinished) continue;

      if (piece.isHome) {
        if (!_hasUsedDice1 && _dice1Value == 5) {
          final startPos = _getStartPosition(_currentPlayer);
          if (_canLandOn(_currentPlayer, startPos, piece)) {
            _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 1, 'piece': piece});
          }
        }
        if (!_hasUsedDice2 && _dice2Value == 5 && (_dice1Value != _dice2Value || _hasUsedDice1)) {
          final startPos = _getStartPosition(_currentPlayer);
          if (_canLandOn(_currentPlayer, startPos, piece)) {
            _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 2, 'piece': piece});
          }
        }
      } else {
        if (!_hasUsedDice1 && _canMovePieceWithValue(piece, _dice1Value)) {
          _movablePieces.add({'pieceId': i, 'diceValue': _dice1Value, 'diceNumber': 1, 'piece': piece});
        }
        if (!_hasUsedDice2 && (_dice1Value != _dice2Value || _hasUsedDice1) &&
            _canMovePieceWithValue(piece, _dice2Value)) {
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

    if (newSteps > 50) {
      final stepsIntoStretch = newSteps - 51;
      if (stepsIntoStretch > 5) return null;
      return 52 + stepsIntoStretch;
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
    final stepsFromStart = _stepsFromStart(piece.position, startPos);

    for (int step = 1; step < diceValue; step++) {
      final newSteps = stepsFromStart + step;
      if (newSteps > 51) break; // posiciones >= 52 son la recta final (no hay barreras enemigas ahí)
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

    if (_isEnemyBarrierAt(newPos, color)) return false;

    // No permitir una 3ra ficha del mismo color en la misma casilla (máximo 2 = barrera)
    final sameColorCount = _gameState.getPiecesByColor(color)
        .where((p) => p != movingPiece && !p.isHome && !p.isFinished && p.position == newPos)
        .length;
    if (sameColorCount >= 2) return false;

    // La casilla de salida de cada color es exclusiva:
    // ningún enemigo puede aterrizar ahí si hay fichas del dueño
    for (final ownerColor in _activePlayers) {
      if (ownerColor == color) continue;
      final ownerStart = _getStartPosition(ownerColor);
      if (newPos == ownerStart) {
        final ownerPieces = _gameState.getPiecesByColor(ownerColor);
        final ownerCount = ownerPieces.where(
                (p) => !p.isHome && !p.isFinished && p.position == ownerStart
        ).length;
        if (ownerCount > 0) return false;
      }
    }

    return true;
  }

  void _handleBoardTap(Offset localPosition) {
    if (_gameEnded || _currentPlayer != 'yellow' || _boardSize == 0) return;

    final squareSize = _boardSize / 15;
    final yellowPieces = _gameState.getPiecesByColor('yellow');
    final tapRadius = squareSize * 0.7;

    if (_bonusSelectionActive) {
      // Modo bonus: el jugador toca la ficha que quiere que reciba el +20
      for (int i = 0; i < yellowPieces.length; i++) {
        final piece = yellowPieces[i];
        final hasBonusMove = _movablePieces.any((m) => m['pieceId'] == i);
        if (!hasBonusMove) continue;

        final piecePos = _getPieceScreenPosition(piece, 'yellow', squareSize);
        if (piecePos != null && (localPosition - piecePos).distance < tapRadius) {
          _showBonusConfirmDialog(i);
          return;
        }
      }
      return;
    }

    if (_totalDiceValue == 0 || _movablePieces.isEmpty) return;

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

  void _showBonusConfirmDialog(int pieceId) {
    final opt = _movablePieces.firstWhere((m) => m['pieceId'] == pieceId, orElse: () => {});
    if (opt.isEmpty) return;

    final p = opt['piece'] as LudoPiece;
    final bonusPos = opt['bonusPos'] as int;
    final hadDouble = _bonusHadDouble;
    final isSafe = bonusPos >= 52 || _isSafeForColor(bonusPos, 'yellow');
    final willCapture = bonusPos < 52 && !_isSafeForColor(bonusPos, 'yellow') &&
        _activePlayers.any((ec) => ec != 'yellow' &&
            _gameState.getPiecesByColor(ec).any((e) => !e.isHome && !e.isFinished && e.position == bonusPos));

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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯 Bonus +20 casillas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEC7A34))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: willCapture
                        ? [const Color(0xFFE53935), const Color(0xFFEF5350)]
                        : [const Color(0xFF00897B), const Color(0xFF26A69A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                      child: Center(
                        child: Text('${pieceId + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ficha ${pieceId + 1}  •  Casilla ${p.position} → $bonusPos',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            willCapture ? '🔥 ¡Comerá otra ficha!' : isSafe ? '⭐ Casilla segura' : '➡ Avanza +20',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _bonusSelectionActive = false;
                          _movablePieces.clear();
                        });
                        _applyBonusTopiece('yellow', p, bonusPos, hadDouble);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC7A34),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Mover', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
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
                        boxShadow: [BoxShadow(color: const Color(0xFFEC7A34).withValues(alpha: 0.3), blurRadius: 5, offset: const Offset(0, 3))],
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
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(child: CustomPaint(size: const Size(40, 40), painter: DiceDotsPainter(value))),
    );
  }

  Offset? _getPieceScreenPosition(LudoPiece piece, String color, double squareSize) {
    if (piece.isHome) return _getHomeScreenPosition(color, piece.id, squareSize);
    if (piece.isFinished) return null;
    if (piece.position >= 52 && piece.position <= 56) {
      return _getHomeStretchScreenPosition(color, piece.position, squareSize);
    }
    return _getBoardScreenPosition(piece, color, squareSize);
  }

  // Debe coincidir exactamente con _getHomeStretchBoardPosition del painter
  Offset _getHomeStretchScreenPosition(String color, int position, double squareSize) {
    final si = position - 52;
    switch (color) {
      case 'green':
        return Offset(7.5 * squareSize, (1.5 + si) * squareSize);
      case 'red':
        return Offset((1.5 + si) * squareSize, 7.5 * squareSize);
      case 'blue':
        return Offset(7.5 * squareSize, (13.5 - si) * squareSize);
      case 'yellow':
        return Offset((13.5 - si) * squareSize, 7.5 * squareSize);
      default:
        return Offset(7.5 * squareSize, 7.5 * squareSize);
    }
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
      'green':  _Coord(3, 3),
      'yellow': _Coord(12, 3),
      'red':    _Coord(3, 12),
      'blue':   _Coord(12, 12),
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
    if (color == 'yellow') _cancelMoveTimer();

    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return;

    final piece = pieces[pieceId];
    final newPosition = _calculateNewPosition(piece, diceValue, color);
    if (newPosition == null) return;
    if (!_canLandOn(color, newPosition, piece)) return;

    bool captured = false;

    // Capturar ANTES de mover la ficha propia
    if (newPosition < 52 && !_isSafeForColor(newPosition, color)) {
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyPieces = _gameState.getPiecesByColor(enemyColor);
        for (final enemyPiece in enemyPieces) {
          if (!enemyPiece.isHome && !enemyPiece.isFinished && enemyPiece.position == newPosition) {
            setState(() { enemyPiece.position = -1; });
            captured = true;
          }
        }
      }
    }

    setState(() {
      piece.position = newPosition;
      if (newPosition == 57) piece.isFinished = true;
      if (diceNumber == 1) {
        _hasUsedDice1 = true;
      } else if (diceNumber == 2) {
        _hasUsedDice2 = true;
      }
    });

    if (_checkVictory(color)) {
      Future.delayed(const Duration(milliseconds: 500), () => _endGame(color));
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;

    if (captured) {
      // Limpiar dados antes del bonus para que el jugador elija qué ficha mueve +20
      setState(() {
        _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
        _movablePieces.clear();
        _hasUsedDice1 = false; _hasUsedDice2 = false;
      });
      _applyCaptureBonusWithSelection(color, piece, hadDouble);
      return;
    }

    _calculateMovablePieces();

    // Si quedan movimientos del segundo dado, esperar selección
    if (_movablePieces.isNotEmpty) {
      if (color == 'yellow') _startMoveTimer();
      return;
    }

    setState(() {
      _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
      _movablePieces.clear();
      _hasUsedDice1 = false; _hasUsedDice2 = false;
    });

    if (hadDouble) {
      setState(() => _canRollDice = true);
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_gameEnded) _nextTurn();
      });
    }
  }

  void _applyCaptureBonusWithSelection(String color, LudoPiece capturedBy, bool hadDouble) {
    if (!mounted) return;

    final allPieces = _gameState.getPiecesByColor(color);
    final bonusMoves = <Map<String, dynamic>>[];

    for (int i = 0; i < allPieces.length; i++) {
      final p = allPieces[i];
      if (p.isFinished || p.isHome) continue;
      final bonusPos = _calculateCaptureBonusPosition(p, color);
      if (bonusPos == null) continue;
      if (bonusPos < 52 && _isEnemyBarrierAt(bonusPos, color)) continue;
      if (bonusPos < 52 && !_isSafeForColor(bonusPos, color)) {
        final samePos = allPieces.where((q) => q != p && !q.isHome && !q.isFinished && q.position == bonusPos).length;
        if (samePos >= 2) continue;
      }
      bonusMoves.add({'pieceId': i, 'piece': p, 'bonusPos': bonusPos, 'diceValue': 20, 'diceNumber': 0});
    }

    if (bonusMoves.isEmpty) {
      _showEventToast('¡Comiste! Sin bonus disponible 🎯');
      _resolveTurnAfterCapture(hadDouble);
      return;
    }

    if (color != 'yellow') {
      final best = bonusMoves.reduce((a, b) {
        final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition(color));
        final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition(color));
        return stA >= stB ? a : b;
      });
      _applyBonusTopiece(color, best['piece'] as LudoPiece, best['bonusPos'] as int, hadDouble);
      return;
    }

    // Jugador humano: guardar bonusMoves para que el jugador toque la ficha
    setState(() {
      _movablePieces = bonusMoves;
      _bonusSelectionActive = true;
      _bonusHadDouble = hadDouble;
    });
    _showEventToast('🎯 ¡Comiste! Toca la ficha que quieres mover +20');
  }

  void _resolveTurnAfterCapture(bool hadDouble) {
    if (hadDouble) {
      setState(() => _canRollDice = true);
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_gameEnded) _nextTurn();
      });
    }
  }

  void _applyBonusTopiece(String color, LudoPiece piece, int bonusPos, bool hadDouble) {
    if (!mounted || piece.isFinished) return;

    if (bonusPos < 52 && !_isSafeForColor(bonusPos, color)) {
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyList = _gameState.getPiecesByColor(enemyColor)
            .where((p) => !p.isHome && !p.isFinished && p.position == bonusPos)
            .toList();
        if (enemyList.length == 1) {
          setState(() => enemyList[0].position = -1);
          _showEventToast('¡Comiste otra! 🔥');
        }
      }
    }

    setState(() {
      piece.position = bonusPos;
      if (bonusPos == 57) piece.isFinished = true;
    });

    if (_checkVictory(color)) {
      Future.delayed(const Duration(milliseconds: 500), () => _endGame(color));
      return;
    }

    _resolveTurnAfterCapture(hadDouble);
  }

  void _nextTurn() {
    if (_gameEnded) return;
    _cancelMoveTimer();

    setState(() {
      final currentIndex = _activePlayers.indexOf(_currentPlayer);
      _currentPlayer = _activePlayers[(currentIndex + 1) % _activePlayers.length];
      _canRollDice = true;
      _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
      _movablePieces.clear();
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _consecutiveDoubles = 0;
      _bonusSelectionActive = false;
      _bonusHadDouble = false;
    });
    _showTurnBanner(_currentPlayer);

    if (_cpuPlayers.contains(_currentPlayer)) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!_gameEnded && _canRollDice && _cpuPlayers.contains(_currentPlayer) && mounted) {
          _playCpuTurn();
        }
      });
    }
  }

  Future<void> _playCpuTurn() async {
    if (_gameEnded || !_cpuPlayers.contains(_currentPlayer) || !_canRollDice) return;
    if (!mounted) return;

    final String cpuColor = _currentPlayer;

    await Future.delayed(const Duration(milliseconds: 800));
    if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;

    setState(() {
      _dice1Value = _random.nextInt(6) + 1;
      _dice2Value = _random.nextInt(6) + 1;
      _totalDiceValue = _dice1Value + _dice2Value;
      _canRollDice = false;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _updateConsecutiveDoubles(_dice1Value, _dice2Value);
    });

    if (_consecutiveDoubles >= 3) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _applyTripleDoublesPenalty(cpuColor);
      setState(() {
        _consecutiveDoubles = 0;
        _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_gameEnded && mounted) _nextTurn();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;

    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_gameEnded && mounted) _nextTurn();
      return;
    }

    final bool hadDoubles = _dice1Value == _dice2Value;
    bool gotCapture = false;

    for (int attempt = 0; attempt < 2; attempt++) {
      if (_movablePieces.isEmpty) break;
      if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;

      final bestMove = _calculateBestCpuMove();
      if (bestMove == null) break;

      await Future.delayed(const Duration(milliseconds: 700));
      if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;

      gotCapture = _doCpuMove(cpuColor, bestMove['pieceId'] as int, bestMove['diceValue'] as int, bestMove['diceNumber'] as int);

      if (_checkVictory(cpuColor)) { _endGame(cpuColor); return; }
      if (gotCapture) break;

      await Future.delayed(const Duration(milliseconds: 400));
      if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;
      _calculateMovablePieces();
    }

    setState(() {
      _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
      _movablePieces.clear();
      _hasUsedDice1 = false; _hasUsedDice2 = false;
    });

    if (_gameEnded || !mounted) return;

    if (hadDoubles || gotCapture) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!_gameEnded && _currentPlayer == cpuColor && mounted) {
        setState(() => _canRollDice = true);
        _playCpuTurn();
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_gameEnded && mounted) _nextTurn();
    }
  }

  bool _doCpuMove(String color, int pieceId, int diceValue, int diceNumber) {
    if (color != _currentPlayer || _gameEnded) return false;

    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return false;

    final piece = pieces[pieceId];
    final newPosition = _calculateNewPosition(piece, diceValue, color);
    if (newPosition == null) return false;
    if (!_canLandOn(color, newPosition, piece)) return false;

    bool captured = false;

    if (newPosition < 52 && !_isSafeForColor(newPosition, color)) {
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        for (final enemyPiece in _gameState.getPiecesByColor(enemyColor)) {
          if (!enemyPiece.isHome && !enemyPiece.isFinished && enemyPiece.position == newPosition) {
            setState(() => enemyPiece.position = -1);
            captured = true;
          }
        }
      }
    }

    setState(() {
      piece.position = newPosition;
      if (newPosition == 57) piece.isFinished = true;
      if (diceNumber == 1) {
        _hasUsedDice1 = true;
      } else if (diceNumber == 2) {
        _hasUsedDice2 = true;
      }
    });

    if (captured) _applyCpuCaptureBonus(color);

    return captured;
  }

  void _applyCpuCaptureBonus(String color) {
    final allPieces = _gameState.getPiecesByColor(color);
    final bonusMoves = <Map<String, dynamic>>[];

    for (int i = 0; i < allPieces.length; i++) {
      final p = allPieces[i];
      if (p.isFinished || p.isHome) continue;
      final bonusPos = _calculateCaptureBonusPosition(p, color);
      if (bonusPos == null) continue;
      if (bonusPos < 52 && _isEnemyBarrierAt(bonusPos, color)) continue;
      if (bonusPos < 52 && !_isSafeForColor(bonusPos, color)) {
        final samePos = allPieces.where((q) => q != p && !q.isHome && !q.isFinished && q.position == bonusPos).length;
        if (samePos >= 2) continue;
      }
      bonusMoves.add({'piece': p, 'bonusPos': bonusPos});
    }

    if (bonusMoves.isEmpty) return;

    final best = bonusMoves.reduce((a, b) {
      final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition(color));
      final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition(color));
      return stA >= stB ? a : b;
    });

    final bestPiece = best['piece'] as LudoPiece;
    final bonusPos = best['bonusPos'] as int;

    // Capturar ficha enemiga si hay una sola en la posición destino
    if (bonusPos < 52 && !_isSafeForColor(bonusPos, color)) {
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyList = _gameState.getPiecesByColor(enemyColor)
            .where((p) => !p.isHome && !p.isFinished && p.position == bonusPos)
            .toList();
        if (enemyList.length == 1) {
          setState(() => enemyList[0].position = -1);
        }
      }
    }

    setState(() {
      bestPiece.position = bonusPos;
      if (bonusPos == 57) bestPiece.isFinished = true;
    });
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
      if (newPos != null && newPos < 52 && !_isSafeForColor(newPos, _currentPlayer)) {
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

      if (score > bestScore) { bestScore = score; bestMove = move; }
    }

    return bestMove;
  }

  int? _calculateCaptureBonusPosition(LudoPiece piece, String color) {
    const bonus = 20;
    if (piece.position >= 52) {
      final newPos = piece.position + bonus;
      return newPos >= 57 ? 57 : newPos;
    }
    final startPos = _getStartPosition(color);
    final newSteps = _stepsFromStart(piece.position, startPos) + bonus;
    if (newSteps > 50) {
      final into = newSteps - 51;
      if (into > 5) return 57;
      return 52 + into;
    }
    return (startPos + newSteps) % 52;
  }

  void _applyTripleDoublesPenalty(String color) {
    final pieces = _gameState.getPiecesByColor(color);
    final activePieces = pieces.where((p) => !p.isHome && !p.isFinished).toList();

    if (activePieces.length < 2) return;

    LudoPiece? furthest;
    int maxSteps = -1;

    for (final piece in activePieces) {
      final steps = piece.position >= 52
          ? 51 + (piece.position - 51)
          : _stepsFromStart(piece.position, _getStartPosition(color));
      if (steps > maxSteps) { maxSteps = steps; furthest = piece; }
    }

    if (furthest != null) {
      setState(() => furthest!.position = -1);
      _showEventToast('¡Triple doble! Ficha enviada a casa 😱', color: Colors.red.shade700);
    }
  }

  // Posiciones de inicio en el camino exterior:
  // Verde  = 0  (col=6, row=1)
  // Rojo   = 13 (col=1, row=8)
  // Azul   = 26 (col=8, row=13)
  // Amarillo = 39 (col=13, row=6)
  int _getStartPosition(String color) {
    switch (color) {
      case 'green':  return 0;
      case 'red':    return 13;
      case 'blue':   return 26;
      case 'yellow': return 39;
      default:       return 0;
    }
  }

  bool _isSafePosition(int position) {
    const safePositions = {0, 4, 8, 13, 17, 21, 26, 30, 34, 39, 43, 47};
    return safePositions.contains(position);
  }

  // Devuelve true si la posición es segura para el color dado.
  // Las casillas de salida solo son seguras para su color dueño.
  bool _isSafeForColor(int position, String color) {
    // Casillas de salida: solo seguras para el dueño
    final startPositions = {
      'green': 0, 'red': 13, 'blue': 26, 'yellow': 39,
    };
    for (final entry in startPositions.entries) {
      if (position == entry.value) {
        return entry.key == color; // segura solo para el dueño
      }
    }
    // Resto de casillas seguras: seguras para todos
    return _isSafePosition(position);
  }

  bool _checkVictory(String color) {
    return _gameState.getPiecesByColor(color).every((p) => p.isFinished);
  }

  void _endGame(String winnerColor) {
    if (_gameEnded) return;
    setState(() => _gameEnded = true);

    final result = winnerColor == 'yellow' ? GameResultModel.win : GameResultModel.loss;
    _recordGameResult(result);
    _showGameEndDialog(winnerColor == 'yellow' ? '¡Ganaste! 🎉' : '${_getColorName(winnerColor)} ganó 🤖');
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
    final isWin = message.contains('Ganaste');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isWin ? Colors.amber : const Color(0xFFEC7A34), width: 2),
            boxShadow: [BoxShadow(
              color: isWin ? Colors.amber.withValues(alpha: 0.25) : const Color(0xFFEC7A34).withValues(alpha: 0.25),
              blurRadius: 24, spreadRadius: 4,
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isWin ? '🏆' : '😔', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                isWin ? '¡VICTORIA!' : 'FIN DEL JUEGO',
                style: TextStyle(
                  color: isWin ? Colors.amber.shade700 : const Color(0xFFEC7A34),
                  fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.black87, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Salir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
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
                          _consecutiveDoubles = 0;
                          _setupActivePlayers();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: const Text('Jugar de nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Parchís vs ${widget.cpuCount} CPU${widget.cpuCount > 1 ? "s" : ""} - ${widget.difficulty}',
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 2,
      ),
      body: Stack(
        children: [
          Column(
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
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulseController, _diceRotation]),
                          builder: (context, _) {
                            final movableKeys = <String>{};
                            if (_currentPlayer == 'yellow') {
                              for (final m in _movablePieces) {
                                movableKeys.add('yellow-${m['pieceId']}');
                              }
                            }
                            return Container(
                              width: size, height: size,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getPlayerColor(_currentPlayer).withValues(alpha: 0.35),
                                    blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CustomPaint(
                                  painter: LudoBoardPainter(
                                    gameState: _gameState,
                                    highlightedPieceColor: _selectedPieceColor,
                                    highlightedPieceId: _selectedPieceId,
                                    validMovePositions: _validMovePositions,
                                    pulseValue: _pulseController.value,
                                    movableKeys: movableKeys,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
              _buildControls(),
            ],
          ),
          if (_showTurnOverlay)
            Positioned(
              top: 100, left: 0, right: 0,
              child: AnimatedBuilder(
                animation: _turnOverlayAnim,
                builder: (context, _) {
                  return Opacity(
                    opacity: _turnOverlayAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, -20 * (1 - _turnOverlayAnim.value)),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              _turnOverlayColor.withValues(alpha: 0.95),
                              _turnOverlayColor.withValues(alpha: 0.75),
                            ]),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: _turnOverlayColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
                          ),
                          child: Text(
                            _turnOverlayText,
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900,
                              fontSize: 22, letterSpacing: 2,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_showToast)
            Positioned(
              bottom: 140, left: 24, right: 24,
              child: AnimatedBuilder(
                animation: _toastAnim,
                builder: (context, _) {
                  return Opacity(
                    opacity: _toastAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _toastAnim.value)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
                        ),
                        child: Text(
                          _toastMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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

  Widget _buildPlayersInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _activePlayers.map((color) {
          final isPlayer = color == 'yellow';
          final isActive = color == _currentPlayer;
          final pieces = _gameState.getPiecesByColor(color);
          final finishedCount = pieces.where((p) => p.isFinished).length;
          final playerColor = _getPlayerColor(color);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? playerColor.withValues(alpha: 0.12) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? playerColor : Colors.grey.shade300, width: isActive ? 2.5 : 1),
              boxShadow: isActive
                  ? [BoxShadow(color: playerColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: playerColor, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: playerColor.withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPlayer ? 'Tú' : 'CPU',
                      style: TextStyle(
                        color: isActive ? playerColor : Colors.black87,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 4),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: playerColor, shape: BoxShape.circle)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: finishedCount / 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(playerColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$finishedCount/4',
                  style: TextStyle(color: isActive ? playerColor : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControls() {
    final isMyTurn = _currentPlayer == 'yellow' && !_gameEnded;
    final canRoll = isMyTurn && _canRollDice;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (context, _) => Transform.scale(
                      scale: _dice1Value > 0 ? _bounceAnim.value : 1.0,
                      child: _buildDice(_dice1Value, 0, !_hasUsedDice1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: _bounceAnim,
                    builder: (context, _) => Transform.scale(
                      scale: _dice2Value > 0 ? _bounceAnim.value : 1.0,
                      child: _buildDice(_dice2Value, 1, !_hasUsedDice2),
                    ),
                  ),
                ],
              ),
              if (canRoll)
                GestureDetector(
                  onTap: _rollDice,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final glow = 0.3 + _pulseController.value * 0.4;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC7A34), Color(0xFFFF9F5A)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFFEC7A34).withValues(alpha: glow), blurRadius: 18, spreadRadius: 3)],
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.casino_rounded, color: Colors.white, size: 28),
                            SizedBox(height: 4),
                            Text('LANZAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _getPlayerColor(_currentPlayer).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _getPlayerColor(_currentPlayer), width: 2.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPlayer == 'yellow' ? 'TU TURNO' : 'CPU',
                        style: TextStyle(color: _getPlayerColor(_currentPlayer), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text(_getColorName(_currentPlayer),
                          style: TextStyle(color: _getPlayerColor(_currentPlayer).withValues(alpha: 0.8), fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
          if (isMyTurn && _movablePieces.isNotEmpty && !_canRollDice)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _bonusSelectionActive ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bonusSelectionActive ? Colors.green.shade300 : Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _bonusSelectionActive ? Icons.star : Icons.touch_app,
                      color: _bonusSelectionActive ? Colors.green.shade700 : Colors.blue.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _bonusSelectionActive
                          ? '🎯 Toca la ficha que recibirá +20'
                          : 'Toca una ficha para mover',
                      style: TextStyle(
                        color: _bonusSelectionActive ? Colors.green.shade900 : Colors.blue.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_moveTimerSeconds > 0 && !_bonusSelectionActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _moveTimerSeconds <= 5 ? Colors.red : Colors.blue.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_moveTimerSeconds}s',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_consecutiveDoubles >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎲', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      _consecutiveDoubles == 1
                          ? '¡Dobles! Tira de nuevo'
                          : '¡Dobles x2! ⚠ Otro doble = penalización',
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDice(int value, int index, bool isAvailable) {
    const activeColor = Color(0xFFEC7A34);

    return AnimatedBuilder(
      animation: _diceRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _isRollingDice ? _diceRotation.value + (index * 0.5) : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isAvailable ? 1.0 : 0.35,
            child: Container(
              width: 66, height: 66,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade100],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAvailable ? (value > 0 ? activeColor : Colors.grey.shade400) : Colors.grey.shade600,
                  width: isAvailable && value > 0 ? 2.5 : 1.5,
                ),
                boxShadow: isAvailable && value > 0
                    ? [
                  BoxShadow(color: activeColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3),
                ]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3)],
              ),
              child: Center(
                child: value > 0
                    ? CustomPaint(size: const Size(48, 48), painter: DiceDotsPainter(value, isAvailable))
                    : Icon(Icons.casino_rounded, size: 34,
                    color: _canRollDice && _currentPlayer == 'yellow' ? activeColor : Colors.grey.shade400),
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
  final bool isAvailable;
  DiceDotsPainter(this.value, [this.isAvailable = true]);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = isAvailable ? const Color(0xFF1A1A2E) : Colors.grey..style = PaintingStyle.fill;
    final dotRadius = size.width * 0.08;
    final positions = <Offset>[];

    switch (value) {
      case 1:
        positions.add(Offset(size.width / 2, size.height / 2));
        break;
      case 2:
        positions.addAll([Offset(size.width * 0.3, size.height * 0.3), Offset(size.width * 0.7, size.height * 0.7)]);
        break;
      case 3:
        positions.addAll([Offset(size.width * 0.3, size.height * 0.3), Offset(size.width / 2, size.height / 2), Offset(size.width * 0.7, size.height * 0.7)]);
        break;
      case 4:
        positions.addAll([Offset(size.width * 0.3, size.height * 0.3), Offset(size.width * 0.7, size.height * 0.3), Offset(size.width * 0.3, size.height * 0.7), Offset(size.width * 0.7, size.height * 0.7)]);
        break;
      case 5:
        positions.addAll([Offset(size.width * 0.3, size.height * 0.3), Offset(size.width * 0.7, size.height * 0.3), Offset(size.width / 2, size.height / 2), Offset(size.width * 0.3, size.height * 0.7), Offset(size.width * 0.7, size.height * 0.7)]);
        break;
      case 6:
        positions.addAll([
          Offset(size.width * 0.3, size.height * 0.25), Offset(size.width * 0.7, size.height * 0.25),
          Offset(size.width * 0.3, size.height * 0.5),  Offset(size.width * 0.7, size.height * 0.5),
          Offset(size.width * 0.3, size.height * 0.75), Offset(size.width * 0.7, size.height * 0.75),
        ]);
        break;
    }

    for (final pos in positions) {
      canvas.drawCircle(pos, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(DiceDotsPainter oldDelegate) => oldDelegate.value != value || oldDelegate.isAvailable != isAvailable;
}