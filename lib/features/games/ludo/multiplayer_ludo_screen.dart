import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/ludo_game_match.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/ludo_game_service.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../adds/banner_ad_widget.dart';
import 'ludo_board_painter.dart';

class MultiplayerLudoScreen extends StatefulWidget {
  final String gameId;
  final int playerNumber;
  final String matchType;

  const MultiplayerLudoScreen({
    super.key,
    required this.gameId,
    required this.playerNumber,
    required this.matchType,
  });

  @override
  State<MultiplayerLudoScreen> createState() => _MultiplayerLudoScreenState();
}

class _MultiplayerLudoScreenState extends State<MultiplayerLudoScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final LudoGameService _gameService = LudoGameService();
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  int? _userDiamonds;
  int? _userCoins;
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;

  LudoGameMatch? _currentGame;
  StreamSubscription<LudoGameMatch?>? _gameSubscription;
  LudoGameState _gameState = LudoGameState.initial();
  String _myColor = 'yellow';
  String _currentTurn = 'player1';
  bool get _isMyTurn => _currentTurn == 'player${widget.playerNumber}';

  int _dice1Value = 0;
  int _dice2Value = 0;
  bool _hasUsedDice1 = false;
  bool _hasUsedDice2 = false;
  bool _isRollingDice = false;
  int _consecutiveDoubles = 0;
  int? _lastMovedPieceId;
  final Random _random = Random();


  List<Map<String, dynamic>> _movablePieces = [];
  int? _selectedPieceId;
  final List<int> _validMovePositions = [];
  bool _bonusSelectionActive = false;
  bool _bonusHadDouble = false;
  final List<Map<String, dynamic>> _pendingBonusMoves = [];

  double _boardSize = 0;
  List<String> _activePlayers = ['yellow', 'red', 'green', 'blue'];

  bool _gameEnded = false;
  bool _hasUserExited = false;
  DateTime? _gameStartTime;
  bool _isScreenKeepOnActive = false;

  String _toastMessage = '';
  bool _showToast = false;
  String _turnBannerText = '';
  bool _showTurnBanner = false;
  Color _turnBannerColor = Colors.orange;

  late AnimationController _pulseController;
  late AnimationController _diceAnimController;
  late Animation<double> _diceRotation;
  late AnimationController _toastController;
  late Animation<double> _toastAnim;
  late AnimationController _bannerController;
  late Animation<double> _bannerAnim;

  Timer? _turnTimer;
  int _turnTimerSeconds = 0;
  static const int _turnTimeoutSeconds = 30;


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
    _gameStartTime = DateTime.now();
    _enableWakeLock();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900), vsync: this,
    )..repeat(reverse: true);

    _diceAnimController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _diceRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _diceAnimController, curve: Curves.easeInOut),
    );

    _toastController = AnimationController(
      duration: const Duration(milliseconds: 300), vsync: this,
    );
    _toastAnim = CurvedAnimation(parent: _toastController, curve: Curves.easeOut);

    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 400), vsync: this,
    );
    _bannerAnim = CurvedAnimation(parent: _bannerController, curve: Curves.easeOut);

    _initializeGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _turnTimer?.cancel();
    _pulseController.dispose();
    _diceAnimController.dispose();
    _toastController.dispose();
    _bannerController.dispose();
    _disableWakeLock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isScreenKeepOnActive) {
      _enableWakeLock();
    } else if (state == AppLifecycleState.paused) {
      _disableWakeLock();
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted) setState(() => _isScreenKeepOnActive = true);
      }
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) setState(() => _isScreenKeepOnActive = false);
      }
    } catch (_) {}
  }

  void _initializeGame() {
    _gameSubscription = _gameService
        .getGameStream(widget.gameId)
        .listen(_handleGameUpdate, onError: (e) {
      if (kDebugMode) print('Ludo stream error: $e');
    });
    _setupBalanceListener();
  }

  void _setupBalanceListener() {
    if (_currentUser == null) return;
    _balanceSubscription?.cancel();
    _balanceSubscription = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userDiamonds = data['diamonds'] ?? 0;
          _userCoins = data['coins'] ?? 0;
        });
      }
    });
  }

  void _handleGameUpdate(LudoGameMatch? game) {
    if (game == null || !mounted) return;

    final prevGame = _currentGame;
    _currentGame = game;

    if (prevGame == null) {
      _setupPlayerColor(game);
      _setupActivePlayers(game);
    }

    final prevTurn = _currentTurn;
    final newTurn = game.currentTurn;
    final turnChangedToMe = newTurn != prevTurn && newTurn == 'player${widget.playerNumber}';
    final isMyTurnNow = newTurn == 'player${widget.playerNumber}';

    setState(() {
      _gameState = game.gameState;
      _currentTurn = newTurn;
      if (!isMyTurnNow || turnChangedToMe) {
        _dice1Value = game.dice1;
        _dice2Value = game.dice2;
        _hasUsedDice1 = game.hasUsedDice1;
        _hasUsedDice2 = game.hasUsedDice2;
      }
    });

    if (isMyTurnNow) _calculateMovablePieces();

    if (prevTurn != _currentTurn && _isMyTurn && !_gameEnded) {
      _showTurnBannerAnim('¡TU TURNO!', _getPlayerColor(_myColor));
      _startTurnTimer();
    }

    if (!_gameEnded && game.isFinished) {
      _gameEnded = true;
      _turnTimer?.cancel();
      _handleGameEnd(game);
    }
    if (!_gameEnded && game.isAbandoned) {
      _gameEnded = true;
      _turnTimer?.cancel();
      _handleAbandon(game);
    }

    if (prevGame != null && !prevGame.rewardsDistributed && game.rewardsDistributed) {
      if (kDebugMode) print('💰 [Ludo] Recompensas distribuidas por Cloud Function');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _reloadUserCurrency();
      });
    }
  }

  void _setupPlayerColor(LudoGameMatch game) {
    switch (widget.playerNumber) {
      case 1: _myColor = game.player1Color; break;
      case 2: _myColor = game.player2Color ?? 'red'; break;
      case 3: _myColor = game.player3Color ?? 'blue'; break;
      case 4: _myColor = game.player4Color ?? 'green'; break;
    }
  }

  void _setupActivePlayers(LudoGameMatch game) {
    _activePlayers = [game.player1Color];
    if (game.player2Color != null) _activePlayers.add(game.player2Color!);
    if (game.player3Color != null) _activePlayers.add(game.player3Color!);
    if (game.player4Color != null) _activePlayers.add(game.player4Color!);
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() => _turnTimerSeconds = _turnTimeoutSeconds);
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameEnded || !_isMyTurn) { t.cancel(); return; }
      setState(() => _turnTimerSeconds--);
      if (_turnTimerSeconds <= 0) {
        t.cancel();
        _autoAction();
      }
    });
  }

  Future<void> _autoAction() async {
    if (!mounted || _gameEnded || !_isMyTurn) return;

    if (_bonusSelectionActive && _pendingBonusMoves.isNotEmpty) {
      final m = _pendingBonusMoves.first;
      _executeBonusMove(m['pieceId'] as int, m['bonusPos'] as int);
      return;
    }

    if (_dice1Value == 0 && _dice2Value == 0) {
      await _rollDice();
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted || _gameEnded || !_isMyTurn) return;
      if (_movablePieces.isNotEmpty) {
        final m = _movablePieces.first;
        _executePieceMove(_myColor, m['pieceId'] as int, m['diceValue'] as int, m['diceNumber'] as int);
      }
    } else if (_movablePieces.isNotEmpty) {
      final m = _movablePieces.first;
      _executePieceMove(_myColor, m['pieceId'] as int, m['diceValue'] as int, m['diceNumber'] as int);
    } else {
      _advanceTurn();
    }
  }

  Future<void> _rollDice() async {
    if (!_isMyTurn || _gameEnded || _isRollingDice || _bonusSelectionActive) return;
    if (_dice1Value != 0 || _dice2Value != 0) return;

    setState(() { _isRollingDice = true; });
    _diceAnimController.repeat();
    await Future.delayed(const Duration(milliseconds: 600));
    _diceAnimController.stop();
    _diceAnimController.reset();

    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;

    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    if (_consecutiveDoubles >= 3) {
      setState(() {
        _isRollingDice = false;
        _consecutiveDoubles = 0;
      });
      _showEventToast('¡Tres dobles! Turno perdido.');
      await _applyTripleDoublesPenalty();
      return;
    }

    setState(() {
      _dice1Value = d1;
      _dice2Value = d2;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _isRollingDice = false;
    });

    await _syncDiceToFirestore(d1, d2, false, false);

    _calculateMovablePieces();
    if (_movablePieces.isEmpty) {
      _showEventToast('Sin movimientos válidos. Turno perdido.');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_gameEnded && mounted) await _advanceTurn();
    } else {
      _startTurnTimer();
    }
  }

  Future<void> _syncDiceToFirestore(int d1, int d2, bool u1, bool u2) async {
    try {
      await _firestore.collection('ludo_games').doc(widget.gameId).update({
        'dice1': d1,
        'dice2': d2,
        'hasUsedDice1': u1,
        'hasUsedDice2': u2,
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Error syncing dice: $e');
    }
  }

  Future<void> _applyTripleDoublesPenalty() async {
    final pieces = _gameState.getPiecesByColor(_myColor);
    final active = pieces.where((p) => !p.isHome && !p.isFinished).toList();
    if (active.isEmpty) {
      await _syncGameState(advanceTurn: true);
      return;
    }

    // Enviar a casa la última ficha movida; si ya no está activa, la más avanzada
    LudoPiece? target;
    if (_lastMovedPieceId != null && _lastMovedPieceId! < pieces.length) {
      final last = pieces[_lastMovedPieceId!];
      if (!last.isHome && !last.isFinished) {
        target = last;
      }
    }
    if (target == null) {
      final sp = _getStartPosition(_myColor);
      int maxSteps = -1;
      for (final p in active) {
        final steps = p.position >= 52
            ? 51 + (p.position - 51)
            : _stepsFromStart(p.position, sp);
        if (steps > maxSteps) { maxSteps = steps; target = p; }
      }
    }

    if (target != null) {
      target.position = -1;
      _showEventToast('¡Triple doble! Ficha enviada a casa 😱', color: Colors.red.shade700);
    }
    await _syncGameState(advanceTurn: true);
  }

  void _calculateMovablePieces([String? forColor]) {
    final color = forColor ?? _myColor;
    _movablePieces.clear();
    final pieces = _gameState.getPiecesByColor(color);

    for (int i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.isFinished) continue;

      if (piece.isHome) {
        if (!_hasUsedDice1 && _dice1Value == 5) {
          final sp = _getStartPosition(color);
          if (_canLandOn(color, sp, piece)) {
            _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 1, 'piece': piece});
          }
        }
        if (!_hasUsedDice2 && _dice2Value == 5 && (_dice1Value != _dice2Value || _hasUsedDice1)) {
          final sp = _getStartPosition(color);
          if (_canLandOn(color, sp, piece)) {
            _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 2, 'piece': piece});
          }
        }
      } else {
        if (!_hasUsedDice1 && _canMovePieceWithValue(piece, _dice1Value, color)) {
          _movablePieces.add({'pieceId': i, 'diceValue': _dice1Value, 'diceNumber': 1, 'piece': piece});
        }
        if (!_hasUsedDice2 && (_dice1Value != _dice2Value || _hasUsedDice1) &&
            _canMovePieceWithValue(piece, _dice2Value, color)) {
          _movablePieces.add({'pieceId': i, 'diceValue': _dice2Value, 'diceNumber': 2, 'piece': piece});
        }
      }
    }

    if (_dice1Value > 0 && _dice1Value == _dice2Value && !_hasUsedDice1 && !_hasUsedDice2) {
      final barrIndices = _getBarreraIndices(color);
      if (barrIndices.isNotEmpty) {
        final barrMoves = _movablePieces.where((m) => barrIndices.contains(m['pieceId'])).toList();
        if (barrMoves.isNotEmpty) _movablePieces = barrMoves;
      }
    }

    if (mounted) setState(() {});
  }

  bool _canMovePieceWithValue(LudoPiece piece, int diceValue, [String? color]) {
    final c = color ?? _myColor;
    if (piece.isFinished) return false;
    if (piece.isHome) return diceValue == 5;
    final np = _calculateNewPosition(piece, diceValue, c);
    if (np == null) return false;
    if (_hasBarrierInPath(piece, diceValue, c)) return false;
    return _canLandOn(c, np, piece);
  }

  void _handleBoardTap(Offset local) {
    if (!_isMyTurn || _gameEnded || _boardSize == 0) return;
    if (_dice1Value == 0 && _dice2Value == 0 && !_bonusSelectionActive) return;

    final sq = _boardSize / 15;
    final tapR = sq * 0.7;
    final pieces = _gameState.getPiecesByColor(_myColor);

    if (_bonusSelectionActive) {
      final bonusTapR = sq * 1.8;
      int? closestId;
      Map<String, dynamic>? closestBm;
      double closestDist = double.infinity;

      for (int i = 0; i < pieces.length; i++) {
        final bm = _pendingBonusMoves.firstWhere(
          (m) => m['pieceId'] == i, orElse: () => {},
        );
        if (bm.isEmpty) continue;
        final pos = _getPieceScreenPosition(pieces[i], _myColor, sq);
        if (pos == null) continue;
        final dist = (local - pos).distance;
        if (dist < bonusTapR && dist < closestDist) {
          closestDist = dist;
          closestId = i;
          closestBm = bm;
        }
      }

      if (closestId != null && closestBm != null) {
        _executeBonusMove(closestId, closestBm['bonusPos'] as int);
      }
      return;
    }

    if (_movablePieces.isEmpty) return;
    for (int i = 0; i < pieces.length; i++) {
      if (!_movablePieces.any((m) => m['pieceId'] == i)) continue;
      final pos = _getPieceScreenPosition(pieces[i], _myColor, sq);
      if (pos != null && (local - pos).distance < tapR) {
        _showMoveSelectionDialog(i);
        return;
      }
    }
  }

  void _showMoveSelectionDialog(int pieceId) {
    final options = _movablePieces.where((m) => m['pieceId'] == pieceId).toList();
    if (options.isEmpty) return;
    if (options.length == 1) {
      _executePieceMove(_myColor, pieceId, options[0]['diceValue'] as int, options[0]['diceNumber'] as int);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Qué dado usar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final dv = opt['diceValue'] as int;
                final dn = opt['diceNumber'] as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _executePieceMove(_myColor, pieceId, dv, dn);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC7A34),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Dado $dn: $dv casillas',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _executePieceMove(String color, int pieceId, int diceValue, int diceNumber) {
    if (color != _myColor || _gameEnded) return;
    _turnTimer?.cancel();

    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return;
    final piece = pieces[pieceId];
    final newPos = _calculateNewPosition(piece, diceValue, color);
    if (newPos == null || !_canLandOn(color, newPos, piece)) return;

    bool captured = false;
    if (newPos < 52 && !_isSafeForColor(newPos, color)) {
      for (final ec in _activePlayers) {
        if (ec == color) continue;
        for (final ep in _gameState.getPiecesByColor(ec)) {
          if (!ep.isHome && !ep.isFinished && ep.position == newPos) {
            ep.position = -1;
            captured = true;
          }
        }
      }
    }

    piece.position = newPos;
    if (newPos == 57) piece.isFinished = true;
    _lastMovedPieceId = pieceId;

    if (diceNumber == 1) {
      _hasUsedDice1 = true;
    } else {
      _hasUsedDice2 = true;
    }

    if (_checkVictory(color)) {
      _syncGameState(advanceTurn: false).then((_) {
        if (mounted) _endGame(color);
      });
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;

    if (captured) {
      _dice1Value = 0; _dice2Value = 0;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _movablePieces.clear();
      _prepareCaptureBonus(color, piece, hadDouble);
      _syncGameState(advanceTurn: false);
      return;
    }

    setState(() {});
    _calculateMovablePieces();

    if (_movablePieces.isNotEmpty) {
      _syncGameState(advanceTurn: false);
      _startTurnTimer();
      return;
    }

    _dice1Value = 0; _dice2Value = 0;
    _hasUsedDice1 = false; _hasUsedDice2 = false;
    _movablePieces.clear();

    if (hadDouble) {
      _syncGameState(advanceTurn: false);
      _startTurnTimer();
    } else {
      _syncGameState(advanceTurn: true);
    }
  }

  void _prepareCaptureBonus(String color, LudoPiece capturer, bool hadDouble) {
    final allPieces = _gameState.getPiecesByColor(color);
    _pendingBonusMoves.clear();

    for (int i = 0; i < allPieces.length; i++) {
      final p = allPieces[i];
      if (p.isFinished || p.isHome) continue;
      final bp = _calculateCaptureBonusPosition(p, color);
      if (bp == null) continue;
      if (bp < 52 && _isEnemyBarrierAt(bp, color)) continue;
      _pendingBonusMoves.add({'pieceId': i, 'piece': p, 'bonusPos': bp});
    }

    if (_pendingBonusMoves.isEmpty) {
      if (hadDouble) {
        _syncGameState(advanceTurn: false);
      } else {
        _syncGameState(advanceTurn: true);
      }
      return;
    }

    _bonusSelectionActive = true;
    _bonusHadDouble = hadDouble;
    _showEventToast('¡Capturaste! Elige una ficha para el bonus +20', color: Colors.green);

    _movablePieces = _pendingBonusMoves.map((m) => {
      ...m, 'diceValue': 20, 'diceNumber': 0,
    }).toList();
    setState(() {});
  }

  void _executeBonusMove(int pieceId, int bonusPos) {
    _bonusSelectionActive = false;
    final pieces = _gameState.getPiecesByColor(_myColor);
    if (pieceId >= pieces.length) return;
    final piece = pieces[pieceId];
    piece.position = bonusPos;
    if (bonusPos == 57) piece.isFinished = true;

    _pendingBonusMoves.clear();
    _movablePieces.clear();

    if (_checkVictory(_myColor)) {
      _syncGameState(advanceTurn: false).then((_) => _endGame(_myColor));
      return;
    }

    if (_bonusHadDouble) {
      _syncGameState(advanceTurn: false);
    } else {
      _syncGameState(advanceTurn: true);
    }
  }

  Future<void> _advanceTurn() async {
    await _syncGameState(advanceTurn: true);
  }

  Future<void> _syncGameState({required bool advanceTurn}) async {
    if (!mounted) return;
    try {
      final updates = <String, dynamic>{
        'gameState': _gameState.toMap(),
        'dice1': _dice1Value,
        'dice2': _dice2Value,
        'hasUsedDice1': _hasUsedDice1,
        'hasUsedDice2': _hasUsedDice2,
        'lastActivity': FieldValue.serverTimestamp(),
      };

      if (advanceTurn) {
        updates['currentTurn'] = _getNextTurn();
        updates['dice1'] = 0;
        updates['dice2'] = 0;
        updates['hasUsedDice1'] = false;
        updates['hasUsedDice2'] = false;
      }

      await _firestore.collection('ludo_games').doc(widget.gameId).update(updates);
    } catch (e) {
      if (kDebugMode) print('Error syncing game state: $e');
    }
  }

  String _getNextTurn() {
    if (_currentGame == null) return 'player1';
    final cur = int.parse(_currentTurn.replaceAll('player', ''));
    for (int next = cur + 1; next <= 4; next++) {
      if (_currentGame!.getPlayerIdByNumber(next) != null) {
        return 'player$next';
      }
    }
    return 'player1';
  }

  int? _calculateNewPosition(LudoPiece piece, int diceValue, String color) {
    if (piece.isHome) return _getStartPosition(color);
    if (piece.position >= 52) {
      final np = piece.position + diceValue;
      return np > 57 ? null : np;
    }
    final sp = _getStartPosition(color);
    final steps = _stepsFromStart(piece.position, sp);
    final ns = steps + diceValue;
    if (ns >= 51) {
      final into = ns - 51;
      return into > 5 ? null : 52 + into;
    }
    return (sp + ns) % 52;
  }

  int _stepsFromStart(int pos, int start) {
    if (pos >= start) return pos - start;
    return (52 - start) + pos;
  }

  bool _hasBarrierInPath(LudoPiece piece, int diceValue, String color) {
    if (piece.isHome || piece.position >= 52) return false;
    final sp = _getStartPosition(color);
    for (int step = 1; step < diceValue; step++) {
      final ns = _stepsFromStart(piece.position, sp) + step;
      if (ns >= 51) break;
      if (_isEnemyBarrierAt((sp + ns) % 52, color)) return true;
    }
    return false;
  }

  bool _isEnemyBarrierAt(int pos, String movingColor) {
    for (final ec in _activePlayers) {
      if (ec == movingColor) continue;
      final count = _gameState.getPiecesByColor(ec)
          .where((p) => !p.isHome && !p.isFinished && p.position == pos)
          .length;
      if (count >= 2) return true;
    }
    return false;
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

  bool _canLandOn(String color, int newPos, LudoPiece moving) {
    if (newPos >= 52) return true;
    final myPieces = _gameState.getPiecesByColor(color);
    final myCount = myPieces
        .where((p) => p != moving && !p.isHome && !p.isFinished && p.position == newPos)
        .length;
    if (myCount >= 2) return false;
    if (_isEnemyBarrierAt(newPos, color)) return false;
    for (final oc in _activePlayers) {
      if (oc == color) continue;
      final ownerStart = _getStartPosition(oc);
      if (newPos == ownerStart) {
        final ownerCount = _gameState.getPiecesByColor(oc)
            .where((p) => !p.isHome && !p.isFinished && p.position == ownerStart)
            .length;
        if (ownerCount > 0) return false;
      }
    }
    return true;
  }

  int? _calculateCaptureBonusPosition(LudoPiece piece, String color) {
    if (piece.isFinished || piece.isHome) return null;
    if (piece.position >= 52) {
      final np = piece.position + 20;
      return np > 57 ? 57 : np;
    }
    final sp = _getStartPosition(color);
    final steps = _stepsFromStart(piece.position, sp) + 20;
    if (steps >= 51) {
      final into = steps - 51;
      return into > 5 ? 57 : 52 + into;
    }
    return (sp + steps) % 52;
  }

  bool _checkVictory(String color) =>
      _gameState.getPiecesByColor(color).every((p) => p.isFinished);

  int _getStartPosition(String color) {
    switch (color) {
      case 'green':  return 0;
      case 'red':    return 13;
      case 'blue':   return 26;
      case 'yellow': return 39;
      default:       return 0;
    }
  }

  bool _isSafeForColor(int pos, String color) {
    return const {4, 8, 17, 21, 30, 34, 43, 47}.contains(pos);
  }

  Offset? _getPieceScreenPosition(LudoPiece piece, String color, double sq) {
    if (piece.isHome) return _getHomeScreenPos(color, piece.id, sq);
    if (piece.isFinished) return null;
    if (piece.position >= 52 && piece.position <= 56) {
      return _getHomeStretchPos(color, piece.position, sq);
    }
    return _getBoardPos(piece, color, sq);
  }

  Offset _getHomeStretchPos(String color, int pos, double sq) {
    final si = pos - 52;
    switch (color) {
      case 'green':  return Offset(7.5 * sq, (1.0 + si) * sq);
      case 'red':    return Offset((1.0 + si) * sq, 7.5 * sq);
      case 'blue':   return Offset(7.5 * sq, (13.0 - si) * sq);
      case 'yellow': return Offset((13.0 - si) * sq, 7.5 * sq);
      default:       return Offset(7.5 * sq, 7.5 * sq);
    }
  }

  Offset? _getBoardPos(LudoPiece piece, String color, double sq) {
    if (piece.position < 0 || piece.position >= _boardPath.length) return null;
    final c = _boardPath[piece.position];
    final base = Offset((c.col + 0.5) * sq, (c.row + 0.5) * sq);
    final samePos = _gameState.getPiecesByColor(color)
        .where((p) => !p.isHome && !p.isFinished && p.position == piece.position)
        .toList();
    if (samePos.length <= 1) return base;
    final idx = samePos.indexOf(piece);
    final off = sq * 0.28;
    return idx == 0 ? base - Offset(off, 0) : base + Offset(off, 0);
  }

  Offset _getHomeScreenPos(String color, int id, double sq) {
    const homes = {
      'green':  _Coord(3, 3), 'yellow': _Coord(12, 3),
      'red':    _Coord(3, 12), 'blue':  _Coord(12, 12),
    };
    final base = homes[color]!;
    const off = 0.8;
    final positions = [
      Offset((base.col - off) * sq, (base.row - off) * sq),
      Offset((base.col + off) * sq, (base.row - off) * sq),
      Offset((base.col - off) * sq, (base.row + off) * sq),
      Offset((base.col + off) * sq, (base.row + off) * sq),
    ];
    return positions[id];
  }

  void _endGame(String winnerColor) {
    if (_gameEnded) return;
    setState(() => _gameEnded = true);
    _turnTimer?.cancel();

    final winnerId = _currentUser?.uid;
    if (winnerId != null) {
      // Usar el servicio en lugar de escribir Firestore directamente
      // (equivalente a MultiplayerGameService.finishGame en chess)
      _gameService.finishGame(gameId: widget.gameId, winnerId: winnerId);
    }

    final isWin = winnerColor == _myColor;
    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    _showEndDialog(isWin ? '¡GANASTE! 🏆' : '${_getColorName(winnerColor)} ganó', _currentGame);
  }

  void _handleGameEnd(LudoGameMatch game) {
    final isWin = game.winnerId == _currentUser?.uid;
    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    _showEndDialog(isWin ? '¡GANASTE! 🏆' : 'Otro jugador ganó', game);
  }

  void _handleAbandon(LudoGameMatch game) {
    final data = game.toFirestore();
    final abandonedBy = data['abandonedBy'] as String?;
    if (abandonedBy != null && abandonedBy != _currentUser?.uid) {
      _recordResult(GameResultModel.win);
      _showEndDialog('Un jugador abandonó. ¡Ganaste! 🎉', game);
    } else {
      if (!_hasUserExited) {
        _recordResult(GameResultModel.loss);
      }
      _showEndDialog('Partida abandonada.', game);
    }
  }

  Future<void> _reloadUserCurrency() async {
    // El listener _balanceSubscription actualiza automáticamente _userDiamonds/_userCoins
    // cuando la Cloud Function modifica el balance en Firestore. No se necesita polling.
    if (kDebugMode) print('💰 [Ludo] Balance actualizado por listener en tiempo real');
  }

  Future<void> _recordResult(GameResultModel result) async {
    if (_gameStartTime == null || _currentUser == null) return;
    try {
      final dur = DateTime.now().difference(_gameStartTime!).inMinutes;
      await _firestoreService.recordGameMatch(
        userId: _currentUser!.uid,
        gameType: GameTypeModel.ludo,
        result: result,
        pointsEarned: result == GameResultModel.win ? 25 : -10,
        durationMinutes: dur > 0 ? dur : 1,
        opponentName: 'Jugador en línea',
        additionalData: {'matchType': widget.matchType, 'playerColor': _myColor},
      );
    } catch (_) {}
  }

  void _showEndDialog(String message, LudoGameMatch? game) {
    if (!mounted) return;
    final isWin = message.contains('GANASTE') || message.contains('Ganaste');
    final betAmount = game?.betAmount;
    final isBetGame = betAmount != null && betAmount > 0 && game?.currencyType == 'diamonds';
    // Ganador recibe 90% del pot total (apuesta × 2). Casa cobra el 10%.
    final winnerPrize = isBetGame ? ((betAmount * 2) * 0.90).floor() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isWin ? Colors.amber : const Color(0xFFEC7A34), width: 2,
            ),
            boxShadow: [BoxShadow(
              color: (isWin ? Colors.amber : const Color(0xFFEC7A34)).withValues(alpha: 0.25),
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
              Text(message,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  textAlign: TextAlign.center),
              if (isBetGame) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isWin ? Colors.blue.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWin ? Colors.blue.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond,
                          color: isWin ? Colors.blue : Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isWin
                            ? '+$winnerPrize 💎 ganados'
                            : '-$betAmount 💎 perdidos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isWin ? Colors.blue.shade800 : Colors.red.shade800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC7A34),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showAbandonConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('¿Abandonar partida?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.warning_amber_rounded,
                    size: 48, color: Colors.orange),
                SizedBox(height: 12),
                Text(
                  '¿Estás seguro de que quieres abandonar la partida?\n\n'
                  'Si abandonas, se contará como una derrota y perderás puntos.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text('¿Confirmas que deseas salir?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Continuar partida'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text('Abandonar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _abandonGame() async {
    if (_gameEnded || _hasUserExited) return;
    _hasUserExited = true;
    _gameEnded = true;
    _turnTimer?.cancel();
    final success = await _gameService.abandonGame(
      gameId: widget.gameId,
      playerId: _currentUser?.uid ?? '',
    );
    if (success) {
      await _recordResult(GameResultModel.loss);
    } else {
      _hasUserExited = false;
      _gameEnded = false;
    }
    if (mounted) Navigator.of(context).pop();
  }


  void _showEventToast(String msg, {Color color = Colors.orange}) {
    if (!mounted) return;
    setState(() { _toastMessage = msg; _showToast = true; });
    _toastController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _toastController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  void _showTurnBannerAnim(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _turnBannerText = text;
      _turnBannerColor = color;
      _showTurnBanner = true;
    });
    _bannerController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _bannerController.reverse().then((_) {
          if (mounted) setState(() => _showTurnBanner = false);
        });
      }
    });
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

  String _getColorName(String color) {
    switch (color) {
      case 'yellow': return 'Amarillo';
      case 'green':  return 'Verde';
      case 'red':    return 'Rojo';
      case 'blue':   return 'Azul';
      default:       return color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _gameEnded,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !_gameEnded) {
          final confirm = await _showAbandonConfirmDialog();
          if (confirm) _abandonGame();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFEC7A34),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Parchís Online',
              style: TextStyle(color: Colors.white)),
          actions: [
            if (!_gameEnded)
              IconButton(
                icon: const Icon(Icons.flag, color: Colors.white),
                onPressed: () async {
                  final confirm = await _showAbandonConfirmDialog();
                  if (confirm) _abandonGame();
                },
              ),
          ],
          elevation: 2,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final sz = constraints.maxWidth - 16;
                    _boardSize = sz;
                    return SizedBox(
                      height: sz + 16,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTapUp: (d) => _handleBoardTap(d.localPosition),
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_pulseController, _diceRotation]),
                            builder: (ctx, _) {
                              final movableKeys = <String>{};
                              if (_isMyTurn) {
                                for (final m in _movablePieces) {
                                  movableKeys.add('$_myColor-${m['pieceId']}');
                                }
                              }
                              final currentColor = _currentGame != null
                                  ? _colorForCurrentTurn()
                                  : _myColor;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: sz, height: sz,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getPlayerColor(currentColor).withValues(alpha: 0.35),
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
                                          highlightedPieceColor: _isMyTurn ? _myColor : null,
                                          highlightedPieceId: _selectedPieceId,
                                          validMovePositions: _validMovePositions,
                                          pulseValue: _pulseController.value,
                                          movableKeys: movableKeys,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildBoardPlayerLabels(sz),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                _buildChatWidget(),
                _buildControls(),
                const BannerAdWidget(),
              ],
            ),
            if (_showTurnBanner)
              Positioned(
                top: 90, left: 0, right: 0,
                child: AnimatedBuilder(
                  animation: _bannerAnim,
                  builder: (ctx, _) => Opacity(
                    opacity: _bannerAnim.value,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _turnBannerColor.withValues(alpha: 0.95),
                            _turnBannerColor.withValues(alpha: 0.75),
                          ]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: _turnBannerColor.withValues(alpha: 0.5), blurRadius: 20)],
                        ),
                        child: Text(
                          _turnBannerText,
                          style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900,
                            fontSize: 22, letterSpacing: 2,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showToast)
              Positioned(
                bottom: 120, left: 20, right: 20,
                child: AnimatedBuilder(
                  animation: _toastAnim,
                  builder: (ctx, _) => Opacity(
                    opacity: _toastAnim.value,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _toastMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _colorForCurrentTurn() {
    if (_currentGame == null) return _myColor;
    final playerNum = int.tryParse(_currentTurn.replaceAll('player', '')) ?? 1;
    switch (playerNum) {
      case 1: return _currentGame!.player1Color;
      case 2: return _currentGame!.player2Color ?? 'red';
      case 3: return _currentGame!.player3Color ?? 'blue';
      case 4: return _currentGame!.player4Color ?? 'green';
      default: return 'yellow';
    }
  }

  Widget _buildBoardPlayerLabels(double sz) {
    if (_currentGame == null) return const SizedBox.shrink();
    final activeColor = _colorForCurrentTurn();
    const pad = 8.0;

    final colorNames = <String, String>{};
    void addPlayer(int n, String? color, String? name) {
      if (color == null) return;
      colorNames[color] = (n == widget.playerNumber) ? 'Tú' : (name ?? 'J$n').split(' ').first;
    }
    addPlayer(1, _currentGame!.player1Color, _currentGame!.hostName);
    addPlayer(2, _currentGame!.player2Color, _currentGame!.guest2Name);
    addPlayer(3, _currentGame!.player3Color, _currentGame!.guest3Name);
    addPlayer(4, _currentGame!.player4Color, _currentGame!.guest4Name);

    Widget lbl(String color, {double? top, double? bottom, double? left, double? right}) {
      final name = colorNames[color];
      if (name == null) return const SizedBox.shrink();
      final pc = _getPlayerColor(color);
      final isActive = color == activeColor;
      final isMe = name == 'Tú';
      return Positioned(
        top: top, bottom: bottom, left: left, right: right,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? pc.withValues(alpha: 0.90) : Colors.black.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: isMe ? Border.all(color: Colors.white, width: 1.5) : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)],
          ),
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white, fontSize: 11,
              fontWeight: (isMe || isActive) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: sz, height: sz,
      child: Stack(children: [
        lbl('green',  top: pad,    left: pad),
        lbl('yellow', top: pad,    right: pad),
        lbl('red',    bottom: pad, left: pad),
        lbl('blue',   bottom: pad, right: pad),
      ]),
    );
  }

  Widget _buildPlayersInfo() {
    if (_currentGame == null) {
      return const SizedBox(height: 50,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFEC7A34))));
    }
    final players = <Map<String, dynamic>>[];
    void add(int n, String? id, String? name, String? photo, String color) {
      if (id == null) return;
      players.add({'n': n, 'id': id, 'name': name ?? 'Jugador', 'photo': photo, 'color': color});
    }
    add(1, _currentGame!.hostId, _currentGame!.hostName, _currentGame!.hostPhotoUrl, _currentGame!.player1Color);
    if (_currentGame!.guest2Id != null) {
      add(2, _currentGame!.guest2Id, _currentGame!.guest2Name, _currentGame!.guest2PhotoUrl, _currentGame!.player2Color ?? 'red');
    }
    if (_currentGame!.guest3Id != null) {
      add(3, _currentGame!.guest3Id, _currentGame!.guest3Name, _currentGame!.guest3PhotoUrl, _currentGame!.player3Color ?? 'blue');
    }
    if (_currentGame!.guest4Id != null) {
      add(4, _currentGame!.guest4Id, _currentGame!.guest4Name, _currentGame!.guest4PhotoUrl, _currentGame!.player4Color ?? 'green');
    }

    return Container(
      height: 56,
      color: Colors.white,
      child: Row(
        children: players.map((p) {
          final isActive = _currentTurn == 'player${p['n']}';
          final isMe = p['n'] == widget.playerNumber;
          final col = _getPlayerColor(p['color'] as String);
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                border: isActive
                    ? Border(bottom: BorderSide(color: col, width: 3))
                    : null,
                color: isActive ? col.withValues(alpha: 0.08) : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 4)]),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isMe ? 'Tú' : (p['name'] as String).split(' ').first,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? col : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatWidget() {
    const quickEmojis = ['😂', '😤', '💀', '🫡', '🔥', '😈', '👑', '🤡'];
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 2),
                itemCount: quickEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) => Material(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: null, // TODO: enviar emoji al chat
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(quickEmojis[i], style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: null, // TODO: abrir chat completo
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEC7A34).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEC7A34).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFEC7A34)),
                  SizedBox(width: 4),
                  Text('Chat', style: TextStyle(fontSize: 12, color: Color(0xFFEC7A34), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final canRoll = _isMyTurn && !_gameEnded && _dice1Value == 0 && _dice2Value == 0 && !_isRollingDice && !_bonusSelectionActive;
    final isOpponentTurn = !_isMyTurn && !_gameEnded;
    final currentColor = _currentGame != null ? _colorForCurrentTurn() : _myColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildDiceWidget(_dice1Value, _hasUsedDice1),
          const SizedBox(width: 8),
          _buildDiceWidget(_dice2Value, _hasUsedDice2),
          const SizedBox(width: 12),
          Expanded(
            child: isOpponentTurn
                ? _buildWaitingIndicator(currentColor)
                : canRoll
                    ? _buildRollButton()
                    : _isMyTurn
                        ? _buildSelectPieceHint()
                        : const SizedBox.shrink(),
          ),
          if (_isMyTurn && !_gameEnded && _turnTimerSeconds > 0)
            _buildTimer(),
        ],
      ),
    );
  }

  Widget _buildDiceWidget(int value, bool used) {
    return AnimatedBuilder(
      animation: _diceRotation,
      builder: (ctx, _) {
        return Transform.rotate(
          angle: _isRollingDice ? _diceRotation.value : 0,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: used ? Colors.grey.shade300 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: value == 0
                  ? Icon(Icons.casino, color: Colors.grey.shade400, size: 28)
                  : CustomPaint(size: const Size(34, 34), painter: DiceDotsPainter(value)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRollButton() {
    return ElevatedButton.icon(
      onPressed: _rollDice,
      icon: const Icon(Icons.casino, size: 20),
      label: const Text('Lanzar dados', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEC7A34),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildWaitingIndicator(String color) {
    return Row(
      children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _getPlayerColor(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Turno de ${_getColorName(color)}',
          style: TextStyle(
            fontSize: 13,
            color: _getPlayerColor(color),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectPieceHint() {
    return const Text(
      'Toca una ficha para mover',
      style: TextStyle(fontSize: 13, color: Color(0xFFEC7A34), fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTimer() {
    final low = _turnTimerSeconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: low ? Colors.red : Colors.green.shade700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$_turnTimerSeconds"',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}


class DiceDotsPainter extends CustomPainter {
  final int value;
  DiceDotsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final r = size.width * 0.09;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final off = size.width * 0.28;

    final dotPositions = <List<Offset>>[
      [Offset(cx, cy)],
      [Offset(cx - off, cy - off), Offset(cx + off, cy + off)],
      [Offset(cx - off, cy - off), Offset(cx, cy), Offset(cx + off, cy + off)],
      [Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx - off, cy + off), Offset(cx + off, cy + off)],
      [Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx, cy), Offset(cx - off, cy + off), Offset(cx + off, cy + off)],
      [Offset(cx - off, cy - off), Offset(cx + off, cy - off), Offset(cx - off, cy), Offset(cx + off, cy), Offset(cx - off, cy + off), Offset(cx + off, cy + off)],
    ];

    if (value >= 1 && value <= 6) {
      for (final pos in dotPositions[value - 1]) {
        canvas.drawCircle(pos, r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DiceDotsPainter old) => old.value != value;
}

class _Coord {
  final int col;
  final int row;
  const _Coord(this.col, this.row);
}
