import 'dart:ui' as ui;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';
import 'package:flutter_stockfish_plugin/stockfish_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/service/firestore_service.dart';
import '../../../generated/l10n.dart';
import '../../../core/utils/game_type.dart';
import '../../../core/utils/game_result.dart';
import '../../adds/banner_ad_widget.dart';
import '../../adds/Interstitial_ad_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ChessVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;
  final String matchType;

  const ChessVsComputerScreen(
    this.selectedDifficulty, {
    super.key,
    required this.matchType,
  });

  @override
  State<ChessVsComputerScreen> createState() => _ChessVsComputerScreenState();
}

class _ChessVsComputerScreenState extends State<ChessVsComputerScreen>
    with WidgetsBindingObserver {
  late Stockfish _stockfish;
  ChessBoardController controller = ChessBoardController();
  late InterstitialAdHelper _interstitialHelper;

  int playerScore = 0;
  int cpuScore = 0;

  bool _isStockfishReady = false;
  bool _gameEnded = false;
  bool _showGameEndOverlay = false;
  String _gameEndMessage = '';
  bool _hasStartedGame = false;
  bool _waitingForCpuMove = false;

  Timer? _playerTimer;
  Timer? _initialMoveTimer;
  int _playerTimeSeconds = 60;
  bool _hasPlayerMovedOnce = false;
  bool _isPlayerTurn = false;

  late int _cpuMoveTime;
  DateTime? _gameStartTime;
  int? _userCoins;
  int? _userDiamonds;
  PlayerColor? _playerColor;

  bool _isScreenKeepOnActive = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  final List<Map<String, String>> _moveHistory = [];
  String? _lastMoveFrom;
  String? _lastMoveTo;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakeLock();

    final isBetMode = widget.matchType.toLowerCase().contains('apuesta') ||
        widget.matchType.toLowerCase().contains('bet');

    if (isBetMode) {
      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'normal':
          _cpuMoveTime = 250;
          break;
        case 'difícil':
          _cpuMoveTime = 400;
          break;
        case 'muy difícil':
          _cpuMoveTime = 600;
          break;
        default:
          _cpuMoveTime = 250;
      }
    } else {
      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'muy fácil':
          _cpuMoveTime = 50;
          break;
        case 'fácil':
          _cpuMoveTime = 75;
          break;
        case 'normal':
          _cpuMoveTime = 100;
          break;
        case 'difícil':
          _cpuMoveTime = 150;
          break;
        default:
          _cpuMoveTime = 100;
      }
    }

    _stockfish = Stockfish();

    _stockfish.stdout.listen((output) {
      if (output.contains('bestmove ')) {
        final parts = output.split(' ');
        if (parts.length >= 2) {
          final best = parts[1];

          if (best == '0000' || best == '(none)') {
            _waitingForCpuMove = false;
            return;
          }

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _applyUciMoveToBoard(best);
              _checkGameEnd();
              _waitingForCpuMove = false;

              if (!_gameEnded) {
                setState(() {
                  _isPlayerTurn = true;
                  _playerTimeSeconds = 60;
                });
                _startPlayerTimer();
              }
              setState(() {});
            }
          });
        }
      }
    });

    _stockfish.state.addListener(() async {
      if (_stockfish.state.value == StockfishState.ready &&
          !_isStockfishReady) {
        _isStockfishReady = true;
        await _initializeStockfish();

        if (_playerColor == PlayerColor.black) {
          _makeCpuMove();
        } else {
          setState(() {
            _isPlayerTurn = true;
          });
          _startInitialMoveTimer();
        }
      }
    });

    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
    _loadUserCurrency();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserCurrency();
  }

  Future<void> _loadUserCurrency() async {
    if (currentUser == null) return;
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userDiamonds = userData['diamonds'] ?? 0;
          _userCoins = userData['coins'] ?? 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user currency: $e');
      }
      setState(() {
        _userDiamonds = 0;
        _userCoins = 0;
      });
    }
  }

  String _getCurrencyType() {
    return widget.matchType == S.of(context).bet ? 'diamonds' : 'coins';
  }


  IconData _getCurrencyIcon() {
    return widget.matchType == S.of(context).bet
        ? Icons.diamond
        : Icons.monetization_on;
  }

  int? _getCurrentBalance() {
    return widget.matchType == S.of(context).bet ? _userDiamonds : _userCoins;
  }

  int _getGameCost() {
    return widget.matchType == S.of(context).bet ? 5 : 100;
  }

  void _startInitialMoveTimer() {
    if (_hasPlayerMovedOnce || _gameEnded) return;

    _initialMoveTimer?.cancel();
    _initialMoveTimer = Timer(const Duration(seconds: 14), () {
      if (!_hasPlayerMovedOnce && !_gameEnded && mounted) {
        _timeOut(isInitialTimeout: true);
      }
    });
  }

  void _startPlayerTimer() {
    if (_gameEnded) return;

    _playerTimer?.cancel();
    _playerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameEnded) {
        timer.cancel();
        return;
      }

      if (_isPlayerTurn) {
        setState(() {
          _playerTimeSeconds--;
        });

        if (_playerTimeSeconds <= 0) {
          timer.cancel();
          _timeOut(isInitialTimeout: false);
        }
      }
    });
  }

  void _timeOut({required bool isInitialTimeout}) {
    if (_gameEnded) return;

    _gameEnded = true;
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();

    cpuScore++;

    String message =
        isInitialTimeout
            ? 'Tiempo agotado: No realizaste tu primer movimiento en 14 segundos'
            : 'Tiempo agotado: No completaste tu movimiento en 1 minuto';

    _showTimeoutDialog(message);
    _recordGameResult(GameResultModel.loss);

    setState(() {});
  }

  void _showTimeoutDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.timer_off, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text(
                  'Tiempo Agotado',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.timer_off, size: 48, color: Colors.red),
                      SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.red[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _restartGame();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(S.of(context).newGame),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(S.of(context).exit),
                ),
              ),
            ],
          ),
    );
  }

  Future<bool> _showAbandonDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          '¿${S.of(context).abandonGame}?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              S.of(context).abandonGameWarning,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              S.of(context).areYouSure,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).continueGame),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(S.of(context).abandonGame),
            ),
          ),
        ],
      ),
    ) ?? false;
  }


  Widget _buildTimer() {
    if (_gameEnded || !_isPlayerTurn) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 40,
      );
    }
    final minutes = _playerTimeSeconds ~/ 60;
    final seconds = _playerTimeSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isRunningOut = _playerTimeSeconds <= 10;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isRunningOut ? Colors.red[700] : Colors.green[700],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isRunningOut ? Colors.red : Colors.green).withValues(
              alpha: 0.3,
            ),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            timeString,
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

  Future<bool> _checkAndDeductGameCost() async {
    if (currentUser == null) return false;

    final currentBalance = _getCurrentBalance();
    final gameCost = _getGameCost();

    if (currentBalance == null || currentBalance < gameCost) {
      _showInsufficientFundsDialog();
      return false;
    }

    final isBet = widget.matchType == S.of(context).bet;

    try {
      final userData = await _firestoreService.getUser(currentUser!.uid);
      if (!mounted) return false;
      if (userData != null) {
        if (isBet) {
          final newDiamonds = userData.diamonds - gameCost;
          await _firestoreService.updateUserDiamonds(
            currentUser!.uid,
            newDiamonds,
          );
          if (!mounted) return false;
          setState(() => _userDiamonds = newDiamonds);
        } else {
          final newCoins = userData.coins - gameCost;
          await _firestoreService.updateUserCoins(currentUser!.uid, newCoins);
          if (!mounted) return false;
          setState(() => _userCoins = newCoins);
        }
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deducting game cost: $e');
      }
      _showError('Error al procesar el pago del juego');
      return false;
    }
  }

  void _showInsufficientFundsDialog() {
    final gameCost = _getGameCost();
    final currencyName = _getCurrencyType();
    final currentBalance = _getCurrentBalance() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(_getCurrencyIcon(), color: Colors.red),
                SizedBox(width: 8),
                Text(S.of(context).insufficientFunds),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${S.of(context).youNeed} $gameCost $currencyName ${S.of(context).toPlay}.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  '${S.of(context).yourCurrentBalance} $currentBalance $currencyName',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).back),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _initializeStockfish() async {
    final isFun = widget.matchType == S.of(context).fun;
    final isBet = widget.matchType == S.of(context).bet;

    _stockfish.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _stockfish.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (isFun) {
      _stockfish.stdin = "setoption name Threads value 1";
      _stockfish.stdin = "setoption name Hash value 32";
    }

    if (isBet) {
      _stockfish.stdin = "setoption name Hash value 128";
    } else {
      _stockfish.stdin = "setoption name Hash value 32";
    }

    if (isBet) {
      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'normal':
          _stockfish.stdin = "setoption name Skill Level value 15";
          break;
        case 'difícil':
          _stockfish.stdin = "setoption name Skill Level value 18";
          break;
        case 'muy difícil':
          _stockfish.stdin = "setoption name Skill Level value 20";
          break;
      }
    } else {
      switch (widget.selectedDifficulty.toLowerCase()) {
        case 'muy fácil':
          _stockfish.stdin = "setoption name Skill Level value 0";
          break;
        case 'fácil':
          _stockfish.stdin = "setoption name Skill Level value 5";
          break;
        case 'normal':
          _stockfish.stdin = "setoption name Skill Level value 10";
          break;
        case 'difícil':
          _stockfish.stdin = "setoption name Skill Level value 15";
          break;
      }
    }
  }

  void _makeCpuMove() {
    if (!_isStockfishReady || _gameEnded || _waitingForCpuMove) return;

    _waitingForCpuMove = true;

    final fen = controller.getFen();
    _stockfish.stdin = "position fen $fen";

    if (widget.selectedDifficulty.toLowerCase() == 'muy fácil') {
      _stockfish.stdin = "go depth 1";
    } else if (widget.selectedDifficulty.toLowerCase() == 'fácil') {
      _stockfish.stdin = "go depth 3";
    } else {
      _stockfish.stdin = "go movetime $_cpuMoveTime";
    }
  }

  void playerMoved() async {
    if (!_isStockfishReady || _gameEnded) return;

    if (!_hasStartedGame) {
      final canPlay = await _checkAndDeductGameCost();
      if (!mounted) return;
      if (!canPlay) {
        return;
      }
      _hasStartedGame = true;
      _gameStartTime = DateTime.now();
    }

    if (!_hasPlayerMovedOnce) {
      _hasPlayerMovedOnce = true;
      _initialMoveTimer?.cancel();
    }

    _playerTimer?.cancel();

    setState(() {
      _isPlayerTurn = false;
    });

    _checkGameEnd();

    if (!_gameEnded) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _makeCpuMove();
      });
    }
  }

  void _checkGameEnd() {
    bool isCheckMate = controller.isCheckMate();
    bool isCheck = controller.isInCheck();

    if (isCheckMate) {
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();

      final isWhiteTurn = controller.getFen().split(' ')[1] == 'w';
      final playerWon =
          (_playerColor == PlayerColor.white && !isWhiteTurn) ||
          (_playerColor == PlayerColor.black && isWhiteTurn);

      if (playerWon) {
        playerScore++;
        _showGameEndDialog('${S.of(context).youWonCheckMate}\n¡Jaque Mate!');
        _recordGameResult(GameResultModel.win);
      } else {
        cpuScore++;
        _showGameEndDialog('${S.of(context).cpuWonCheckMate}\n¡Jaque Mate!');
        _recordGameResult(GameResultModel.loss);
      }

      setState(() {});
    } else if (controller.isDraw()) {
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();
      _showGameEndDialog(S.of(context).drawMsg);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isStaleMate()) {
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();
      _showGameEndDialog(S.of(context).drawByStalemate);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isThreefoldRepetition()) {
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();
      _showGameEndDialog(S.of(context).tieByReply);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isInsufficientMaterial()) {
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();
      _showGameEndDialog(S.of(context).tieByInsufficient);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (isCheck) {
      _showCheckMessage();
    }
  }

  void _showCheckMessage() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Jaque!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (currentUser == null) return;
    if (_gameStartTime == null) return;

    final isBet = widget.matchType == S.of(context).bet;
    final currencyType = _getCurrencyType();

    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      int pointsEarned = 0;
      int currencyChange = 0;
      final gameCost = _getGameCost();

      switch (result) {
        case GameResultModel.win:
          pointsEarned = 15;
          currencyChange = gameCost + (gameCost ~/ 2);
          break;
        case GameResultModel.loss:
          pointsEarned = -5;
          currencyChange = 0;
          break;
        case GameResultModel.draw:
          pointsEarned = 5;
          currencyChange = gameCost ~/ 2;
          break;
      }

      if (currencyChange > 0) {
        final userData = await _firestoreService.getUser(currentUser!.uid);
        if (!mounted) return;
        if (userData != null) {
          if (isBet) {
            final newDiamonds = userData.diamonds + currencyChange;
            await _firestoreService.updateUserDiamonds(
              currentUser!.uid,
              newDiamonds,
            );
            if (!mounted) return;
            setState(() => _userDiamonds = newDiamonds);
          } else {
            final newCoins = userData.coins + currencyChange;
            await _firestoreService.updateUserCoins(currentUser!.uid, newCoins);
            if (!mounted) return;
            setState(() => _userCoins = newCoins);
          }
        }
      }

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: 'CPU (${widget.selectedDifficulty})',
        additionalData: {
          'difficulty': widget.selectedDifficulty,
          'playerColor': _playerColor == PlayerColor.white ? 'white' : 'black',
          'finalFEN': controller.getFen(),
          'gameCost': gameCost,
          'currencyChange': currencyChange,
          'currencyType': currencyType,
          'matchType': widget.matchType,
          'timeControl': '1 minuto por movimiento',
          'hasTimeLimit': true,
        },
      );

      if (!mounted) return;
      if (success) {
        if (currencyChange > 0) {
          if (kDebugMode) {
            print('Recompensa: $currencyChange $currencyType');
          }
        }
      } else {
        if (kDebugMode) {
          print('Error al registrar la partida en Firestore');
        }
      }
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

  void _showGameEndDialog(String message) {
    if (!mounted) return;
    setState(() {
      _showGameEndOverlay = true;
      _gameEndMessage = message;
    });
  }

  Widget _buildGameEndOverlay() {
    final isWin = _gameEndMessage.toLowerCase().contains('ganaste') ||
        _gameEndMessage.toLowerCase().contains('won');
    final color = isWin ? Colors.green[700]! : Colors.red[700]!;
    final icon = isWin ? Icons.emoji_events_rounded : Icons.sports_esports_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gameEndMessage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameEndButtons() {
    final isWin = _gameEndMessage.toLowerCase().contains('ganaste') ||
        _gameEndMessage.toLowerCase().contains('won');
    final color = isWin ? Colors.green[700]! : Colors.red[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(S.of(context).exit),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(S.of(context).newGame),
            ),
          ),
        ],
      ),
    );
  }

  void _applyUciMoveToBoard(String uci) {
    String from = '';
    String to = '';

    if (uci.length == 4) {
      from = uci.substring(0, 2);
      to = uci.substring(2, 4);
      controller.makeMove(from: from, to: to);
    }

    if (uci.length == 5) {
      from = uci.substring(0, 2);
      to = uci.substring(2, 4);
      final promo = uci.substring(4).toUpperCase();
      controller.makeMoveWithPromotion(
        from: from,
        to: to,
        pieceToPromoteTo: promo,
      );
    }

    setState(() {
      _lastMoveFrom = from;
      _lastMoveTo = to;
      _moveHistory.add({'from': from, 'to': to, 'player': 'CPU'});
    });
  }

  void _selectPlayerColor(PlayerColor color) async {
    final currentBalance = _getCurrentBalance();
    final gameCost = _getGameCost();

    if (currentBalance == null || currentBalance < gameCost) {
      _showInsufficientFundsDialog();
      return;
    }

    setState(() {
      _playerColor = color;
      if (_playerColor == PlayerColor.black && _isStockfishReady) {
        _makeCpuMove();
      } else if (_playerColor == PlayerColor.white) {
        _isPlayerTurn = true;
        _startInitialMoveTimer();
      }
    });
  }

  void _restartGame() {
    _interstitialHelper.showAdIfReady(
      onComplete: () {
        _playerTimer?.cancel();
        _initialMoveTimer?.cancel();
        _gameEnded = false;
        _showGameEndOverlay = false;
        _gameEndMessage = '';
        _waitingForCpuMove = false;
        _hasStartedGame = false;
        _gameStartTime = null;
        _hasPlayerMovedOnce = false;
        _isPlayerTurn = false;
        _playerTimeSeconds = 60;

        controller.resetBoard();

        if (_isStockfishReady) {
          final fen = controller.getFen();
          _stockfish.stdin = "position fen $fen";

          if (_playerColor == PlayerColor.black) {
            _makeCpuMove();
          } else {
            setState(() {
              _isPlayerTurn = true;
            });
            _startInitialMoveTimer();
          }
        }
        setState(() {});
      },
    );
  }

  Widget _buildPlayerAvatar() {
    if (currentUser?.photoURL != null) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(currentUser!.photoURL!),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    } else {
      return CircleAvatar(
        radius: 30,
        backgroundColor:
            _playerColor == PlayerColor.white ? Colors.white : Colors.black,
        child: Icon(
          Icons.person,
          color:
              _playerColor == PlayerColor.white ? Colors.black : Colors.white,
          size: 30,
        ),
      );
    }
  }

  Widget _buildCpuAvatar() {
    return CircleAvatar(
      radius: 30,
      backgroundColor:
          _playerColor == PlayerColor.white ? Colors.black : Colors.white,
      child: Icon(
        Icons.smart_toy,
        color: _playerColor == PlayerColor.white ? Colors.white : Colors.black,
        size: 30,
      ),
    );
  }

  Widget _buildCurrencyDisplay() {
    final currentBalance = _getCurrentBalance() ?? 0;
    final gameCost = _getGameCost();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCurrencyIcon(),
            color:
                widget.matchType == S.of(context).bet
                    ? Colors.amber
                    : Colors.blue,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            '$currentBalance ${_getCurrencyType()}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Costo: $gameCost',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();
    if (_isStockfishReady) _stockfish.stdin = "quit";
    _stockfish.dispose();
    _interstitialHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playerColor == null) {
      return Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCurrencyDisplay(),
              SizedBox(height: 30),
              Text(
                S.of(context).changeColor,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _selectPlayerColor(PlayerColor.white),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 40, backgroundColor: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).whites,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),
                  GestureDetector(
                    onTap: () => _selectPlayerColor(PlayerColor.black),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 40, backgroundColor: Colors.black),
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).blacks,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: _gameEnded,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldAbandon = await _showAbandonDialog();
        if (!context.mounted) return;
        if (shouldAbandon) {
          _interstitialHelper.forceShowAd(
            onComplete: () async {
              await _recordGameResult(GameResultModel.loss);
            },
          );
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).playerVsCpu,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [Center(child: _buildCurrencyDisplay())],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      _buildPlayerAvatar(),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.displayName ?? 'Tú',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$playerScore - $cpuScore',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        S.of(context).marker,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _buildCpuAvatar(),
                      const SizedBox(height: 6),
                      Text(
                        S.of(context).cpu,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _buildTimer(),

            if (_showGameEndOverlay) _buildGameEndOverlay(),

            if (!_gameEnded && !_showGameEndOverlay)
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _isPlayerTurn ? 'Tu turno' : 'Turno del CPU',
                  style: TextStyle(
                    color: _isPlayerTurn ? Colors.green[300] : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChessBoard(
                  controller: controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: _playerColor!,
                  enableUserMoves: !_gameEnded && _isPlayerTurn,
                  onMove: playerMoved,
                  arrows: _lastMoveFrom != null && _lastMoveTo != null
                      ? [
                    BoardArrow(
                      from: _lastMoveFrom!,
                      to: _lastMoveTo!,
                      color: Colors.yellowAccent.withValues(alpha: 0.5),
                    ),
                  ] : [],
                ),
              ),
            ),
            if (_showGameEndOverlay)
              _buildGameEndButtons()
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.replay),
                  label: Text(S.of(context).restartGame),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            const BannerAdWidget(),
          ],
        ),
      ),
    )
    );
  }
}
