import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/domino_game_match.dart';
import '../../../core/service/bot_name_service.dart';
import '../../../core/service/domino_game_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/widgets/domino_board_widgets.dart';
import '../../../core/widgets/domino_webview_board.dart';
import '../../adds/banner_ad_widget.dart';

enum _FriendDominoState { setup, waitingRoom, gameActive }

class MultiplayerDominoScreen extends StatefulWidget {
  final String? gameId;
  final int playerNumber;
  final String matchType;

  const MultiplayerDominoScreen({
    super.key,
    this.gameId,
    this.playerNumber = 1,
    required this.matchType,
  });

  @override
  State<MultiplayerDominoScreen> createState() => _MultiplayerDominoScreenState();
}

class _MultiplayerDominoScreenState extends State<MultiplayerDominoScreen>
    with WidgetsBindingObserver {
  final DominoGameService _gameService = DominoGameService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  _FriendDominoState _screenState = _FriendDominoState.setup;
  int _myPlayerNumber = 1;
  int _selectedPlayerCount = 2;
  String? _activeGameId;
  int? _selectedBetAmount;
  String _currencyType = 'coins';

  static const List<int> _betOptions = [10, 25, 50, 100, 250, 500, 1000];

  DominoGameMatch? _currentGame;
  StreamSubscription<DominoGameMatch?>? _gameSubscription;
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;
  StreamSubscription<DominoGameMatch?>? _waitingSubscription;

  String? _myName;
  String? _myPhotoUrl;
  int? _userCoins;
  int? _userDiamonds;

  String? _selectedTileId;
  bool _needsSideChoice = false;
  bool _gameEnded = false;
  bool _isScreenKeepOnActive = false;
  final ScrollController _chainScrollCtrl = ScrollController();

  Timer? _turnTimer;
  int _turnSecondsLeft = 60;
  bool _isJoining = false;
  bool _isPlayingVsBot = false;
  bool _isOpponentThinking = false;
  String _botName = 'Bot';
  Timer? _botMoveTimer;
  Timer? _waitingTimer;
  int _waitingSeconds = 0;
  final TextEditingController _roomCodeCtrl = TextEditingController();

  static const Color _panelColor   = Color(0xEE0D2010);

  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();
    DominoSpriteSheet.preload().then((_) { if (mounted) setState(() {}); });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addObserver(this);
    _currencyType = widget.matchType == 'Apuesta' ? 'diamonds' : 'coins';
    if (widget.matchType != 'Apuesta') _selectedBetAmount = 100;
    _loadUserData();

    if (widget.gameId != null) {
      _myPlayerNumber = widget.playerNumber;
      _joinExistingGame(widget.gameId!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isScreenKeepOnActive) {
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    try {
      final userData = await _firestoreService.getUser(_currentUser!.uid);
      if (mounted && userData != null) {
        setState(() {
          _myName = userData.name;
          _myPhotoUrl = userData.urlPhoto;
        });
      }
      _setupBalanceListener();
    } catch (e) {
      if (kDebugMode) print('Error loading user: $e');
    }
  }

  void _setupBalanceListener() {
    if (_currentUser == null) return;
    _balanceSubscription?.cancel();
    _balanceSubscription = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      setState(() {
        _userCoins = d['coins'] ?? 0;
        _userDiamonds = d['diamonds'] ?? 0;
      });
    });
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      if (mounted) setState(() => _isScreenKeepOnActive = true);
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      if (mounted) setState(() => _isScreenKeepOnActive = false);
    } catch (_) {}
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _waitingSubscription?.cancel();
    _botMoveTimer?.cancel();
    _waitingTimer?.cancel();
    _turnTimer?.cancel();
    _chainScrollCtrl.dispose();
    _roomCodeCtrl.dispose();
    _disableWakeLock();
    super.dispose();
  }

  Future<void> _createGame() async {
    if (_currentUser == null) return;
    if (widget.matchType == 'Apuesta' && _selectedBetAmount == null) return;

    final balance = _currencyType == 'diamonds' ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final cost = _selectedBetAmount ?? 0;
    if (cost > 0 && balance < cost) {
      _showSnack('Fondos insuficientes');
      return;
    }

    final result = await _gameService.createGame(
      hostId: _currentUser!.uid,
      hostName: _myName ?? 'Jugador',
      hostPhotoUrl: _myPhotoUrl,
      currencyType: _currencyType,
      betAmount: _selectedBetAmount,
      isOnlineMatchmaking: false,
      numberOfPlayers: _selectedPlayerCount,
    );

    if (result == null || !mounted) return;

    setState(() {
      _activeGameId = result['gameId'];
      _myPlayerNumber = 1;
      _screenState = _FriendDominoState.waitingRoom;
    });

    await _enableWakeLock();

    _waitingSeconds = 0;
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _waitingSeconds++);
      // Bot fallback only for 2-player games
      if (_waitingSeconds >= 120 && _selectedPlayerCount == 2) {
        t.cancel();
        _startBotFallback(result['gameId']!);
      }
    });

    _waitingSubscription?.cancel();
    _waitingSubscription = _gameService.getGameStream(result['gameId']!).listen((game) {
      if (!mounted) return;
      if (game == null) return;
      setState(() => _currentGame = game);
      if (game.isActive) {
        _waitingTimer?.cancel();
        _waitingSubscription?.cancel();
        _startGame(result['gameId']!, 1);
      }
    });
  }

  Future<void> _startBotFallback(String gameId) async {
    if (!mounted) return;
    _waitingSubscription?.cancel();
    await _gameService.addBotAndStart(gameId);
    final profile = await BotNameService.pickUnseenProfile(_random);
    if (!mounted) return;
    setState(() {
      _isPlayingVsBot = true;
      _botName = profile['name'] ?? 'Bot';
    });
    _startGame(gameId, 1);
  }

  Future<void> _joinByCode() async {
    final code = _roomCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack('Ingresa el código de sala');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final doc = await _firestore.collection('domino_games').doc(code).get();
      if (!doc.exists) {
        _showSnack('Sala no encontrada');
        setState(() => _isJoining = false);
        return;
      }

      final game = DominoGameMatch.fromFirestore(doc);
      if (game.status != 'waiting') {
        _showSnack('La sala ya está en uso o cerrada');
        setState(() => _isJoining = false);
        return;
      }

      if (game.hostId == _currentUser!.uid) {
        _showSnack('No puedes unirte a tu propia sala');
        setState(() => _isJoining = false);
        return;
      }

      final joined = await _gameService.joinGame(
        gameId: code,
        guestId: _currentUser!.uid,
        guestName: _myName ?? 'Jugador',
        guestPhotoUrl: _myPhotoUrl,
      );

      if (!joined || !mounted) {
        _showSnack('No se pudo unir a la sala');
        setState(() => _isJoining = false);
        return;
      }

      _startGame(code, 2);
    } catch (e) {
      if (kDebugMode) print('Error joining by code: $e');
      _showSnack('Error al unirse');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _joinExistingGame(String gameId) {
    _startGame(gameId, widget.playerNumber);
  }

  void _startGame(String gameId, int playerNumber) {
    setState(() {
      _activeGameId = gameId;
      _myPlayerNumber = playerNumber;
      _screenState = _FriendDominoState.gameActive;
      _gameEnded = false;
      _selectedTileId = null;
      _needsSideChoice = false;
    });

    _enableWakeLock();

    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted) return;
      setState(() => _currentGame = game);

      if (game == null || _gameEnded) return;

      if (game.isFinished || game.isAbandoned) {
        _stopTurnTimer();
        setState(() => _gameEnded = true);
        _disableWakeLock();
        _showGameOverDialog(game);
        return;
      }

      final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
      if (isMyTurn) {
        _startTurnTimer();
      } else {
        _stopTurnTimer();
        if (_isOpponent(game)) _scheduleOpponentTurn(game);
      }
    });
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    _turnSecondsLeft = 30;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _turnSecondsLeft--);
      if (_turnSecondsLeft <= 0) {
        t.cancel();
        _autoPlayOrPass();
      }
    });
  }

  void _stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  Future<void> _autoPlayOrPass() async {
    if (_activeGameId == null || _gameEnded) return;
    final game = _currentGame;
    if (game == null) return;
    final myHand = game.getHand(_myPlayerNumber);
    final state = game.gameState;
    final playable = myHand.where((id) => state.canPlay(id)).toList();
    if (playable.isNotEmpty) {
      playable.shuffle(_random);
      final tileId = playable.first;
      final tileData = state.tiles[tileId]!;
      String side;
      if (state.chain.isEmpty) {
        side = 'right';
      } else {
        final canLeft = tileData['left'] == state.leftOpen || tileData['right'] == state.leftOpen;
        side = canLeft ? 'left' : 'right';
      }
      final newDeal = DominoGameState.initialDeal(_random);
      await _gameService.playTile(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
        tileId: tileId,
        side: side,
        newRoundDeal: newDeal,
      );
    } else if (state.boneyard.isNotEmpty) {
      await _gameService.drawFromBoneyard(gameId: _activeGameId!, playerId: _currentUser!.uid);
    } else {
      final newDeal = DominoGameState.initialDeal(_random);
      await _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
        newRoundDeal: newDeal,
      );
    }
  }

  bool _isOpponent(DominoGameMatch game) {
    if (!_isPlayingVsBot) return false;
    final opponentId = _myPlayerNumber == 1 ? game.guestId : game.hostId;
    return opponentId?.startsWith('bot_') == true;
  }

  void _scheduleOpponentTurn(DominoGameMatch game) {
    if (_isOpponentThinking) return;
    setState(() => _isOpponentThinking = true);
    _botMoveTimer?.cancel();
    _botMoveTimer = Timer(Duration(milliseconds: 800 + _random.nextInt(600)), () {
      if (!mounted) return;
      _makeBotMove(game);
    });
  }

  void _makeBotMove(DominoGameMatch game) {
    if (!mounted) return;
    final botNum = _myPlayerNumber == 1 ? 2 : 1;
    final botHand = game.getHand(botNum);
    final state = game.gameState;

    final playable = botHand.where((id) => state.canPlay(id)).toList();

    if (playable.isNotEmpty) {
      playable.shuffle(_random);
      final tileId = playable.first;
      final tileData = state.tiles[tileId]!;
      String side;
      if (state.chain.isEmpty) {
        side = 'right';
      } else {
        final canLeft = tileData['left'] == state.leftOpen || tileData['right'] == state.leftOpen;
        side = canLeft ? 'left' : 'right';
      }
      final newDeal = DominoGameState.initialDeal(_random);
      _gameService.playTile(
        gameId: _activeGameId!,
        playerId: botNum == 1 ? game.hostId : (game.guestId ?? ''),
        tileId: tileId,
        side: side,
        newRoundDeal: newDeal,
      ).then((_) {
        if (mounted) setState(() => _isOpponentThinking = false);
      });
    } else if (state.boneyard.isNotEmpty) {
      final botId = botNum == 1 ? game.hostId : (game.guestId ?? '');
      _gameService.drawFromBoneyard(gameId: _activeGameId!, playerId: botId).then((_) {
        if (mounted) {
          setState(() => _isOpponentThinking = false);
          final updated = _currentGame;
          if (updated != null && !updated.isPlayerTurn(_currentUser!.uid)) {
            _scheduleOpponentTurn(updated);
          }
        }
      });
    } else {
      final botId = botNum == 1 ? game.hostId : (game.guestId ?? '');
      final newDeal = DominoGameState.initialDeal(_random);
      _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: botId,
        newRoundDeal: newDeal,
      ).then((_) {
        if (mounted) setState(() => _isOpponentThinking = false);
      });
    }
  }

  void _onTileTap(String tileId) {
    final game = _currentGame;
    if (game == null || !game.isPlayerTurn(_currentUser!.uid)) return;

    final state = game.gameState;
    if (!state.canPlay(tileId)) {
      _showSnack('Esta ficha no conecta con los extremos');
      return;
    }

    final tileData = state.tiles[tileId]!;
    setState(() => _selectedTileId = tileId);

    if (state.chain.isEmpty) {
      _placeSelectedTile(tileId, 'right');
      return;
    }

    final canLeft = tileData['left'] == state.leftOpen || tileData['right'] == state.leftOpen;
    final canRight = tileData['left'] == state.rightOpen || tileData['right'] == state.rightOpen;

    if (canLeft && canRight && state.leftOpen != state.rightOpen) {
      setState(() => _needsSideChoice = true);
    } else {
      _placeSelectedTile(tileId, canLeft ? 'left' : 'right');
    }
  }

  void _placeSelectedTile(String tileId, String side) async {
    final prevGame = _currentGame;
    if (prevGame == null) return;

    setState(() {
      _selectedTileId = null;
      _needsSideChoice = false;
    });

    final optimistic = _applyTileLocally(prevGame, tileId, side);
    if (optimistic != null) {
      setState(() => _currentGame = optimistic);
      _scrollChainToEnd();
    }

    final newDeal = DominoGameState.initialDeal(_random);
    final ok = await _gameService.playTile(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
      tileId: tileId,
      side: side,
      newRoundDeal: newDeal,
    );

    if (!ok && mounted) {
      setState(() => _currentGame = prevGame);
      _showSnack('No se pudo jugar la ficha');
    }
  }

  DominoGameMatch? _applyTileLocally(DominoGameMatch game, String tileId, String side) {
    final playerNum = game.getPlayerNumber(_currentUser!.uid);
    final tileData = game.gameState.tiles[tileId];
    if (tileData == null) return null;

    final tl = tileData['left']!;
    final tr = tileData['right']!;
    final isDouble = tl == tr;
    final chain = List<DominoChainTile>.from(game.gameState.chain);
    int? newLeftOpen = game.gameState.leftOpen;
    int? newRightOpen = game.gameState.rightOpen;
    int displayLeft, displayRight;

    if (chain.isEmpty) {
      displayLeft = tl; displayRight = tr;
      newLeftOpen = tl; newRightOpen = tr;
    } else if (side == 'left') {
      if (tr == newLeftOpen) { displayLeft = tl; displayRight = tr; newLeftOpen = tl; }
      else { displayLeft = tr; displayRight = tl; newLeftOpen = tr; }
      if (isDouble) newLeftOpen = tl;
    } else {
      if (tl == newRightOpen) { displayLeft = tl; displayRight = tr; newRightOpen = tr; }
      else { displayLeft = tr; displayRight = tl; newRightOpen = tl; }
      if (isDouble) newRightOpen = tr;
    }

    final placement = DominoChainTile(id: tileId, displayLeft: displayLeft, displayRight: displayRight);
    if (side == 'left') {
      chain.insert(0, placement);
    } else {
      chain.add(placement);
    }

    final hands = <int, List<String>>{};
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      hands[p] = List<String>.from(game.gameState.handOf(p));
    }
    hands[playerNum]!.remove(tileId);

    final newState = DominoGameState(
      chain: chain,
      leftOpen: newLeftOpen,
      rightOpen: newRightOpen,
      player1Hand: hands[1] ?? [],
      player2Hand: hands[2] ?? [],
      player3Hand: game.numberOfPlayers >= 3 ? (hands[3] ?? []) : game.gameState.player3Hand,
      player4Hand: game.numberOfPlayers >= 4 ? (hands[4] ?? []) : game.gameState.player4Hand,
      boneyard: game.gameState.boneyard,
      tiles: game.gameState.tiles,
      player1Score: game.gameState.player1Score,
      player2Score: game.gameState.player2Score,
      player3Score: game.gameState.player3Score,
      player4Score: game.gameState.player4Score,
      roundNumber: game.gameState.roundNumber,
      consecutivePasses: 0,
    );

    return DominoGameMatch(
      id: game.id,
      gameType: game.gameType,
      hostId: game.hostId,
      guestId: game.guestId,
      guest2Id: game.guest2Id,
      guest3Id: game.guest3Id,
      hostName: game.hostName,
      guestName: game.guestName,
      guest2Name: game.guest2Name,
      guest3Name: game.guest3Name,
      hostPhotoUrl: game.hostPhotoUrl,
      guestPhotoUrl: game.guestPhotoUrl,
      status: game.status,
      currentTurn: game.nextTurnAfter(game.currentTurn),
      gameState: newState,
      createdAt: game.createdAt,
      startedAt: game.startedAt,
      finishedAt: game.finishedAt,
      winnerId: game.winnerId,
      reason: game.reason,
      isRanked: game.isRanked,
      betAmount: game.betAmount,
      currencyType: game.currencyType,
      quotasCollected: game.quotasCollected,
      rewardsDistributed: game.rewardsDistributed,
      hostQuota: game.hostQuota,
      guestQuota: game.guestQuota,
      totalPot: game.totalPot,
      gameSettings: game.gameSettings,
      targetScore: game.targetScore,
      numberOfPlayers: game.numberOfPlayers,
    );
  }

  Future<void> _drawFromBoneyard() async {
    final game = _currentGame;
    if (game == null || !game.isPlayerTurn(_currentUser!.uid)) return;
    final state = game.gameState;
    final myHand = game.getHand(_myPlayerNumber);
    if (state.canPlayAny(myHand)) {
      _showSnack('Tienes fichas jugables');
      return;
    }
    if (state.boneyard.isEmpty) {
      _showSnack('El pozo está vacío');
      return;
    }
    await _gameService.drawFromBoneyard(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
    );
  }

  Future<void> _passTurn() async {
    final newDeal = DominoGameState.initialDeal(_random);
    await _gameService.passTurn(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
      newRoundDeal: newDeal,
    );
  }

  Future<void> _abandonGame() async {
    if (_gameEnded) { Navigator.of(context).pop(); return; }
    final isBet = widget.matchType == 'Apuesta';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Abandonar partida?'),
        content: Text(isBet ? 'Perderás la apuesta si abandonas.' : 'Se cerrará la partida en curso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Abandonar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && _activeGameId != null && mounted) {
      await _gameService.abandonGame(gameId: _activeGameId!, playerId: _currentUser!.uid);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showGameOverDialog(DominoGameMatch game) {
    if (!mounted) return;
    final iWon = game.winnerId == _currentUser!.uid;
    final scores = game.getPlayerScores();
    final scoreLines = StringBuffer();
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      final name = p == _myPlayerNumber ? 'Tú' : (_isPlayingVsBot && p != 1 ? _botName : game.playerNameOf(p));
      scoreLines.write('$name: ${scores['player$p'] ?? 0}');
      if (p < game.numberOfPlayers) scoreLines.write(' | ');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text(
          iWon ? '🏆 ¡Ganaste!' : '😞 Perdiste',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: iWon ? _accentOrange : Colors.red[700],
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              scoreLines.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if ((game.betAmount ?? 0) > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iWon ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  iWon
                      ? '+${game.betAmount! + (game.betAmount! * 0.7).ceil()} ${game.currencyType}'
                      : '-${game.betAmount} ${game.currencyType}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iWon ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Salir', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
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

  String _playerCountIcon(int n) {
    switch (n) {
      case 2: return '👥';
      case 3: return '👥+';
      case 4: return '👨‍👩‍👧‍👦';
      default: return '👥';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1500),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final inGame = _screenState == _FriendDominoState.gameActive;
    return PopScope(
      canPop: !inGame || _gameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inGame && !_gameEnded) _abandonGame();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF347A2A),
        appBar: AppBar(
          backgroundColor: _accentOrange,
          elevation: 0,
          title: const Text('Dominó - Amigos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (inGame)
              TextButton(
                onPressed: _abandonGame,
                child: Text('Salir', style: TextStyle(color: Colors.red[300])),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case _FriendDominoState.setup:
        return _buildSetup();
      case _FriendDominoState.waitingRoom:
        return _buildWaitingRoom();
      case _FriendDominoState.gameActive:
        return _buildGame();
    }
  }

  Widget _buildSetup() {
    final isBet = widget.matchType == 'Apuesta';
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final currencyIcon = isBet ? Icons.diamond : Icons.monetization_on;
    final currencyColor = isBet ? Colors.blue[300]! : Colors.amber[300]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 40),
                const SizedBox(height: 12),
                const Text('Jugar con Amigos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  widget.matchType == 'Apuesta' ? 'Modo Apuesta' : 'Modo Diversión',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(currencyIcon, color: currencyColor, size: 18),
                    const SizedBox(width: 6),
                    Text('Balance: $balance', style: TextStyle(color: currencyColor, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('¿Cuántos jugadores?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final sel = _selectedPlayerCount == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlayerCount = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80, height: 90,
                    decoration: BoxDecoration(
                      color: sel ? _accentOrange : _panelColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? _accentOrange : Colors.white24, width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: _accentOrange.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_playerCountIcon(n), style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text('$n jugadores', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.white70), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (isBet) ...[
            const Text('Monto de apuesta', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _betOptions.map((amount) {
                final isSelected = _selectedBetAmount == amount;
                final canAfford = balance >= amount;
                return GestureDetector(
                  onTap: canAfford ? () => setState(() => _selectedBetAmount = amount) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentOrange : canAfford ? _panelColor : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _accentOrange : canAfford ? Colors.white24 : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currencyIcon, size: 13, color: canAfford ? currencyColor : Colors.white24),
                        const SizedBox(width: 4),
                        Text(
                          '$amount',
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton.icon(
            onPressed: (isBet && _selectedBetAmount == null) ? null : _createGame,
            icon: const Icon(Icons.add),
            label: const Text('Crear sala', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentOrange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o únete con código', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _roomCodeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Código de sala (ID)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: _panelColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accentOrange),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isJoining ? null : _joinByCode,
            icon: _isJoining
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login),
            label: Text(_isJoining ? 'Uniéndose...' : 'Unirse a sala', style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom() {
    final gameId = _activeGameId ?? '';
    final joined = _currentGame?.currentPlayerCount ?? 1;
    final remaining = _selectedPlayerCount - joined;
    final countdown = (120 - _waitingSeconds).clamp(0, 120);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text('🁣', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text('Sala de espera',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$joined / $_selectedPlayerCount jugadores',
                      style: const TextStyle(fontSize: 16, color: Color(0xFFEC7A34), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: joined / _selectedPlayerCount,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFFEC7A34),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Room code
                  const Text('Comparte el código con tu amigo:',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: gameId));
                      _showSnack('Código copiado');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEC7A34), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            gameId.length > 16 ? '${gameId.substring(0, 16)}...' : gameId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy, color: Color(0xFFEC7A34), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (remaining > 0) ...[
                    const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFEC7A34))),
                    const SizedBox(height: 6),
                    Text('Esperando $remaining ${remaining == 1 ? 'jugador más' : 'jugadores más'}...',
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      'Expira en $countdown"',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _waitingSeconds >= 100 ? FontWeight.bold : FontWeight.normal,
                        color: _waitingSeconds >= 100 ? Colors.orange.shade700 : Colors.black45,
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const Text('¡Todos listos! Iniciando...',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                _waitingTimer?.cancel();
                _waitingSubscription?.cancel();
                if (_activeGameId != null) {
                  await _gameService.abandonGame(gameId: _activeGameId!, playerId: _currentUser!.uid);
                }
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final game = _currentGame;
    if (game == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final myHand = game.getHand(_myPlayerNumber);
    final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
    final scores = game.getPlayerScores();
    final myScore = scores['player$_myPlayerNumber'] ?? 0;
    final state = game.gameState;
    final canDraw = state.boneyard.isNotEmpty && !state.canPlayAny(myHand);
    final canPass = !state.canPlayAny(myHand) && state.boneyard.isEmpty;

    final opponents = <({int playerNum, String name, int handCount, int score, bool isActive})>[];
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      if (p == _myPlayerNumber) continue;
      opponents.add((
        playerNum: p,
        name: _isPlayingVsBot ? _botName : game.playerNameOf(p),
        handCount: game.gameState.handOf(p).length,
        score: scores['player$p'] ?? 0,
        isActive: game.currentTurn == 'player$p',
      ));
    }

    return SafeArea(
      child: Column(
        children: [
          _buildLandscapeHeader(
            opponents: opponents,
            myScore: myScore,
            isMyTurn: isMyTurn,
            targetScore: game.targetScore,
            roundNumber: state.roundNumber,
          ),
          _buildChainArea(state),
          _buildLandscapeFooter(
            hand: myHand,
            state: state,
            isMyTurn: isMyTurn,
            canDraw: canDraw,
            canPass: canPass,
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeHeader({
    required List<({int playerNum, String name, int handCount, int score, bool isActive})> opponents,
    required int myScore,
    required bool isMyTurn,
    required int targetScore,
    required int roundNumber,
  }) {
    return Container(
      height: 72,
      color: _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ronda $roundNumber', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('Meta: $targetScore', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                if (isMyTurn && _turnTimer != null)
                  Text('⏱ $_turnSecondsLeft"',
                      style: TextStyle(color: _turnSecondsLeft <= 10 ? Colors.red[300] : Colors.green[300], fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: opponents.map((opp) => Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: opp.isActive ? Colors.white12 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: opp.isActive ? Border.all(color: _accentOrange, width: 1.5) : null,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_outline, color: Colors.white54, size: 18),
                        Text(opp.name, style: const TextStyle(color: Colors.white60, fontSize: 9), overflow: TextOverflow.ellipsis),
                        Text('${opp.score}', style: TextStyle(color: opp.isActive ? _accentOrange : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: List.generate(opp.handCount, (_) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildFaceDown(width: 20, height: 38),
                        )),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.white12 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isMyTurn ? Border.all(color: _accentOrange, width: 1.5) : null,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person, color: Colors.white70, size: 18),
              const Text('Tú', style: TextStyle(color: Colors.white60, fontSize: 9)),
              Text('$myScore', style: TextStyle(color: isMyTurn ? _accentOrange : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeFooter({
    required List<String> hand,
    required DominoGameState state,
    required bool isMyTurn,
    required bool canDraw,
    required bool canPass,
  }) {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB8844A), Color(0xFF8B5C28), Color(0xFF6E4318)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, -3))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mpInfoChip('Pozo: ${state.boneyard.length}'),
                const SizedBox(height: 3),
                if (state.chain.isNotEmpty) _mpInfoChip('${state.leftOpen ?? '-'} ↔ ${state.rightOpen ?? '-'}'),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildPlayerArea(hand, state, isMyTurn)),
          if (isMyTurn && (canDraw || canPass)) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canDraw) _mpActionBtn('Tomar', Icons.add_box, Colors.blue[700]!, _drawFromBoneyard),
                  if (canPass) _mpActionBtn('Pasar', Icons.skip_next, Colors.orange[700]!, _passTurn),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mpInfoChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      );

  Widget _mpActionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 13),
          label: Text(label, style: const TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _buildChainArea(DominoGameState state) {
    final showHints = _needsSideChoice && _selectedTileId != null;
    return Expanded(
      child: Container(
        color: const Color(0xFF429936),
        child: DominoBoardWebView(
          tiles: state.chain
              .map<DominoChainEntry>((t) => DominoChainEntry(left: t.displayLeft, right: t.displayRight))
              .toList(),
          showEndpointHints: showHints,
          leftOpen: state.leftOpen ?? 0,
          rightOpen: state.rightOpen ?? 0,
          onLeftTapped: showHints ? () {
            final id = _selectedTileId!;
            setState(() { _needsSideChoice = false; _selectedTileId = null; });
            _placeSelectedTile(id, 'left');
          } : null,
          onRightTapped: showHints ? () {
            final id = _selectedTileId!;
            setState(() { _needsSideChoice = false; _selectedTileId = null; });
            _placeSelectedTile(id, 'right');
          } : null,
        ),
      ),
    );
  }

  Widget _buildPlayerArea(List<String> hand, DominoGameState state, bool isMyTurn) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: hand.map((tileId) {
          final td = state.tiles[tileId];
          if (td == null) return const SizedBox.shrink();
          final isPlayable = isMyTurn && state.canPlay(tileId);
          final isSelected = _selectedTileId == tileId;
          return GestureDetector(
            onTap: () => _onTileTap(tileId),
            child: AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: DominoTileWidget(left: td['left']!, right: td['right']!, width: 34, height: 64, isPlayable: isPlayable, isSelected: isSelected),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaceDown({required double width, required double height}) {
    return DominoTileWidget(left: 0, right: 0, width: width, height: height, faceDown: true);
  }
}
