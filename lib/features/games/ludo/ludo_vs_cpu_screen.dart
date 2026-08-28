import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
    super.key,
    required this.difficulty,
    required this.matchType,
    this.cpuCount = 1,
  });

  @override
  State<LudoVsCpuScreen> createState() => _LudoVsCpuScreenState();
}

class _LudoVsCpuScreenState extends State<LudoVsCpuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  final Map<String, int> _missedFive = {};
  int _humanHomeDoubles = 0;
  int _cpuHomeDoubles = 0;

  bool get _isUltra => widget.difficulty.toLowerCase().contains('ultra');

  int _rollCpuDice() {
    final r = _random.nextDouble();
    if (_isUltra) {
      if (r < 0.01) return 1;
      if (r < 0.03) return 2;
      if (r < 0.06) return 3;
      if (r < 0.12) return 4;
      if (r < 0.52) return 5;
      return 6;
    }
    if (r < 0.02) return 1;
    if (r < 0.05) return 2;
    if (r < 0.10) return 3;
    if (r < 0.18) return 4;
    if (r < 0.55) return 5;
    return 6;
  }

  int _rollCpuDiceNoDouble(int exclude) {
    int v;
    do { v = _rollCpuDice(); } while (v == exclude);
    return v;
  }

  DateTime? _gameStartTime;
  double _boardSize = 0;

  String? _selectedPieceColor;
  int? _selectedPieceId;
  final List<int> _validMovePositions = [];
  List<Map<String, dynamic>> _movablePieces = [];
  Set<int> _bridgeBreakPieceIds = {};

  bool _hasUsedDice1 = false;
  bool _hasUsedDice2 = false;

  bool _bonusSelectionActive = false;
  bool _bonusHadDouble = false;

  int _consecutiveDoubles = 0;
  final Map<String, int?> _lastMovedPieceId = {};

  Timer? _moveTimer;
  int _moveTimerSeconds = 0;
  static const int _moveTimeoutSeconds = 15;

  Timer? _afkRollTimer;
  static const int _afkRollTimeoutSeconds = 15;
  DateTime? _pausedAt;
  int _savedMoveTimerSeconds = 0;

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
  User? get _currentUser => FirebaseAuth.instance.currentUser;


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
    WidgetsBinding.instance.addObserver(this);
    _enableWakeLock();
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAndDeductGameCost();
      _startAfkRollTimer();
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _moveTimer?.cancel();
    _afkRollTimer?.cancel();
    _diceAnimationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    _turnOverlayController.dispose();
    _toastController.dispose();
    super.dispose();
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableWakeLock();
      if (_pausedAt != null && !_gameEnded && _currentPlayer == 'yellow') {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
        if (_savedMoveTimerSeconds > 0) {
          final remaining = (_savedMoveTimerSeconds - elapsed).clamp(0, _moveTimeoutSeconds);
          if (remaining > 0) {
            _startMoveTimer(remaining);
          } else {
            _autoMove();
          }
        }
      } else {
        _pausedAt = null;
      }
    } else if (state == AppLifecycleState.paused) {
      _disableWakeLock();
      _savedMoveTimerSeconds = _moveTimerSeconds;
      _pausedAt = DateTime.now();
      _moveTimer?.cancel();
      _afkRollTimer?.cancel();
    }
  }


  Future<void> _autoRollAndMove() async {
    if (_gameEnded || _currentPlayer != 'yellow') return;
    final autoPieces = _gameState.getPiecesByColor(_currentPlayer);
    final allInHome = autoPieces.every((p) => p.isHome);
    int d1auto = 0, d2auto = 0;

    do {
      d1auto = _random.nextInt(6) + 1;
      d2auto = _random.nextInt(6) + 1;
      final autoHasHome = autoPieces.any((p) => p.isHome);
      final autoMissed = _missedFive[_currentPlayer] ?? 0;
      if (autoMissed >= 3 && autoHasHome && d1auto != 5 && d2auto != 5) {
        if (_random.nextBool()) { d1auto = 5; } else { d2auto = 5; }
      }
      _missedFive[_currentPlayer] = (autoHasHome && d1auto != 5 && d2auto != 5) ? autoMissed + 1 : 0;

      if (allInHome && d1auto == d2auto && d1auto != 5) {
        _humanHomeDoubles++;
        setState(() {
          _dice1Value = d1auto; _dice2Value = d2auto;
          _totalDiceValue = d1auto + d2auto;
          _canRollDice = false; _hasUsedDice1 = false; _hasUsedDice2 = false;
        });
        if (_humanHomeDoubles >= 3) {
          _humanHomeDoubles = 0;
          _consecutiveDoubles = 0;
          _showEventToast(S.of(context).threeDoublesHome);
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
          _nextTurn();
          return;
        }
        _showEventToast(S.of(context).doubleHome);
        await Future.delayed(const Duration(milliseconds: 1000));
        setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
        continue;
      }
      _humanHomeDoubles = 0;
      break;
    } while (true);

    setState(() {
      _dice1Value = d1auto; _dice2Value = d2auto;
      _totalDiceValue = d1auto + d2auto;
      _canRollDice = false; _hasUsedDice1 = false; _hasUsedDice2 = false;
      _updateConsecutiveDoubles(d1auto, d2auto);
    });
    _calculateMovablePieces();
    if (_movablePieces.isNotEmpty) {
      _cancelMoveTimer();
      _autoMove();
    } else {
      _nextTurn();
    }
  }

  Future<void> _rollDice() async {
    if (!_canRollDice || _gameEnded || _currentPlayer != 'yellow' || _isRollingDice) return;
    _cancelAfkRollTimer();

    setState(() {
      _canRollDice = false;
      _movablePieces.clear();
      _selectedPieceColor = null;
      _selectedPieceId = null;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
    });

    final humanPieces = _gameState.getPiecesByColor(_currentPlayer);
    final allInHome = humanPieces.every((p) => p.isHome);
    int d1r = 0, d2r = 0;

    do {
      setState(() { _isRollingDice = true; });
      _diceAnimationController.repeat();
      await Future.delayed(const Duration(milliseconds: 600));
      _diceAnimationController.stop();
      _diceAnimationController.reset();

      d1r = _random.nextInt(6) + 1;
      d2r = _random.nextInt(6) + 1;
      final humanHasHome = humanPieces.any((p) => p.isHome);
      final humanMissed = _missedFive[_currentPlayer] ?? 0;
      if (humanMissed >= 3 && humanHasHome && d1r != 5 && d2r != 5) {
        if (_random.nextBool()) { d1r = 5; } else { d2r = 5; }
      }
      _missedFive[_currentPlayer] = (humanHasHome && d1r != 5 && d2r != 5) ? humanMissed + 1 : 0;

      if (allInHome && d1r == d2r && d1r != 5) {
        _humanHomeDoubles++;
        setState(() {
          _dice1Value = d1r; _dice2Value = d2r;
          _totalDiceValue = d1r + d2r; _isRollingDice = false;
        });
        if (_humanHomeDoubles >= 3) {
          _humanHomeDoubles = 0;
          _consecutiveDoubles = 0;
          _showEventToast(S.of(context).threeDoublesHome);
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
          _nextTurn();
          return;
        }
        _showEventToast(S.of(context).doubleHome);
        await Future.delayed(const Duration(milliseconds: 1200));
        setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
        continue;
      }
      _humanHomeDoubles = 0;
      break;
    } while (true);

    _bridgeBreakPieceIds = (d1r == d2r) ? _getBarreraIndices(_currentPlayer) : {};
    setState(() {
      _dice1Value = d1r; _dice2Value = d2r;
      _totalDiceValue = d1r + d2r;
      _isRollingDice = false;
      _updateConsecutiveDoubles(d1r, d2r);
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
      _showEventToast(S.of(context).noValidMoves);
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
      _turnOverlayText = isHuman ? S.of(context).yourTurn : '${_getColorName(color).toUpperCase()} (CPU)';
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

  void _startMoveTimer([int? initialSeconds]) {
    _moveTimer?.cancel();
    if (!mounted) return;
    setState(() => _moveTimerSeconds = initialSeconds ?? _moveTimeoutSeconds);
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

  void _startAfkRollTimer() {
    _afkRollTimer?.cancel();
    if (!mounted || _gameEnded || _currentPlayer != 'yellow') return;
    _afkRollTimer = Timer(const Duration(seconds: _afkRollTimeoutSeconds), () {
      if (mounted && !_gameEnded && _currentPlayer == 'yellow' && _canRollDice) {
        _autoRollAndMove();
      }
    });
  }

  void _cancelAfkRollTimer() {
    _afkRollTimer?.cancel();
    _afkRollTimer = null;
  }

  void _autoMove() {
    if (_movablePieces.isEmpty || _gameEnded) return;

    if (_bonusSelectionActive) {
      final best = _movablePieces.reduce((a, b) {
        final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition('yellow'));
        final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition('yellow'));
        return stA >= stB ? a : b;
      });
      setState(() { _bonusSelectionActive = false; _movablePieces.clear(); });
      _applyBonusTopiece('yellow', best['piece'] as LudoPiece, best['bonusPos'] as int, _bonusHadDouble);
      return;
    }

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

    final isDoubles = _dice1Value > 0 && _dice1Value == _dice2Value;

    if (isDoubles && !_hasUsedDice1 && !_hasUsedDice2) {
      final barrIndices = _getBarreraIndices(_currentPlayer);
      if (barrIndices.isNotEmpty) {
        final barrMoves = _movablePieces.where((m) => barrIndices.contains(m['pieceId'])).toList();
        if (barrMoves.isNotEmpty) _movablePieces = barrMoves;
      }
    }

    if (isDoubles && _hasUsedDice1 && !_hasUsedDice2 && _bridgeBreakPieceIds.isNotEmpty) {
      _movablePieces.removeWhere((m) {
        final pid = m['pieceId'] as int;
        if (!_bridgeBreakPieceIds.contains(pid)) return false;
        final piece = pieces[pid];
        final np = _calculateNewPosition(piece, _dice2Value, _currentPlayer);
        if (np == null) return false;
        for (int j = 0; j < pieces.length; j++) {
          if (j == pid) continue;
          if (!_bridgeBreakPieceIds.contains(j)) continue;
          final ally = pieces[j];
          if (!ally.isHome && !ally.isFinished && ally.position == np) return true;
        }
        return false;
      });
    }
  }

  Set<int> _getBarreraIndices(String color) {
    final pieces = _gameState.getPiecesByColor(color);
    final inBarrera = <int>{};
    for (int i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      if (p.isHome || p.isFinished) continue;
      for (int j = i + 1; j < pieces.length; j++) {
        final q = pieces[j];
        if (q.isHome || q.isFinished) continue;
        if (p.position == q.position) {
          inBarrera.add(i);
          inBarrera.add(j);
        }
      }
    }
    return inBarrera;
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
      if (newSteps > 51) break;
      final checkPos = (startPos + newSteps) % 52;
      if (_isAnyBarrierAt(checkPos)) return true;
    }

    return false;
  }

  bool _isAnyBarrierAt(int pos) {
    for (final c in _activePlayers) {
      final count = _gameState.getPiecesByColor(c)
          .where((p) => !p.isHome && !p.isFinished && p.position == pos)
          .length;
      if (count >= 2) return true;
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

    // Regla especial: salida de casa con barrera enemiga en tu casilla de salida → permitido (rompe barrera)
    if (movingPiece.isHome && newPos == _getStartPosition(color) && _isEnemyBarrierAt(newPos, color)) {
      return true;
    }
    if (_isEnemyBarrierAt(newPos, color)) return false;

    final sameColorCount = _gameState.getPiecesByColor(color)
        .where((p) => p != movingPiece && !p.isHome && !p.isFinished && p.position == newPos)
        .length;
    if (sameColorCount >= 2) return false;

    return true;
  }

  void _handleBoardTap(Offset localPosition) {
    if (_gameEnded || _currentPlayer != 'yellow' || _boardSize == 0) return;

    final squareSize = _boardSize / 15;
    final yellowPieces = _gameState.getPiecesByColor('yellow');
    final tapRadius = squareSize * 0.7;

    if (_bonusSelectionActive) {
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

    if (options.length == 1) {
      _executePieceMove('yellow', pieceId, options[0]['diceValue'] as int, options[0]['diceNumber'] as int);
      return;
    }

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

    if (newPosition < 52 && !_isSafeForColor(newPosition, color)) {
      final isBarrierBreak = piece.isHome && newPosition == _getStartPosition(color);
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyPiecesHere = _gameState.getPiecesByColor(enemyColor)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPosition)
            .toList();
        if (isBarrierBreak && enemyPiecesHere.length >= 2) {
          setState(() { enemyPiecesHere.last.position = -1; });
          captured = true;
        } else {
          for (final ep in enemyPiecesHere) {
            setState(() { ep.position = -1; });
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
    _lastMovedPieceId[color] = pieceId;

    if (_checkVictory(color)) {
      Future.delayed(const Duration(milliseconds: 500), () => _endGame(color));
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;

    if (captured) {
      setState(() {
        _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0;
        _movablePieces.clear();
        _hasUsedDice1 = false; _hasUsedDice2 = false;
      });
      _applyCaptureBonusWithSelection(color, piece, hadDouble);
      return;
    }

    _calculateMovablePieces();

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
      if (color == 'yellow') _startAfkRollTimer();
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

    // Si solo hay una ficha elegible, ejecutar bonus automáticamente
    if (bonusMoves.length == 1) {
      final m = bonusMoves.first;
      _showEventToast('🎯 ¡Comiste! +20 casillas');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _gameEnded) return;
        _applyBonusTopiece('yellow', m['piece'] as LudoPiece, m['bonusPos'] as int, hadDouble);
      });
      return;
    }
    setState(() {
      _movablePieces = bonusMoves;
      _bonusSelectionActive = true;
      _bonusHadDouble = hadDouble;
    });
    _showEventToast('🎯 ¡Comiste! Toca la ficha que quieres mover +20');
    _startMoveTimer();
  }

  void _resolveTurnAfterCapture(bool hadDouble) {
    if (hadDouble) {
      setState(() => _canRollDice = true);
      if (_currentPlayer == 'yellow') _startAfkRollTimer();
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
    } else {
      _startAfkRollTimer();
    }
  }

  Future<void> _playCpuTurn() async {
    if (_gameEnded || !_cpuPlayers.contains(_currentPlayer) || !_canRollDice) return;
    if (!mounted) return;

    final String cpuColor = _currentPlayer;

    await Future.delayed(const Duration(milliseconds: 800));
    if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;

    final cpuPieces = _gameState.getPiecesByColor(cpuColor);
    final cpuAllInHome = cpuPieces.every((p) => p.isHome);
    int d1cpu = 0, d2cpu = 0;

    do {
      d1cpu = _rollCpuDice();
      d2cpu = (_consecutiveDoubles >= 2) ? _rollCpuDiceNoDouble(d1cpu) : _rollCpuDice();
      final cpuHasHome = cpuPieces.any((p) => p.isHome);
      final cpuMissed = _missedFive[cpuColor] ?? 0;
      if (cpuMissed >= 3 && cpuHasHome && d1cpu != 5 && d2cpu != 5) {
        if (_random.nextBool()) { d1cpu = 5; } else { d2cpu = 5; }
      }
      _missedFive[cpuColor] = (cpuHasHome && d1cpu != 5 && d2cpu != 5) ? cpuMissed + 1 : 0;

      if (cpuAllInHome && d1cpu == d2cpu && d1cpu != 5) {
        _cpuHomeDoubles++;
        setState(() {
          _dice1Value = d1cpu; _dice2Value = d2cpu;
          _totalDiceValue = d1cpu + d2cpu;
          _canRollDice = false; _hasUsedDice1 = false; _hasUsedDice2 = false;
        });
        if (_cpuHomeDoubles >= 3) {
          _cpuHomeDoubles = 0;
          _consecutiveDoubles = 0;
          _showEventToast('CPU: tres dobles en casa, pierde turno.');
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
          if (!_gameEnded && mounted) _nextTurn();
          return;
        }
        _showEventToast('CPU: doble en casa, vuelve a tirar.');
        await Future.delayed(const Duration(milliseconds: 1000));
        setState(() { _dice1Value = 0; _dice2Value = 0; _totalDiceValue = 0; });
        await Future.delayed(const Duration(milliseconds: 500));
        if (_gameEnded || _currentPlayer != cpuColor || !mounted) return;
        continue;
      }
      _cpuHomeDoubles = 0;
      break;
    } while (true);

    _bridgeBreakPieceIds = (d1cpu == d2cpu) ? _getBarreraIndices(_currentPlayer) : {};
    setState(() {
      _dice1Value = d1cpu; _dice2Value = d2cpu;
      _totalDiceValue = d1cpu + d2cpu;
      _canRollDice = false; _hasUsedDice1 = false; _hasUsedDice2 = false;
      _updateConsecutiveDoubles(d1cpu, d2cpu);
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
      final isBarrierBreak = piece.isHome && newPosition == _getStartPosition(color);
      for (final enemyColor in _activePlayers) {
        if (enemyColor == color) continue;
        final enemyPiecesHere = _gameState.getPiecesByColor(enemyColor)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPosition)
            .toList();
        if (isBarrierBreak && enemyPiecesHere.length >= 2) {
          setState(() => enemyPiecesHere.last.position = -1);
          captured = true;
        } else {
          for (final ep in enemyPiecesHere) {
            setState(() => ep.position = -1);
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
    _lastMovedPieceId[color] = pieceId;

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
    int bestScore = -9999;

    for (final move in _movablePieces) {
      final piece = move['piece'] as LudoPiece;
      int score = 0;

      if (piece.isFinished) continue;

      if (piece.position >= 52) score += 1000;

      if (piece.isHome && move['diceValue'] == 5) score += 500;

      if (!piece.isHome && piece.position < 52) {
        final steps = _stepsFromStart(piece.position, _getStartPosition(_currentPlayer));
        score += steps * (_isUltra ? 15 : 10);
      }

      final diceValue = move['diceValue'] as int;
      final newPos = _calculateNewPosition(piece, diceValue, _currentPlayer);

      if (newPos != null) {
        if (newPos < 52 && !_isSafeForColor(newPos, _currentPlayer)) {
          for (final ec in _activePlayers) {
            if (ec == _currentPlayer) continue;
            for (final e in _gameState.getPiecesByColor(ec)) {
              if (!e.isHome && !e.isFinished && e.position == newPos) {
                final enemySteps = _stepsFromStart(e.position, _getStartPosition(ec));
                final isHuman = ec == 'yellow';
                score += (isHuman ? 10000 : 8000) + enemySteps * 20;
                break;
              }
            }
          }
        }

        if (_isUltra) {
          if (newPos < 52 && !_isSafeForColor(newPos, _currentPlayer)) {
            for (final ec in _activePlayers) {
              if (ec == _currentPlayer) continue;
              for (final e in _gameState.getPiecesByColor(ec)) {
                if (e.isHome || e.isFinished) continue;
                for (int d = 2; d <= 6; d++) {
                  final eReach = _calculateNewPosition(e, d, ec);
                  if (eReach == newPos) { score -= 400; break; }
                }
              }
            }
          }

          if (newPos < 52 && _isSafeForColor(newPos, _currentPlayer)) score += 200;

          if (newPos < 52) {
            final allies = _gameState.getPiecesByColor(_currentPlayer)
                .where((p) => p != piece && !p.isHome && !p.isFinished && p.position == newPos)
                .length;
            if (allies == 1) score += 450;
          }

          if (!piece.isHome && piece.position < 52) {
            int maxSteps = 0;
            for (final p in _gameState.getPiecesByColor(_currentPlayer)) {
              if (p.isHome || p.isFinished) continue;
              final s = _stepsFromStart(p.position, _getStartPosition(_currentPlayer));
              if (s > maxSteps) maxSteps = s;
            }
            final mySteps = _stepsFromStart(piece.position, _getStartPosition(_currentPlayer));
            if (mySteps == maxSteps) score += 150;
          }

          if (newPos < 52 && !_isSafeForColor(newPos, _currentPlayer)) {
            for (final e in _gameState.getPiecesByColor('yellow')) {
              if (e.isHome || e.isFinished) continue;
              for (int d = 1; d <= 6; d++) {
                final threat = (newPos + d) % 52;
                if (threat == e.position) { score += 180; break; }
              }
            }
          }

          if (!piece.isHome && piece.position < 52 && !_isSafeForColor(piece.position, _currentPlayer)) {
            for (final e in _gameState.getPiecesByColor('yellow')) {
              if (e.isHome || e.isFinished) continue;
              for (int d = 1; d <= 6; d++) {
                final reach = _calculateNewPosition(e, d, 'yellow');
                if (reach == piece.position) { score += 50; break; }
              }
            }
          }

          if (piece.isHome && move['diceValue'] == 5) {
            final startPos = _getStartPosition(_currentPlayer);
            for (final e in _gameState.getPiecesByColor('yellow')) {
              if (e.isHome || e.isFinished) continue;
              final dist = (_stepsFromStart(e.position, _getStartPosition('yellow')) -
                            _stepsFromStart(startPos, _getStartPosition('yellow'))).abs();
              if (dist <= 10) score += 120;
            }
          }
        }
      }

      if (score > bestScore) { bestScore = score; bestMove = move; }
    }

    return bestMove;
  }


  int? _calculateCaptureBonusPosition(LudoPiece piece, String color) {
    if (piece.isFinished || piece.isHome) return null;
    if (piece.position >= 52) return null;
    final startPos = _getStartPosition(color);
    final currentSteps = _stepsFromStart(piece.position, startPos);
    for (int bonus = 1; bonus <= 20; bonus++) {
      final ns = currentSteps + bonus;
      final int candidatePos;
      if (ns >= 51) {
        final into = ns - 51;
        if (into > 5) return null;
        candidatePos = 52 + into;
      } else {
        candidatePos = (startPos + ns) % 52;
      }
      if (candidatePos < 52 && _isAnyBarrierAt(candidatePos)) return null;
      if (candidatePos == 57 && bonus < 20) return null;
      if (bonus == 20) return candidatePos;
    }
    return null;
  }

  void _applyTripleDoublesPenalty(String color) {
    final pieces = _gameState.getPiecesByColor(color);
    final activePieces = pieces.where((p) => !p.isHome && !p.isFinished).toList();

    if (activePieces.isEmpty) return;

    final lastId = _lastMovedPieceId[color];
    LudoPiece? target;
    if (lastId != null && lastId < pieces.length) {
      final last = pieces[lastId];
      if (!last.isHome && !last.isFinished) {
        target = last;
      }
    }
    if (target == null) {
      int maxSteps = -1;
      for (final piece in activePieces) {
        final steps = piece.position >= 52
            ? 51 + (piece.position - 51)
            : _stepsFromStart(piece.position, _getStartPosition(color));
        if (steps > maxSteps) { maxSteps = steps; target = piece; }
      }
    }

    if (target != null) {
      setState(() => target!.position = -1);
      _showEventToast(S.of(context).tripleDouble, color: Colors.red.shade700);
    }
  }

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


  bool _isSafeForColor(int position, String color) {
    final startPositions = {
      'green': 0, 'red': 13, 'blue': 26, 'yellow': 39,
    };
    for (final entry in startPositions.entries) {
      if (position == entry.value) {
        return entry.key == color;
      }
    }
    return _isSafePosition(position);
  }

  bool _checkVictory(String color) {
    return _gameState.getPiecesByColor(color).every((p) => p.isFinished);
  }

  int _getGameCost() => widget.matchType == 'Apuesta' ? 25 : 100;

  Future<void> _loadAndDeductGameCost() async {
    if (_currentUser == null) return;
    try {
      final userData = await _firestoreService.getUser(_currentUser!.uid);
      if (userData == null || !mounted) return;

      final isBet = widget.matchType == 'Apuesta';
      final cost = _getGameCost();

      if (isBet) {
        if (userData.diamonds < cost) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Diamantes insuficientes (necesitas $cost 💎)'), backgroundColor: Colors.red),
            );
            Navigator.of(context).pop();
          }
          return;
        }
        final newDiamonds = userData.diamonds - cost;
        await _firestoreService.updateUserDiamonds(_currentUser!.uid, newDiamonds);
      } else {
        if (userData.coins < cost) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Monedas insuficientes (necesitas $cost 🪙)'), backgroundColor: Colors.red),
            );
            Navigator.of(context).pop();
          }
          return;
        }
        final newCoins = userData.coins - cost;
        await _firestoreService.updateUserCoins(_currentUser!.uid, newCoins);
      }
    } catch (e) {
      if (kDebugMode) print('Error deduciendo costo Ludo vs CPU: $e');
    }
  }

  void _endGame(String winnerColor) {
    if (_gameEnded) return;
    setState(() => _gameEnded = true);

    final result = winnerColor == 'yellow' ? GameResultModel.win : GameResultModel.loss;
    _recordGameResult(result);
    _showGameEndDialog(winnerColor == 'yellow', winnerColor);
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
    if (_gameStartTime == null || _currentUser == null) return;
    try {
      final isBet = widget.matchType == 'Apuesta';
      final gameCost = _getGameCost();
      final duration = DateTime.now().difference(_gameStartTime!).inMinutes;

      if (result == GameResultModel.win) {
        final currencyChange = (gameCost * 2 * 0.9).floor();
        final userData = await _firestoreService.getUser(_currentUser!.uid);
        if (userData != null && mounted) {
          if (isBet) {
            final newDiamondsEarned = userData.diamondsEarned + currencyChange;
            await _firestoreService.updateUserDiamondsEarned(_currentUser!.uid, newDiamondsEarned);
          } else {
            final newCoins = userData.coins + currencyChange;
            await _firestoreService.updateUserCoins(_currentUser!.uid, newCoins);
          }
        }
      }

      await _firestoreService.recordGameMatch(
        userId: _currentUser!.uid,
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
          'gameCost': gameCost,
          'currencyType': isBet ? 'diamonds' : 'coins',
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error recording Ludo vs CPU result: $e');
    }
  }

  void _showGameEndDialog(bool isWin, String winnerColor) {
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
                isWin ? S.of(context).victory : S.of(context).endOfGame,
                style: TextStyle(
                  color: isWin ? Colors.amber.shade700 : const Color(0xFFEC7A34),
                  fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isWin ? S.of(context).youWon : '${_getColorName(winnerColor)} ${S.of(context).endOfGame}',
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                textAlign: TextAlign.center,
              ),
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
                      child: Text(S.of(context).exit),
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
                          _missedFive.clear();
                          _humanHomeDoubles = 0;
                          _cpuHomeDoubles = 0;
                          _setupActivePlayers();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: Text(S.of(context).playAgain, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showBetExitWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(S.of(ctx).abandonGame),
          ],
        ),
        content: Text(S.of(ctx).abandonWarningBet),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.of(ctx).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _endGame(_cpuPlayers.first);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) Navigator.of(context).pop();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(ctx).abandonGame),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBetMode = widget.matchType == 'Apuesta';
    return PopScope(
      canPop: !isBetMode || _gameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isBetMode && !_gameEnded) _showBetExitWarning();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isBetMode
              ? '${S.of(context).parchisVsFriend} — ${S.of(context).betMode}'
              : 'Parchís vs ${widget.cpuCount} CPU${widget.cpuCount > 1 ? "s" : ""} - ${widget.difficulty}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
                      isPlayer ? 'Yo' : 'CPU',
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.casino_rounded, color: Colors.white, size: 28),
                            const SizedBox(height: 4),
                            Text(S.of(context).rollDice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
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
                    if (_moveTimerSeconds > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _moveTimerSeconds <= 5 ? Colors.red : (_bonusSelectionActive ? Colors.green.shade700 : Colors.blue.shade700),
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