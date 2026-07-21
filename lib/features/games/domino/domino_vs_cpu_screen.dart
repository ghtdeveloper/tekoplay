import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/domino_tile.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/widgets/domino_board_widgets.dart';
import '../../../core/widgets/domino_webview_board.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../adds/interstitial_ad_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum _GamePhase { playerTurn, cpuTurn }
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
      cpuScore += pip; 3;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _DominoController _ctrl = _DominoController();
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _gameStarted = false;
  late InterstitialAdHelper _adHelper;

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

  late AnimationController _cpuTileAnimCtrl;
  late AnimationController _playerTileAnimCtrl;

  DominoTile? _selectedTile;
  bool _needsSideChoice = false;
  bool _isCpuThinking = false;
  bool _gameEnded = false;
  bool _isScreenKeepOnActive = false;
  bool _showRoundEndBanner = false;
  bool _showGameOverBanner = false;
  _RoundResult? _roundEndResultType;
  List<DominoTile> _revealedCpuHand = [];

  static const Color _panelColor   = Color(0xEE0D2010);

  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakeLock();

    _cpuTileAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _playerTileAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _adHelper = InterstitialAdHelper(showFrequency: 3);

    _ctrl.onTimeUpdate = () {
      if (mounted) setState(() {});
    };
    _ctrl.onTimeOut = _handleTimeOut;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    DominoSpriteSheet.preload().then((_) { if (mounted) setState(() {}); });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAndDeductGameCost();
      if (mounted) _showStartDialog();
    });
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isScreenKeepOnActive) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
    }
  }

  Future<void> _enableWakeLock() async {
    await WakelockPlus.enable();
    if (mounted) setState(() => _isScreenKeepOnActive = true);
  }

  Future<void> _disableWakeLock() async {
    await WakelockPlus.disable();
    if (mounted) setState(() => _isScreenKeepOnActive = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakeLock();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
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
      if (_ctrl.canPlayerPlayAny()) {
        _autoPlayForPlayer();
      } else if (_ctrl.boneyard.isNotEmpty) {
        _drawFromBoneyard();
        _ctrl.startTimer();
      } else {
        _passPlayerTurn();
      }
    }
  }

  void _autoPlayForPlayer() {
    final playable = _ctrl.playerHand.where(_ctrl.canPlay).toList();
    if (playable.isEmpty) { _passPlayerTurn(); return; }
    playable.sort((a, b) => b.total.compareTo(a.total));
    final tile = playable.first;
    setState(() => _selectedTile = tile);
    final side = _ctrl.getCpuPlaySide(tile);
    _placeSelectedTile(side);
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

    final canRight = tile.canConnectTo(_ctrl.rightOpen!);
    final canLeft = tile.canConnectTo(_ctrl.leftOpen!);

    if (canLeft && canRight) {
      setState(() => _needsSideChoice = true);
      return;
    }

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
    setState(() {
      _showRoundEndBanner = true;
      _roundEndResultType = result;
      _revealedCpuHand = List.from(_ctrl.cpuHand);
    });
  }

  void _handleGameOver() {
    final playerWon = _ctrl.playerScore > _ctrl.cpuScore;
    _recordResult(playerWon);
    setState(() => _showGameOverBanner = true);
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
          } else {
            final newCoins = userData.coins + prize;
            await _firestoreService.updateUserCoins(_currentUser!.uid, newCoins);
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
        backgroundColor: const Color(0xFF347A2A),
        appBar: AppBar(
          backgroundColor: _accentOrange,
          toolbarHeight: 44,
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
        body: _gameStarted ? _buildGame() : _buildEmpty(),
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
      child: Stack(
        children: [
          Column(
            children: [
              _buildLandscapeHeader(),
              _buildChainArea(),
              _buildLandscapeFooter(),
            ],
          ),
          if (_showRoundEndBanner) _buildRoundEndOverlay(),
          if (_showGameOverBanner) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  Widget _buildRoundEndOverlay() {
    final result = _roundEndResultType!;
    final bool playerWon = result == _RoundResult.playerWon;
    final bool blocked = result == _RoundResult.blocked;
    final Color titleColor = playerWon ? _accentOrange : blocked ? Colors.amber[600]! : Colors.red[400]!;
    final String title = playerWon ? 'Ronda ganada' : blocked ? 'Bloqueado' : 'Ronda perdida';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20D2010),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tú: ${_ctrl.playerScore}  |  CPU: ${_ctrl.cpuScore}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (_revealedCpuHand.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.smart_toy, color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Fichas del CPU (${_revealedCpuHand.length} — ${_revealedCpuHand.fold(0, (s, t) => s + t.total)} puntos)',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _revealedCpuHand.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: DominoTileWidget(left: t.left, right: t.right, width: 28, height: 52),
                  )).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showRoundEndBanner = false;
                    _roundEndResultType = null;
                    _revealedCpuHand = [];
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Siguiente ronda', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final bool playerWon = _ctrl.playerScore > _ctrl.cpuScore;
    final Color titleColor = playerWon ? _accentOrange : Colors.red[400]!;
    final String title = playerWon ? '🏆 ¡Ganaste!' : '😞 Juego terminado';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20D2010),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tú: ${_ctrl.playerScore}  |  CPU: ${_ctrl.cpuScore}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              'Meta: ${_ctrl.targetScore} puntos',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            if (widget.matchType == 'Apuesta' && playerWon) ...[
              const SizedBox(height: 8),
              Text(
                '+${(_getGameCost() * 2 * 0.9).floor()} 💎',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accentOrange),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showGameOverBanner = false);
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Salir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _showGameOverBanner = false;
                        _gameEnded = false;
                      });
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Nueva partida', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeHeader() {
    final bool isPlayerTurn = _ctrl.phase == _GamePhase.playerTurn;
    final bool cpuHasOpening = _ctrl.chain.isEmpty &&
        _ctrl.openingDoubleValue != -1 &&
        _ctrl.phase == _GamePhase.cpuTurn;

    return AnimatedBuilder(
      animation: _cpuTileAnimCtrl,
      builder: (context, _) => Container(
        height: 52,
        color: _panelColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            // Round + timer info
            SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ronda ${_ctrl.roundNumber}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('Meta: ${_ctrl.targetScore}',
                      style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  if (_ctrl.timerActive && isPlayerTurn)
                    Text('⏱ ${_ctrl.timeLeft}s',
                        style: TextStyle(
                          color: _ctrl.timeLeft <= 10 ? Colors.red[300] : Colors.green[300],
                          fontSize: 10, fontWeight: FontWeight.bold,
                        )),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildCompactScore('CPU', _ctrl.cpuScore, !isPlayerTurn, _buildCpuAvatar()),
            const SizedBox(width: 4),
            Expanded(
              child: _isCpuThinking
                  ? const Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                        SizedBox(width: 4),
                        Text('CPU pensando...', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ]))
                  : cpuHasOpening
                      ? Center(
                          child: Text(
                            'CPU sale con ${_ctrl.openingDoubleValue}-${_ctrl.openingDoubleValue}',
                            style: TextStyle(color: Colors.amber[300], fontSize: 10, fontWeight: FontWeight.bold),
                          ))
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          children: List.generate(
                            _ctrl.cpuHand.length,
                            (_) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _buildFaceDownTile(width: 16, height: 30),
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 4),
            _buildCompactScore('Tú', _ctrl.playerScore, isPlayerTurn, _buildUserAvatar()),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactScore(String name, int score, bool isActive, Widget avatar) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: _accentOrange, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white60, fontSize: 9)),
              Text('$score',
                  style: TextStyle(
                    color: isActive ? _accentOrange : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeFooter() {
    final bool isPlayerTurn = _ctrl.phase == _GamePhase.playerTurn;
    final bool canDraw = isPlayerTurn && _ctrl.boneyard.isNotEmpty && !_ctrl.canPlayerPlayAny();
    final bool canPass = isPlayerTurn && !_ctrl.canPlayerPlayAny() && _ctrl.boneyard.isEmpty;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB8844A), Color(0xFF8B5C28), Color(0xFF6E4318)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, -3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoChip('Pozo: ${_ctrl.boneyard.length}'),
                const SizedBox(height: 3),
                if (_ctrl.chain.isNotEmpty)
                  _infoChip('${_ctrl.leftOpen ?? '-'} ↔ ${_ctrl.rightOpen ?? '-'}'),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildPlayerArea()),
          if (canDraw || canPass) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canDraw)
                    _actionBtn('Tomar', Icons.add_box, Colors.blue[700]!, _drawFromBoneyard),
                  if (canPass)
                    _actionBtn('Pasar', Icons.skip_next, Colors.orange[700]!, _passPlayerTurn),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      );

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 13),
          label: Text(label, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _buildCpuAvatar() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.smart_toy, color: Colors.white, size: 14),
    );
  }

  Widget _buildUserAvatar() {
    final photoUrl = _currentUser?.photoURL;
    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.grey[600],
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null,
    );
  }

  Widget _buildChainArea() {
    return Expanded(
      child: Container(
        color: const Color(0xFF429936),
        child: _ctrl.chain.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white38, size: 32),
                    const SizedBox(height: 6),
                    Text(
                      _ctrl.phase == _GamePhase.playerTurn
                          ? 'Selecciona una ficha para comenzar'
                          : 'Turno del CPU...',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              )
            : DominoBoardWebView(
                tiles: _ctrl.chain
                    .map((t) => DominoChainEntry(left: t.displayLeft, right: t.displayRight))
                    .toList(),
                showEndpointHints: _needsSideChoice,
                leftOpen: _ctrl.leftOpen ?? 0,
                rightOpen: _ctrl.rightOpen ?? 0,
                onLeftTapped: _needsSideChoice ? () {
                  setState(() => _needsSideChoice = false);
                  _placeSelectedTile('left');
                } : null,
                onRightTapped: _needsSideChoice ? () {
                  setState(() => _needsSideChoice = false);
                  _placeSelectedTile('right');
                } : null,
              ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    final bool isOpeningMove = _ctrl.chain.isEmpty &&
        _ctrl.openingDoubleValue != -1 &&
        _ctrl.phase == _GamePhase.playerTurn;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF8B5E3C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentOrange, width: 1.5),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        dragStartBehavior: DragStartBehavior.down,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        children: _ctrl.playerHand.map((tile) {
          final isPlayable = _ctrl.phase == _GamePhase.playerTurn && _ctrl.canPlay(tile);
          final isSelected = _selectedTile?.id == tile.id;
          final bool isMandatory = isOpeningMove &&
              tile.isDouble && tile.left == _ctrl.openingDoubleValue;

          final Widget tileWidget = GestureDetector(
            onTap: () => _onTileTap(tile),
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: DominoTileWidget(
                  left: tile.left,
                  right: tile.right,
                  width: 24,
                  height: 44,
                  isPlayable: isPlayable,
                  isSelected: isSelected,
                  isMandatory: isMandatory,
                ),
              ),
            ),
          );

          if (!isMandatory) return tileWidget;

          return AnimatedBuilder(
            animation: _playerTileAnimCtrl,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: _playerTileAnimCtrl.value * 0.8),
                    blurRadius: 18 * _playerTileAnimCtrl.value,
                    spreadRadius: 5 * _playerTileAnimCtrl.value,
                  ),
                ],
              ),
              child: child,
            ),
            child: tileWidget,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaceDownTile({required double width, required double height}) {
    return DominoTileWidget(left: 0, right: 0, width: width, height: height, faceDown: true);
  }

}

