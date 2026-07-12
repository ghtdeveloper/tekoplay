import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/domino_tile.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../adds/Interstitial_ad_helper.dart';

enum _GamePhase { playerTurn, cpuTurn, roundEnd, gameOver }
enum _RoundResult { playerWon, cpuWon, blocked }

class _PlayedTile {
  final DominoTile tile;
  final int displayLeft;
  final int displayRight;
  bool get isDouble => displayLeft == displayRight;

  _PlayedTile({required this.tile, required this.displayLeft, required this.displayRight});
}

class _DominoController {
  List<DominoTile> playerHand = [];
  List<DominoTile> cpuHand = [];
  List<_PlayedTile> chain = [];
  List<DominoTile> boneyard = [];

  int? leftOpen;
  int? rightOpen;

  _GamePhase phase = _GamePhase.playerTurn;
  int openingDoubleValue = -1;
  int playerScore = 0;
  int cpuScore = 0;
  int roundNumber = 1;
  int consecutivePasses = 0;
  int targetScore = 100;
  String difficulty = 'normal';

  Timer? _timer;
  int timeLeft = 30;
  bool timerActive = false;
  VoidCallback? onTimeUpdate;
  VoidCallback? onTimeOut;

  void init({required String diff, required int target}) {
    difficulty = diff;
    targetScore = target;
    playerScore = 0;
    cpuScore = 0;
    roundNumber = 1;
    _startRound();
  }

  void _startRound() {
    playerHand.clear();
    cpuHand.clear();
    chain.clear();
    boneyard.clear();
    leftOpen = null;
    rightOpen = null;
    consecutivePasses = 0;

    int id = 0;
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        boneyard.add(DominoTile(left: i, right: j, id: 'r${roundNumber}_$id'));
        id++;
      }
    }
    boneyard.shuffle(Random());

    for (int i = 0; i < 7; i++) {
      playerHand.add(boneyard.removeAt(0));
      cpuHand.add(boneyard.removeAt(0));
    }

    phase = _determineFirst();
  }

  _GamePhase _determineFirst() {
    int pHigh = -1, cHigh = -1;
    for (final t in playerHand) {
      if (t.isDouble && t.left > pHigh) pHigh = t.left;
    }
    for (final t in cpuHand) {
      if (t.isDouble && t.left > cHigh) cHigh = t.left;
    }
    if (pHigh != -1 || cHigh != -1) {
      if (pHigh >= cHigh) {
        openingDoubleValue = pHigh;
        return _GamePhase.playerTurn;
      } else {
        openingDoubleValue = cHigh;
        return _GamePhase.cpuTurn;
      }
    }
    openingDoubleValue = -1;
    final pMax = playerHand.map((t) => t.total).reduce(max);
    final cMax = cpuHand.map((t) => t.total).reduce(max);
    return pMax >= cMax ? _GamePhase.playerTurn : _GamePhase.cpuTurn;
  }

  bool canPlay(DominoTile tile) {
    if (chain.isEmpty) {
      if (openingDoubleValue != -1) {
        return tile.isDouble && tile.left == openingDoubleValue;
      }
      return true;
    }
    return tile.canConnectTo(leftOpen!) || tile.canConnectTo(rightOpen!);
  }

  bool canPlayerPlayAny() => playerHand.any(canPlay);
  bool canCpuPlayAny() => cpuHand.any(canPlay);

  bool playTile(DominoTile tile, String side) {
    if (!canPlay(tile)) return false;
    tile.isPlayed = true;

    int displayLeft, displayRight;
    if (chain.isEmpty) {
      displayLeft = tile.left;
      displayRight = tile.right;
      leftOpen = tile.left;
      rightOpen = tile.right;
      chain.add(_PlayedTile(tile: tile, displayLeft: displayLeft, displayRight: displayRight));
    } else if (side == 'left') {
      if (tile.right == leftOpen) {
        displayLeft = tile.left;
        displayRight = tile.right;
        leftOpen = tile.isDouble ? tile.left : tile.left;
      } else {
        displayLeft = tile.right;
        displayRight = tile.left;
        leftOpen = tile.isDouble ? tile.right : tile.right;
      }
      chain.insert(0, _PlayedTile(tile: tile, displayLeft: displayLeft, displayRight: displayRight));
    } else {
      if (tile.left == rightOpen) {
        displayLeft = tile.left;
        displayRight = tile.right;
        rightOpen = tile.isDouble ? tile.right : tile.right;
      } else {
        displayLeft = tile.right;
        displayRight = tile.left;
        rightOpen = tile.isDouble ? tile.left : tile.left;
      }
      chain.add(_PlayedTile(tile: tile, displayLeft: displayLeft, displayRight: displayRight));
    }

    if (side == 'left' && chain.isNotEmpty && !tile.isDouble) {
      leftOpen = chain.first.displayLeft;
    } else if (side == 'right' && chain.isNotEmpty && !tile.isDouble) {
      rightOpen = chain.last.displayRight;
    } else if (chain.length == 1) {
      leftOpen = chain.first.displayLeft;
      rightOpen = chain.first.displayRight;
    }

    consecutivePasses = 0;
    return true;
  }

  bool drawFromBoneyard(bool isPlayer) {
    if (boneyard.isEmpty) return false;
    final drawn = boneyard.removeAt(0);
    if (isPlayer) {
      playerHand.add(drawn);
    } else {
      cpuHand.add(drawn);
    }
    return true;
  }

  _RoundResult? checkRoundEnd() {
    if (playerHand.isEmpty) {
      final pip = cpuHand.fold(0, (s, t) => s + t.total);
      playerScore += pip;
      return _RoundResult.playerWon;
    }
    if (cpuHand.isEmpty) {
      final pip = playerHand.fold(0, (s, t) => s + t.total);
      cpuScore += pip;
      return _RoundResult.cpuWon;
    }
    if (consecutivePasses >= 2) {
      final pPip = playerHand.fold(0, (s, t) => s + t.total);
      final cPip = cpuHand.fold(0, (s, t) => s + t.total);
      if (pPip < cPip) {
        playerScore += cPip;
        return _RoundResult.playerWon;
      } else if (cPip < pPip) {
        cpuScore += pPip;
        return _RoundResult.cpuWon;
      } else {
        return _RoundResult.blocked;
      }
    }
    return null;
  }

  bool isGameOver() => playerScore >= targetScore || cpuScore >= targetScore;

  void startNextRound() {
    roundNumber++;
    _startRound();
  }

  DominoTile? getBestCpuMove() {
    final playable = cpuHand.where(canPlay).toList();
    if (playable.isEmpty) return null;

    switch (difficulty) {
      case 'muy fácil':
        return playable[Random().nextInt(playable.length)];
      case 'difícil':
        playable.sort((a, b) => b.total.compareTo(a.total));
        return playable.first;
      default:
        final doubles = playable.where((t) => t.isDouble).toList();
        if (doubles.isNotEmpty) {
          doubles.sort((a, b) => a.left.compareTo(b.left));
          return doubles.first;
        }
        playable.sort((a, b) => b.total.compareTo(a.total));
        return playable.first;
    }
  }

  String getCpuPlaySide(DominoTile tile) {
    if (chain.isEmpty) return 'right';
    if (tile.canConnectTo(leftOpen!)) return 'left';
    return 'right';
  }

  void startTimer() {
    _stopTimer();
    timeLeft = 30;
    timerActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      timeLeft--;
      onTimeUpdate?.call();
      if (timeLeft <= 0) {
        _stopTimer();
        onTimeOut?.call();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    timerActive = false;
  }

  void dispose() {
    _stopTimer();
  }
}

class DominoVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;
  final String matchType;

  const DominoVsComputerScreen(
    this.selectedDifficulty, {
    super.key,
    this.matchType = 'Diversión',
  });

  @override
  State<DominoVsComputerScreen> createState() => _DominoVsComputerScreenState();
}

class _DominoVsComputerScreenState extends State<DominoVsComputerScreen>
    with TickerProviderStateMixin {
  final _DominoController _ctrl = _DominoController();
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _gameStarted = false;
  late InterstitialAdHelper _adHelper;

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

  late AnimationController _cpuTileAnimCtrl;
  late AnimationController _playerTileAnimCtrl;
  late Animation<double> _pulseAnim;

  DominoTile? _selectedTile;
  bool _needsSideChoice = false;
  bool _isCpuThinking = false;
  bool _gameEnded = false;
  int _userDiamonds = 0;
  int _userCoins = 0;

  static const Color _tableColor = Color(0xFFD4A850);
  static const Color _panelColor = Color(0xDD1A0800);
  static const Color _tileColor = Color(0xFFFFF8E1);
  static const Color _tileBorder = Color(0xFF4A3728);
  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();

    _cpuTileAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _playerTileAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _playerTileAnimCtrl, curve: Curves.easeInOut),
    );

    _adHelper = InterstitialAdHelper(showFrequency: 3);

    _ctrl.onTimeUpdate = () {
      if (mounted) setState(() {});
    };
    _ctrl.onTimeOut = _handleTimeOut;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAndDeductGameCost();
      if (mounted) _showStartDialog();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _chainScrollCtrl.dispose();
    _cpuTileAnimCtrl.dispose();
    _playerTileAnimCtrl.dispose();
    _adHelper.dispose();
    super.dispose();
  }

  void _showStartDialog() {
    _adHelper.showAdIfReady(onComplete: () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dominó vs CPU',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _accentOrange,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dificultad: ${widget.selectedDifficulty}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                if (widget.matchType == 'Apuesta') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Apuesta: ${_getGameCost()} 💎 — Premio: ${(_getGameCost() * 2 * 0.9).floor()} 💎',
                    style: const TextStyle(fontSize: 13, color: _accentOrange, fontWeight: FontWeight.w600),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Costo: ${_getGameCost()} 🪙 — Premio: ${(_getGameCost() * 2 * 0.9).floor()} 🪙',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  '¿Meta de puntos?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [50, 100, 150, 200].map((pts) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startGame(pts);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text('$pts\npuntos', textAlign: TextAlign.center),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _startGame(int target) {
    _ctrl.init(diff: widget.selectedDifficulty, target: target);
    setState(() {
      _gameStarted = true;
      _selectedTile = null;
      _needsSideChoice = false;
    });
    if (_ctrl.phase == _GamePhase.cpuTurn) {
      _scheduleCpuTurn();
    } else {
      _ctrl.startTimer();
    }
  }

  void _handleTimeOut() {
    if (!mounted) return;
    if (_ctrl.phase == _GamePhase.playerTurn) {
      _passPlayerTurn();
    }
  }

  void _onTileTap(DominoTile tile) {
    if (_ctrl.phase != _GamePhase.playerTurn) return;
    if (!_ctrl.canPlay(tile)) {
      if (_ctrl.chain.isEmpty && _ctrl.openingDoubleValue != -1) {
        _showSnack('Debes abrir con el doble ${_ctrl.openingDoubleValue}-${_ctrl.openingDoubleValue}', success: false);
      } else {
        _showSnack('Esta ficha no conecta con los extremos disponibles', success: false);
      }
      return;
    }

    setState(() {
      _selectedTile = tile;
    });

    if (_ctrl.chain.isEmpty) {
      _placeSelectedTile('right');
      return;
    }

    final canLeft = tile.canConnectTo(_ctrl.leftOpen!);
    final canRight = tile.canConnectTo(_ctrl.rightOpen!);

    _placeSelectedTile(canRight ? 'right' : 'left');
  }

  void _placeSelectedTile(String side) {
    final tile = _selectedTile;
    if (tile == null) return;

    _ctrl._stopTimer();
    final played = _ctrl.playTile(tile, side);
    if (!played) {
      setState(() {
        _selectedTile = null;
        _needsSideChoice = false;
      });
      return;
    }

    _ctrl.playerHand.remove(tile);

    final roundResult = _ctrl.checkRoundEnd();

    setState(() {
      _selectedTile = null;
      _needsSideChoice = false;
    });

    if (roundResult != null) {
      _handleRoundEnd(roundResult);
    } else {
      setState(() => _ctrl.phase = _GamePhase.cpuTurn);
      _scheduleCpuTurn();
    }

    _scrollChainToEnd();
  }

  void _drawFromBoneyard() {
    if (_ctrl.phase != _GamePhase.playerTurn) return;
    if (_ctrl.boneyard.isEmpty) {
      _showSnack('El pozo está vacío');
      return;
    }
    if (_ctrl.canPlayerPlayAny()) {
      _showSnack('Tienes fichas que puedes jugar');
      return;
    }
    setState(() {
      _ctrl.drawFromBoneyard(true);
    });
    if (_ctrl.canPlayerPlayAny()) {
      _showSnack('¡Ficha tomada! Ahora puedes jugar', success: true);
    } else {
      _showSnack('Sin opciones, pasa tu turno');
    }
  }

  void _passPlayerTurn() {
    if (_ctrl.phase != _GamePhase.playerTurn) return;
    _ctrl._stopTimer();
    _ctrl.consecutivePasses++;

    final roundResult = _ctrl.checkRoundEnd();
    if (roundResult != null) {
      _handleRoundEnd(roundResult);
    } else {
      setState(() => _ctrl.phase = _GamePhase.cpuTurn);
      _scheduleCpuTurn();
    }
  }

  void _scheduleCpuTurn() {
    setState(() => _isCpuThinking = true);

    final delay = widget.selectedDifficulty == 'muy fácil'
        ? 1200
        : widget.selectedDifficulty == 'difícil'
            ? 600
            : 900;

    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _makeCpuMove();
    });
  }

  void _makeCpuMove() {
    if (!mounted) return;

    final bestTile = _ctrl.getBestCpuMove();

    if (bestTile != null) {
      final side = _ctrl.getCpuPlaySide(bestTile);
      _ctrl.playTile(bestTile, side);
      _ctrl.cpuHand.remove(bestTile);

      final roundResult = _ctrl.checkRoundEnd();

      setState(() => _isCpuThinking = false);

      if (roundResult != null) {
        _handleRoundEnd(roundResult);
      } else {
        setState(() => _ctrl.phase = _GamePhase.playerTurn);
        _ctrl.startTimer();
      }
      _scrollChainToEnd();
    } else {
      if (_ctrl.boneyard.isNotEmpty && !_ctrl.canCpuPlayAny()) {
        _ctrl.drawFromBoneyard(false);
        setState(() {});
        if (!_ctrl.canCpuPlayAny()) {
          _ctrl.consecutivePasses++;
          final roundResult = _ctrl.checkRoundEnd();
          setState(() => _isCpuThinking = false);
          if (roundResult != null) {
            _handleRoundEnd(roundResult);
            return;
          }
        } else {
          _makeCpuMove();
          return;
        }
      } else {
        _ctrl.consecutivePasses++;
        final roundResult = _ctrl.checkRoundEnd();
        setState(() => _isCpuThinking = false);
        if (roundResult != null) {
          _handleRoundEnd(roundResult);
          return;
        }
      }
      setState(() {
        _isCpuThinking = false;
        _ctrl.phase = _GamePhase.playerTurn;
      });
      _ctrl.startTimer();
      _showSnack('CPU pasó. ¡Tu turno!', success: true);
    }
  }

  void _handleRoundEnd(_RoundResult result) {
    if (_ctrl.isGameOver()) {
      _handleGameOver();
      return;
    }

    String msg;
    switch (result) {
      case _RoundResult.playerWon:
        msg = '¡Ganaste la ronda!\nTú: ${_ctrl.playerScore} | CPU: ${_ctrl.cpuScore}';
        break;
      case _RoundResult.cpuWon:
        msg = 'CPU ganó la ronda\nTú: ${_ctrl.playerScore} | CPU: ${_ctrl.cpuScore}';
        break;
      case _RoundResult.blocked:
        msg = 'Ronda bloqueada\nTú: ${_ctrl.playerScore} | CPU: ${_ctrl.cpuScore}';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          result == _RoundResult.playerWon ? '🏆 Ronda ganada' : result == _RoundResult.cpuWon ? '😞 Ronda perdida' : '🤝 Bloqueado',
          textAlign: TextAlign.center,
        ),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _ctrl.startNextRound();
                  _selectedTile = null;
                  _needsSideChoice = false;
                });
                if (_ctrl.phase == _GamePhase.cpuTurn) {
                  _scheduleCpuTurn();
                } else {
                  _ctrl.startTimer();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Siguiente ronda'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleGameOver() {
    final playerWon = _ctrl.playerScore > _ctrl.cpuScore;
    _recordResult(playerWon);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          playerWon ? '🏆 ¡Ganaste!' : '😞 Juego terminado',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: playerWon ? _accentOrange : Colors.red[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Puntuación final\nTú: ${_ctrl.playerScore} | CPU: ${_ctrl.cpuScore}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Meta: ${_ctrl.targetScore} puntos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (widget.matchType == 'Apuesta' && playerWon) ...[
              const SizedBox(height: 12),
              Text(
                '+${(_getGameCost() * 2 * 0.9).floor()} 💎',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accentOrange),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Salir'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _gameEnded = false);
                    if (widget.matchType == 'Apuesta') {
                      await _loadAndDeductGameCost();
                      if (mounted) _showStartDialog();
                    } else {
                      _showStartDialog();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Nueva partida'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        if (mounted) setState(() => _userDiamonds = newDiamonds);
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
        if (mounted) setState(() => _userCoins = newCoins);
      }
    } catch (e) {
      if (kDebugMode) print('Error deducting domino game cost: $e');
    }
  }

  Future<void> _recordResult(bool playerWon) async {
    if (_currentUser == null) return;
    setState(() => _gameEnded = true);
    try {
      final isBet = widget.matchType == 'Apuesta';
      final gameCost = _getGameCost();

      if (playerWon) {
        final prize = (gameCost * 2 * 0.9).floor();
        final userData = await _firestoreService.getUser(_currentUser!.uid);
        if (userData != null && mounted) {
          if (isBet) {
            final newDiamonds = userData.diamonds + prize;
            await _firestoreService.updateUserDiamonds(_currentUser!.uid, newDiamonds);
            if (mounted) setState(() => _userDiamonds = newDiamonds);
          } else {
            final newCoins = userData.coins + prize;
            await _firestoreService.updateUserCoins(_currentUser!.uid, newCoins);
            if (mounted) setState(() => _userCoins = newCoins);
          }
        }
      }

      await _firestoreService.recordGameMatch(
        userId: _currentUser!.uid,
        gameType: GameTypeModel.domino,
        result: playerWon ? GameResultModel.win : GameResultModel.loss,
        pointsEarned: playerWon ? 20 : -5,
        durationMinutes: 10,
        opponentName: 'CPU (${widget.selectedDifficulty})',
        additionalData: {
          'playerScore': _ctrl.playerScore,
          'cpuScore': _ctrl.cpuScore,
          'matchType': widget.matchType,
          'gameCost': gameCost,
          'currencyType': isBet ? 'diamonds' : 'coins',
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error recording domino result: $e');
    }
  }

  void _scrollChainToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chainScrollCtrl.hasClients) {
        _chainScrollCtrl.animateTo(
          _chainScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBetMode = widget.matchType == 'Apuesta';
    return PopScope(
      canPop: !isBetMode || _gameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isBetMode && !_gameEnded) {
          _showSnack('No puedes salir en modo apuesta hasta terminar la partida');
        }
      },
      child: Scaffold(
        backgroundColor: _tableColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF3E2007),
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.sports_esports, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text('Dominó', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBetMode ? 'Apuesta 💎' : widget.selectedDifficulty,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_gameStarted && !isBetMode)
              TextButton(
                onPressed: _showStartDialog,
                child: const Text('Nueva', style: TextStyle(color: Colors.white70)),
              ),
          ],
        ),
        body: _gameStarted
            ? Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _WoodGrainPainter())),
                _buildGame(),
              ])
            : _buildEmpty(),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildGame() {
    return SafeArea(
      child: Column(
        children: [
          _buildScoreBar(),
          _buildCpuArea(),
          const SizedBox(height: 4),
          _buildChainArea(),
          const SizedBox(height: 4),
          _buildBoneyardBar(),
          const SizedBox(height: 4),
          _buildActionButtons(),
          _buildPlayerArea(),
          if (_needsSideChoice) _buildSideChoiceBar(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildScoreBar() {
    final isPlayerTurn = _ctrl.phase == _GamePhase.playerTurn;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildPlayerScore('CPU', _ctrl.cpuScore, !isPlayerTurn && _isCpuThinking, _buildCpuAvatar()),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Meta: ${_ctrl.targetScore}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  'Ronda ${_ctrl.roundNumber}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (_ctrl.timerActive && isPlayerTurn)
                  Text(
                    '⏱ ${_ctrl.timeLeft}s',
                    style: TextStyle(
                      color: _ctrl.timeLeft <= 10 ? Colors.red[300] : Colors.green[300],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          _buildPlayerScore('Tú', _ctrl.playerScore, isPlayerTurn, _buildUserAvatar()),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, bool isActive, Widget avatar) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive ? Border.all(color: _accentOrange, width: 1.5) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            '$score',
            style: TextStyle(
              color: isActive ? _accentOrange : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCpuAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
    );
  }

  Widget _buildUserAvatar() {
    final photoUrl = _currentUser?.photoURL;
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[600],
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
    );
  }

  Widget _buildCpuArea() {
    return Container(
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: _isCpuThinking
          ? const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('CPU pensando...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              children: List.generate(
                _ctrl.cpuHand.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildFaceDownTile(width: 28, height: 48),
                ),
              ),
            ),
    );
  }

  Widget _buildChainArea() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _ctrl.chain.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.white38, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _ctrl.phase == _GamePhase.playerTurn
                          ? 'Selecciona una ficha para comenzar'
                          : 'Turno del CPU...',
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  controller: _chainScrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildSnakeWidget(_ctrl.chain, constraints.maxWidth - 24),
                ),
              ),
      ),
    );
  }

  Widget _buildSnakeWidget(List<_PlayedTile> chain, double availW) {
    const double tW = 44.0;
    const double tH = 24.0;
    const double cW = 24.0;
    const double cH = 44.0;
    const double g = 3.0;
    const double dy = (cH - tH) / 2.0;
    const double rowStep = cH - tH;

    final items = <Widget>[];
    double curX = 0;
    double curY = 0;
    double totalH = cH;
    int dir = 1;

    for (int i = 0; i < chain.length; i++) {
      final pt = chain[i];
      final bool isLast = i == chain.length - 1;

      bool makeCorner = false;
      if (!isLast) {
        if (dir == 1) {
          makeCorner = (curX + tW + g) > (availW - cW - g);
        } else {
          makeCorner = curX < (cW + g);
        }
      }

      final bool portrait = makeCorner || pt.isDouble;
      final double w = portrait ? cW : tW;
      final double h = portrait ? cH : tH;
      final double topOff = portrait ? 0.0 : dy;

      if (makeCorner) {
        final double left = dir == 1 ? (availW - cW) : 0.0;
        items.add(Positioned(
          left: left, top: curY, width: cW, height: cH,
          child: _buildDominoTileWidget(
            left: pt.displayLeft, right: pt.displayRight,
            isPortrait: true, width: cW, height: cH,
          ),
        ));
        totalH = max(totalH, curY + cH);
        curY += rowStep;
        dir = -dir;
        curX = dir == 1 ? (cW + g) : (availW - cW - g - tW);
      } else {
        double left = curX;
        if (isLast) left = left.clamp(0.0, availW - w);
        items.add(Positioned(
          left: left, top: curY + topOff, width: w, height: h,
          child: _buildDominoTileWidget(
            left: pt.displayLeft, right: pt.displayRight,
            isPortrait: portrait, width: w, height: h,
          ),
        ));
        totalH = max(totalH, curY + topOff + h);
        curX += dir * (w + g);
      }
    }

    return SizedBox(
      width: availW,
      height: max(totalH, cH),
      child: Stack(clipBehavior: Clip.none, children: items),
    );
  }

  Widget _buildBoneyardBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2, color: Colors.white54, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Pozo: ${_ctrl.boneyard.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_ctrl.chain.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_ctrl.leftOpen ?? '-'} ← → ${_ctrl.rightOpen ?? '-'}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_ctrl.phase != _GamePhase.playerTurn) return const SizedBox.shrink();
    final canDraw = _ctrl.boneyard.isNotEmpty && !_ctrl.canPlayerPlayAny();
    final canPass = !_ctrl.canPlayerPlayAny() && _ctrl.boneyard.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          if (canDraw)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _drawFromBoneyard,
                icon: const Icon(Icons.add_box, size: 16),
                label: const Text('Tomar del pozo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          if (canPass) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _passPlayerTurn,
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('Pasar turno'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSideChoiceBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentOrange, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text('¿Dónde colocar?', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ElevatedButton(
            onPressed: () {
              setState(() => _needsSideChoice = false);
              _placeSelectedTile('left');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text('← Izquierda (${_ctrl.leftOpen})'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _needsSideChoice = false);
              _placeSelectedTile('right');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            child: Text('Derecha (${_ctrl.rightOpen}) →'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      height: 88,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: _ctrl.playerHand.map((tile) {
          final isPlayable = _ctrl.phase == _GamePhase.playerTurn && _ctrl.canPlay(tile);
          final isSelected = _selectedTile?.id == tile.id;

          return GestureDetector(
            onTap: () => _onTileTap(tile),
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDominoTileWidget(
                  left: tile.left,
                  right: tile.right,
                  isPortrait: true,
                  width: 36,
                  height: 68,
                  isPlayable: isPlayable,
                  isSelected: isSelected,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaceDownTile({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF4A3728),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 1)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              2,
              (_) => Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDominoTileWidget({
    required int left,
    required int right,
    required bool isPortrait,
    required double width,
    required double height,
    bool isPlayable = false,
    bool isSelected = false,
  }) {
    final borderColor = isSelected
        ? _accentOrange
        : isPlayable
            ? Colors.green[400]!
            : _tileBorder;
    final borderWidth = (isSelected || isPlayable) ? 2.0 : 1.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _tileColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: isPlayable ? Colors.green.withValues(alpha: 0.4) : Colors.black38,
            blurRadius: isPlayable ? 6 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: isPortrait
            ? Column(children: [
                Expanded(child: _buildPips(left)),
                Container(height: 1.5, color: _tileBorder.withValues(alpha: 0.5)),
                Expanded(child: _buildPips(right)),
              ])
            : Row(children: [
                Expanded(child: _buildPips(left)),
                Container(width: 1.5, color: _tileBorder.withValues(alpha: 0.5)),
                Expanded(child: _buildPips(right)),
              ]),
      ),
    );
  }

  Widget _buildPips(int count) {
    if (count == 0) return const SizedBox.expand();
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
      final dotSize = (side * 0.22).clamp(3.0, 7.0);
      final pad = dotSize * 0.55;
      return Stack(
        children: _pipPositions(count).map((align) => Align(
          alignment: align,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
            ),
          ),
        )).toList(),
      );
    });
  }

  List<Alignment> _pipPositions(int count) {
    switch (count) {
      case 1:
        return [Alignment.center];
      case 2:
        return [Alignment.topRight, Alignment.bottomLeft];
      case 3:
        return [Alignment.topRight, Alignment.center, Alignment.bottomLeft];
      case 4:
        return [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];
      case 5:
        return [Alignment.topLeft, Alignment.topRight, Alignment.center, Alignment.bottomLeft, Alignment.bottomRight];
      case 6:
        return [
          const Alignment(-1, -1),
          const Alignment(1, -1),
          const Alignment(-1, 0),
          const Alignment(1, 0),
          const Alignment(-1, 1),
          const Alignment(1, 1),
        ];
      default:
        return [];
    }
  }
}

class _WoodGrainPainter extends CustomPainter {
  static const _baseColors = [
    Color(0xFFDFB25A), Color(0xFFD4A84E), Color(0xFFE3B660),
    Color(0xFFCFA24A), Color(0xFFDAB058), Color(0xFFD5A850),
    Color(0xFFE0B45C), Color(0xFFCCA04C), Color(0xFFDCAE56),
    Color(0xFFD1A64E), Color(0xFFE1B25A), Color(0xFFCCA24C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const plankCount = 14;
    final rng = Random(37);
    final plankH = size.height / plankCount;

    for (int i = 0; i < plankCount; i++) {
      final top = i * plankH;
      final base = _baseColors[i % _baseColors.length];

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.white, 0.12)!,
            base,
            Color.lerp(base, Colors.black, 0.07)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, top, size.width, plankH));
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, plankH), fillPaint);

      final lineCount = 5 + rng.nextInt(5);
      for (int g = 0; g < lineCount; g++) {
        final gy = top + (g + 1) * plankH / (lineCount + 1);
        final opacity = 0.04 + rng.nextDouble() * 0.14;
        final isDark = rng.nextDouble() > 0.30;
        final grainPaint = Paint()
          ..color = isDark
              ? Color.fromARGB((opacity * 255).round(), 100, 55, 5)
              : Color.fromARGB((opacity * 0.5 * 255).round(), 255, 240, 180)
          ..strokeWidth = 0.4 + rng.nextDouble() * 1.0
          ..style = PaintingStyle.stroke;
        final amp = 0.8 + rng.nextDouble() * 2.8;
        final cx = size.width * (0.2 + rng.nextDouble() * 0.6);
        final cy = gy + (rng.nextBool() ? amp : -amp);
        final endY = gy + (rng.nextBool() ? amp * 0.5 : -amp * 0.5);
        canvas.drawPath(
          Path()..moveTo(0, gy)..quadraticBezierTo(cx, cy, size.width, endY),
          grainPaint,
        );
      }

      canvas.drawLine(
        Offset(0, top + 1.5), Offset(size.width, top + 1.5),
        Paint()..color = const Color(0x1AFFFFFF)..strokeWidth = 2.0,
      );
      if (i < plankCount - 1) {
        canvas.drawLine(
          Offset(0, top + plankH), Offset(size.width, top + plankH),
          Paint()..color = const Color(0xFF9B7030)..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WoodGrainPainter old) => false;
}
