import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/domino_game_match.dart';
import '../../../core/service/domino_game_service.dart';
import '../../../core/service/bot_name_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../adds/banner_ad_widget.dart';

enum _DominoOnlineState { playerCountSelection, matchmaking, waitingRoom, gameActive }

class OnlineDominoScreen extends StatefulWidget {
  final String matchType;
  const OnlineDominoScreen({super.key, required this.matchType});

  @override
  State<OnlineDominoScreen> createState() => _OnlineDominoScreenState();
}

class _OnlineDominoScreenState extends State<OnlineDominoScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final DominoGameService _gameService = DominoGameService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  _DominoOnlineState _screenState = _DominoOnlineState.playerCountSelection;
  int _selectedPlayerCount = 2;
  int? _selectedBetAmount;
  String _currencyType = 'coins';

  static const List<int> _betOptions = [10, 20, 50, 100, 250, 500, 1000, 5000, 10000];

  String? _activeGameId;
  int _myPlayerNumber = 1;
  DominoGameMatch? _currentGame;
  StreamSubscription<DominoGameMatch?>? _gameSubscription;
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;

  int _matchmakingSeconds = 0;
  Timer? _matchmakingTimer;
  bool _isSearching = false;
  bool _navigated = false;

  String? _myName;
  String? _myPhotoUrl;
  int? _userCoins;
  int? _userDiamonds;

  bool _isPlayingVsBot = false;
  String _botName = 'Bot';

  String? _selectedTileId;
  bool _needsSideChoice = false;
  bool _isOpponentThinking = false;
  bool _gameEnded = false;
  Timer? _botMoveTimer;
  Timer? _turnTimer;
  int _turnSecondsLeft = 60;
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _isScreenKeepOnActive = false;

  static const Color _tableColor = Color(0xFFD4A850);
  static const Color _panelColor = Color(0xDD1A0800);
  static const Color _tileColor = Color(0xFFFFF8E1);
  static const Color _tileBorder = Color(0xFF4A3728);
  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();

    final isBet = widget.matchType == 'Apuesta';
    _currencyType = isBet ? 'diamonds' : 'coins';
    if (!isBet) {
      _selectedBetAmount = 100;
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
      if (kDebugMode) print('Error loading user data: $e');
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
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _matchmakingTimer?.cancel();
    _botMoveTimer?.cancel();
    _turnTimer?.cancel();
    _chainScrollCtrl.dispose();
    _disableWakeLock();
    super.dispose();
  }

  Future<void> _startMatchmaking() async {
    if (_currentUser == null) return;
    if (_selectedBetAmount == null && widget.matchType == 'Apuesta') return;

    final balance = _currencyType == 'diamonds' ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final cost = _selectedBetAmount ?? 100;
    if (balance < cost) {
      _showSnack('Fondos insuficientes');
      return;
    }

    setState(() {
      _screenState = _DominoOnlineState.matchmaking;
      _isSearching = true;
      _matchmakingSeconds = 0;
    });

    await _enableWakeLock();

    _matchmakingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _matchmakingSeconds++);

      if (_matchmakingSeconds >= 30 && !_navigated && _selectedPlayerCount == 2) {
        t.cancel();
        _startBotGame();
      }
    });

    await _tryJoinOrCreate();
  }

  Future<void> _tryJoinOrCreate() async {
    if (!mounted || _navigated) return;
    try {
      final games = await _gameService.findWaitingGames(
        currencyType: _currencyType,
        numberOfPlayers: _selectedPlayerCount,
      );
      final eligible = games.where((g) {
        if (g.hostId == _currentUser!.uid) return false;
        if (_selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
        return true;
      }).toList();

      if (eligible.isNotEmpty && !_navigated) {
        final game = eligible.first;
        final joined = await _gameService.joinGame(
          gameId: game.id,
          guestId: _currentUser!.uid,
          guestName: _myName ?? 'Jugador',
          guestPhotoUrl: _myPhotoUrl,
        );
        if (joined && !_navigated) {
          _navigated = true;
          _matchmakingTimer?.cancel();
          _openGame(game.id, 2);
          return;
        }
      }

      if (!_navigated) {
        final result = await _gameService.createGame(
          hostId: _currentUser!.uid,
          hostName: _myName ?? 'Jugador',
          hostPhotoUrl: _myPhotoUrl,
          currencyType: _currencyType,
          betAmount: _selectedBetAmount,
          isOnlineMatchmaking: true,
          numberOfPlayers: _selectedPlayerCount,
        );
        if (result != null && !_navigated) {
          setState(() {
            _activeGameId = result['gameId'];
            _screenState = _DominoOnlineState.waitingRoom;
          });
          _listenForOpponent(result['gameId']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Matchmaking error: $e');
    }
  }

  void _listenForOpponent(String gameId) {
    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted || _navigated) return;
      if (game == null) return;
      if (game.status == 'waiting') setState(() => _currentGame = game);
      if (game.isActive && game.isFullyJoined) {
        _navigated = true;
        _matchmakingTimer?.cancel();
        _openGame(gameId, 1);
      }
    });
  }

  Future<void> _startBotGame() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    _matchmakingTimer?.cancel();
    _isSearching = false;

    if (_activeGameId == null) {
      final result = await _gameService.createGame(
        hostId: _currentUser!.uid,
        hostName: _myName ?? 'Jugador',
        hostPhotoUrl: _myPhotoUrl,
        currencyType: _currencyType,
        betAmount: widget.matchType == 'Apuesta' ? _selectedBetAmount : 0,
        isOnlineMatchmaking: true,
      );
      if (result == null || !mounted) return;
      _activeGameId = result['gameId'];
    }

    await _gameService.addBotAndStart(_activeGameId!);

    final profile = await BotNameService.pickUnseenProfile(_random);
    if (!mounted) return;

    setState(() {
      _isPlayingVsBot = true;
      _botName = profile['name'] ?? 'Bot';
    });

    _openGame(_activeGameId!, 1);
  }

  void _openGame(String gameId, int playerNumber) {
    setState(() {
      _activeGameId = gameId;
      _myPlayerNumber = playerNumber;
      _screenState = _DominoOnlineState.gameActive;
      _isSearching = false;
      _gameEnded = false;
      _selectedTileId = null;
      _needsSideChoice = false;
    });

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

    _enableWakeLock();
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    _turnSecondsLeft = 60;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _turnSecondsLeft--);
      if (_turnSecondsLeft <= 0) {
        t.cancel();
        _autoPassTurn();
      }
    });
  }

  void _stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  Future<void> _autoPassTurn() async {
    if (_activeGameId == null || _gameEnded) return;
    final newDeal = DominoGameState.initialDeal(_random);
    await _gameService.passTurn(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
      newRoundDeal: newDeal,
    );
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

    List<String> playable = botHand.where((id) => state.canPlay(id)).toList();

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

    if (state.chain.isEmpty) {
      _placeSelectedTile(tileId, 'right');
      return;
    }

    final tileData = state.tiles[tileId]!;
    final canLeft = tileData['left'] == state.leftOpen || tileData['right'] == state.leftOpen;
    final canRight = tileData['left'] == state.rightOpen || tileData['right'] == state.rightOpen;
    _placeSelectedTile(tileId, canRight ? 'right' : 'left');
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
    final success = await _gameService.playTile(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
      tileId: tileId,
      side: side,
      newRoundDeal: newDeal,
    );

    if (!success && mounted) {
      setState(() => _currentGame = prevGame);
      _showSnack('No se pudo colocar la ficha');
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
    if (game == null) return;
    if (!game.isPlayerTurn(_currentUser!.uid)) return;

    final state = game.gameState;
    if (state.boneyard.isEmpty) {
      _showSnack('El pozo está vacío');
      return;
    }

    final myHand = game.getHand(_myPlayerNumber);
    if (state.canPlayAny(myHand)) {
      _showSnack('Tienes fichas jugables');
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
    final myScore = scores['player$_myPlayerNumber'] ?? 0;
    final scoreLines = StringBuffer();
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      final name = p == _myPlayerNumber ? 'Tú' : game.playerNameOf(p);
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
    final inGame = _screenState == _DominoOnlineState.gameActive;
    return PopScope(
      canPop: !inGame || _gameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inGame && !_gameEnded) _abandonGame();
      },
      child: Scaffold(
        backgroundColor: _tableColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF3E2007),
          elevation: 2,
          title: const Text('Dominó Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (inGame)
              TextButton(
                onPressed: _abandonGame,
                child: Text('Salir', style: TextStyle(color: Colors.red[300])),
              ),
          ],
        ),
        body: inGame
            ? Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _WoodGrainPainter())),
                  _buildBody(),
                ],
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case _DominoOnlineState.playerCountSelection:
        return _buildPlayerCountSelection();
      case _DominoOnlineState.matchmaking:
        return _buildMatchmaking();
      case _DominoOnlineState.waitingRoom:
        return _buildWaitingRoom();
      case _DominoOnlineState.gameActive:
        return _buildGame();
    }
  }

  Widget _buildPlayerCountSelection() {
    final isBet = widget.matchType == 'Apuesta';
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final currencyIcon = isBet ? Icons.diamond : Icons.monetization_on;
    final currencyColor = isBet ? Colors.blue[300]! : Colors.amber[300]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentOrange, const Color(0xFFFF9A5C)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _accentOrange.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('🁣', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dominó Online', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(isBet ? 'Modo Apuesta' : 'Modo Diversión', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(currencyIcon, color: Colors.white, size: 18),
                    const SizedBox(height: 2),
                    Text('$balance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('¿Cuántos jugadores?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Elige el número de jugadores para la partida', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final sel = _selectedPlayerCount == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => setState(() { _selectedPlayerCount = n; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 84, height: 96,
                    decoration: BoxDecoration(
                      color: sel ? _accentOrange : _panelColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? _accentOrange : Colors.white24, width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: _accentOrange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_playerCountIcon(n), style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text('$n jugadores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.white70), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (isBet) ...[
            const Text('Selecciona tu apuesta', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _betOptions.map((amount) {
                final isSelected = _selectedBetAmount == amount;
                final canAfford = balance >= amount;
                return GestureDetector(
                  onTap: canAfford ? () => setState(() => _selectedBetAmount = amount) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _accentOrange : canAfford ? _panelColor : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _accentOrange : canAfford ? Colors.white24 : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currencyIcon, size: 14, color: canAfford ? currencyColor : Colors.white24),
                        const SizedBox(width: 4),
                        Text('$amount', style: TextStyle(color: canAfford ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (isBet && _selectedBetAmount == null) ? null : _startMatchmaking,
              icon: const Icon(Icons.search),
              label: const Text('Buscar partida', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildMatchmaking() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              color: _accentOrange,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Buscando oponente...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${_matchmakingSeconds}s',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () {
              _matchmakingTimer?.cancel();
              setState(() => _screenState = _DominoOnlineState.playerCountSelection);
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom() {
    final joined = _currentGame?.currentPlayerCount ?? 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: _panelColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top, color: Colors.white54, size: 52),
                  const SizedBox(height: 16),
                  const Text('Sala de espera', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$joined / $_selectedPlayerCount jugadores', style: TextStyle(color: _accentOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: joined / _selectedPlayerCount,
                      backgroundColor: Colors.white12,
                      color: _accentOrange,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Esperando jugadores...', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () async {
                _matchmakingTimer?.cancel();
                _gameSubscription?.cancel();
                if (_activeGameId != null) {
                  await _gameService.abandonGame(gameId: _activeGameId!, playerId: _currentUser!.uid);
                }
                if (mounted) Navigator.pop(context);
              },
              child: Text('Cancelar', style: TextStyle(color: Colors.red[300])),
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
    final myScore = scores['player$_myPlayerNumber'] ?? 0;

    return SafeArea(
      child: Column(
        children: [
          _buildOnlineScoreBar(
            myScore: myScore,
            opponents: opponents,
            isMyTurn: isMyTurn,
            targetScore: game.targetScore,
            roundNumber: state.roundNumber,
          ),
          _buildOnlineOpponentsArea(opponents, isMyTurn),
          const SizedBox(height: 4),
          _buildOnlineChainArea(state),
          const SizedBox(height: 4),
          _buildOnlineBoneyardBar(state),
          const SizedBox(height: 4),
          if (isMyTurn)
            _buildOnlineActionButtons(canDraw, canPass),
          _buildOnlinePlayerArea(myHand, state, isMyTurn),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildOnlineScoreBar({
    required int myScore,
    required List<({int playerNum, String name, int handCount, int score, bool isActive})> opponents,
    required bool isMyTurn,
    required int targetScore,
    required int roundNumber,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xBB1A0800),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          for (final opp in opponents)
            _buildScoreColumn(opp.name, opp.score, opp.isActive, isOpponent: true),
          Expanded(
            child: Column(
              children: [
                Text('Meta: $targetScore', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text('Ronda $roundNumber', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                if (isMyTurn && _turnTimer != null)
                  Text(
                    '⏱ $_turnSecondsLeft s',
                    style: TextStyle(
                      color: _turnSecondsLeft <= 10 ? Colors.red[300] : Colors.white38,
                      fontSize: 11, fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          _buildScoreColumn('Tú', myScore, isMyTurn, isOpponent: false),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String name, int score, bool isActive, {required bool isOpponent}) {
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
          CircleAvatar(
            radius: 14,
            backgroundColor: isOpponent ? Colors.grey[700] : Colors.grey[600],
            child: Icon(
              isOpponent ? Icons.person_outline : Icons.person,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 3),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(
            '$score',
            style: TextStyle(
              color: isActive ? _accentOrange : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineOpponentsArea(
    List<({int playerNum, String name, int handCount, int score, bool isActive})> opponents,
    bool isMyTurn,
  ) {
    if (opponents.length == 1) {
      return _buildOpponentRow(opponents.first, isMyTurn);
    }
    // Multiple opponents — show in a Row
    return SizedBox(
      height: 72,
      child: Row(
        children: opponents.map((opp) => Expanded(child: _buildOpponentRow(opp, isMyTurn))).toList(),
      ),
    );
  }

  Widget _buildOpponentRow(
    ({int playerNum, String name, int handCount, int score, bool isActive}) opp,
    bool isMyTurn,
  ) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: opp.isActive ? const Color(0xCC2A1000) : const Color(0xBB1A0800),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: opp.isActive ? _accentOrange : Colors.white12, width: opp.isActive ? 1.5 : 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(opp.name, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis),
                Text('${opp.score}', style: TextStyle(color: opp.isActive ? _accentOrange : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              children: List.generate(
                opp.handCount,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: _buildFaceDownTile(width: 26, height: 48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineChainArea(DominoGameState state) {
    return Expanded(
      child: state.chain.isEmpty
          ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('La cadena aparecerá aquí', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: _chainScrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: _buildSnakeWidget(state.chain, constraints.maxWidth - 24),
              ),
            ),
    );
  }

  Widget _buildSnakeWidget(List<DominoChainTile> chain, double availW) {
    const double tW = 44.0; // landscape tile width
    const double tH = 24.0; // landscape tile height
    const double cW = 24.0; // corner/portrait tile width
    const double cH = 44.0; // corner/portrait tile height
    const double g = 3.0;   // gap between tiles
    const double dy = (cH - tH) / 2.0; // vertical centering offset = 10
    const double rowStep = cH - tH;    // y advance per turn = 20

    final items = <Widget>[];
    double curX = 0;
    double curY = 0;
    double totalH = cH;
    int dir = 1; // 1=right, -1=left

    for (int i = 0; i < chain.length; i++) {
      final ct = chain[i];
      final bool isLast = i == chain.length - 1;

      bool makeCorner = false;
      if (!isLast) {
        if (dir == 1) {
          makeCorner = (curX + tW + g) > (availW - cW - g);
        } else {
          makeCorner = curX < (cW + g);
        }
      }

      final bool portrait = makeCorner || ct.isDouble;
      final double w = portrait ? cW : tW;
      final double h = portrait ? cH : tH;
      final double topOff = portrait ? 0.0 : dy;

      if (makeCorner) {
        final double left = dir == 1 ? (availW - cW) : 0.0;
        items.add(Positioned(
          left: left, top: curY, width: cW, height: cH,
          child: _buildDominoTileWidget(
            left: ct.displayLeft, right: ct.displayRight,
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
            left: ct.displayLeft, right: ct.displayRight,
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

  Widget _buildOnlineBoneyardBar(DominoGameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'Pozo: ${state.boneyard.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (state.chain.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${state.leftOpen ?? '-'} ← → ${state.rightOpen ?? '-'}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOnlineActionButtons(bool canDraw, bool canPass) {
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
                onPressed: _passTurn,
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

  Widget _buildSideChoiceBar(DominoGameState state, String tileId) {
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
          const Text('¿Dónde?', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ElevatedButton(
            onPressed: () {
              setState(() { _needsSideChoice = false; _selectedTileId = null; });
              _placeSelectedTile(tileId, 'left');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: Text('← (${state.leftOpen})'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() { _needsSideChoice = false; _selectedTileId = null; });
              _placeSelectedTile(tileId, 'right');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: Text('(${state.rightOpen}) →'),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlinePlayerArea(List<String> hand, DominoGameState state, bool isMyTurn) {
    return Container(
      height: 108,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xBB1A0800),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
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
                child: _buildDominoTileWidget(
                  left: td['left']!,
                  right: td['right']!,
                  isPortrait: true,
                  width: 46,
                  height: 86,
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
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
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
    final borderColor = isSelected ? _accentOrange : isPlayable ? Colors.green[400]! : _tileBorder;
    final borderWidth = (isSelected || isPlayable) ? 2.0 : 1.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _tileColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: isPlayable ? Colors.green.withValues(alpha: 0.4) : Colors.black45,
            blurRadius: isPlayable ? 6 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: isPortrait
            ? Column(
                children: [
                  Expanded(child: _buildPips(left)),
                  Container(height: 1, color: _tileBorder.withValues(alpha: 0.5)),
                  Expanded(child: _buildPips(right)),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _buildPips(left)),
                  Container(width: 1, color: _tileBorder.withValues(alpha: 0.5)),
                  Expanded(child: _buildPips(right)),
                ],
              ),
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
      case 1: return [Alignment.center];
      case 2: return [Alignment.topRight, Alignment.bottomLeft];
      case 3: return [Alignment.topRight, Alignment.center, Alignment.bottomLeft];
      case 4: return [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];
      case 5: return [Alignment.topLeft, Alignment.topRight, Alignment.center, Alignment.bottomLeft, Alignment.bottomRight];
      case 6: return [const Alignment(-1, -1), const Alignment(1, -1), const Alignment(-1, 0), const Alignment(1, 0), const Alignment(-1, 1), const Alignment(1, 1)];
      default: return [];
    }
  }
}

class _WoodGrainPainter extends CustomPainter {
  // Natural bamboo / light oak palette — warm honey tones
  static const _baseColors = [
    Color(0xFFDFB25A), Color(0xFFD4A84E), Color(0xFFE3B660),
    Color(0xFFCFA24A), Color(0xFFDAB058), Color(0xFFD5A850),
    Color(0xFFE0B45C), Color(0xFFCCA04C), Color(0xFFDCAE56),
    Color(0xFFD1A64E), Color(0xFFE1B25A), Color(0xFFCCA24C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const plankCount = 14;
    final rng = Random(37); // fixed seed — deterministic render
    final plankH = size.height / plankCount;

    for (int i = 0; i < plankCount; i++) {
      final top = i * plankH;
      final base = _baseColors[i % _baseColors.length];

      // Base fill: subtle top-to-bottom gradient per plank
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

      // Wavy grain lines using quadratic bezier curves
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
          Path()
            ..moveTo(0, gy)
            ..quadraticBezierTo(cx, cy, size.width, endY),
          grainPaint,
        );
      }

      // Soft highlight at top of each plank
      canvas.drawLine(
        Offset(0, top + 1.5), Offset(size.width, top + 1.5),
        Paint()..color = const Color(0x1AFFFFFF)..strokeWidth = 2.0,
      );

      // Seam between planks
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

