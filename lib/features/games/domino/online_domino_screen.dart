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
import '../../../core/service/domino_game_service.dart';
import '../../../core/service/bot_name_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/widgets/domino_board_widgets.dart';
import '../../../core/widgets/domino_webview_board.dart';
import '../../adds/banner_ad_widget.dart';
import '../../../core/widgets/game_chat_widget.dart';

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
  final GlobalKey<GameChatWidgetState> _chatKey = GlobalKey<GameChatWidgetState>();

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
  bool _showRoundEndBanner = false;
  bool _showGameOverBanner = false;
  DominoGameMatch? _gameOverGame;
  DominoGameMatch? _pendingNewGame;
  DominoGameMatch? _roundEndPrevGame;
  Timer? _botMoveTimer;
  Timer? _turnTimer;
  int _turnSecondsLeft = 60;
  Timer? _awayTimer;
  int _awaySecondsLeft = 60;
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _isScreenKeepOnActive = false;

  static const Color _panelColor   = Colors.white;
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
    _loadUserData();

    final isBet = widget.matchType == 'Apuesta';
    _currencyType = isBet ? 'diamonds' : 'coins';
    if (!isBet) {
      _selectedBetAmount = 100;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isScreenKeepOnActive) WakelockPlus.enable();
      _awayTimer?.cancel();
      _awayTimer = null;
    } else if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
      if (!_gameEnded && _activeGameId != null) {
        _stopTurnTimer();
        _awaySecondsLeft = 60;
        _awayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          _awaySecondsLeft--;
          if (_awaySecondsLeft <= 0) {
            t.cancel();
            if (_activeGameId != null && _currentUser != null) {
              _gameService.abandonGame(gameId: _activeGameId!, playerId: _currentUser!.uid);
            }
          }
        });
      }
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _matchmakingTimer?.cancel();
    _botMoveTimer?.cancel();
    _turnTimer?.cancel();
    _awayTimer?.cancel();
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
      _gameEnded = false;
      _selectedTileId = null;
      _needsSideChoice = false;
    });

    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted) return;

      if (game == null || _gameEnded) {
        setState(() => _currentGame = game);
        return;
      }

      if (game.isFinished || game.isAbandoned) {
        _stopTurnTimer();
        setState(() { _currentGame = game; _gameEnded = true; });
        _disableWakeLock();
        _showGameOverDialog(game);
        return;
      }

      if (_showRoundEndBanner) {
        setState(() => _pendingNewGame = game);
        return;
      }

      final prevRound = _currentGame?.gameState.roundNumber;
      if (prevRound != null && game.gameState.roundNumber > prevRound) {
        setState(() {
          _roundEndPrevGame = _currentGame;
          _pendingNewGame = game;
          _showRoundEndBanner = true;
        });
        _stopTurnTimer();
        return;
      }

      setState(() => _currentGame = game);

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
    setState(() {
      _gameOverGame = game;
      _showGameOverBanner = true;
    });
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
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _accentOrange,
          elevation: 2,
          title: const Text('Dominó Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (inGame && !_isPlayingVsBot)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                onPressed: () => _chatKey.currentState?.toggleChat(),
                tooltip: 'Chat',
              ),
            if (inGame)
              TextButton(
                onPressed: _abandonGame,
                child: Text('Salir', style: TextStyle(color: Colors.red[300])),
              ),
          ],
        ),
        body: Stack(
          children: [
            _buildBody(),
            if (_activeGameId != null && !_isPlayingVsBot)
              GameChatWidget(
                key: _chatKey,
                gameId: _activeGameId!,
                collectionName: 'domino_games',
                currentUserId: _currentUser?.uid ?? '',
                currentUserName: _currentUser?.displayName ?? 'Jugador',
              ),
          ],
        ),
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
          const Text('¿Cuántos jugadores?', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Elige el número de jugadores para la partida', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
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
                      border: Border.all(color: sel ? _accentOrange : Colors.grey.shade300, width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: _accentOrange.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_playerCountIcon(n), style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text('$n jugadores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (isBet) ...[
            const Text('Selecciona tu apuesta', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
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
                      color: isSelected ? _accentOrange : canAfford ? _panelColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _accentOrange : canAfford ? Colors.grey.shade300 : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currencyIcon, size: 14, color: canAfford ? currencyColor : Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text('$amount', style: TextStyle(color: isSelected ? Colors.white : canAfford ? Colors.black87 : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 15)),
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
                disabledBackgroundColor: Colors.grey.shade300,
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
    final remaining = (60 - _matchmakingSeconds).clamp(0, 60);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFEC7A34)),
            ),
            const SizedBox(height: 32),
            const Text('Buscando partida...',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              '$remaining"',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _matchmakingSeconds >= 50 ? Colors.red : _accentOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text('$_selectedPlayerCount jugadores · buscando...',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(
              _matchmakingSeconds < 10
                  ? 'Conectando con otros jugadores...'
                  : _matchmakingSeconds < 50
                      ? '¡Ya casi! Ampliando búsqueda...'
                      : 'Completando con bots...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: () {
                _matchmakingTimer?.cancel();
                setState(() => _screenState = _DominoOnlineState.playerCountSelection);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancelar búsqueda'),
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

  Widget _buildWaitingRoom() {
    final joined = _currentGame?.currentPlayerCount ?? 1;
    final remaining = _selectedPlayerCount - joined;
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
                  if (remaining > 0) ...[
                    const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFEC7A34))),
                    const SizedBox(height: 6),
                    Text('Esperando $remaining ${remaining == 1 ? 'jugador más' : 'jugadores más'}...',
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      'Iniciando en ${(60 - _matchmakingSeconds).clamp(0, 60)}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _matchmakingSeconds >= 50 ? FontWeight.bold : FontWeight.normal,
                        color: _matchmakingSeconds >= 50 ? Colors.orange.shade700 : Colors.black45,
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
                _matchmakingTimer?.cancel();
                _gameSubscription?.cancel();
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
      child: Stack(
        children: [
          Column(
            children: [
              _buildOnlineLandscapeHeader(
                opponents: opponents,
                myScore: myScore,
                isMyTurn: isMyTurn,
                targetScore: game.targetScore,
                roundNumber: state.roundNumber,
              ),
              _buildOnlineChainArea(state),
              _buildOnlineLandscapeFooter(
                hand: myHand,
                state: state,
                isMyTurn: isMyTurn,
                canDraw: canDraw,
                canPass: canPass,
              ),
            ],
          ),
          if (_showRoundEndBanner) _buildRoundEndOverlay(),
          if (_showGameOverBanner && _gameOverGame != null) _buildGameOverOverlay(_gameOverGame!),
        ],
      ),
    );
  }

  Widget _buildRoundEndOverlay() {
    final prevGame = _roundEndPrevGame;
    final newGame = _pendingNewGame;
    if (prevGame == null || newGame == null) return const SizedBox.shrink();

    final prevScores = prevGame.getPlayerScores();
    final newScores = newGame.getPlayerScores();
    final myPrevScore = prevScores['player$_myPlayerNumber'] ?? 0;
    final myNewScore = newScores['player$_myPlayerNumber'] ?? 0;
    final iWon = myNewScore > myPrevScore;

    final wasBlocked = prevGame.gameState.consecutivePasses >= prevGame.numberOfPlayers;
    final String title = iWon ? 'Ronda ganada' : wasBlocked ? 'Bloqueado' : 'Ronda perdida';
    final Color titleColor = iWon ? _accentOrange : wasBlocked ? Colors.amber[600]! : Colors.red[400]!;

    // Fichas de los oponentes al final de la ronda anterior
    final opponentTiles = <({String name, List<({int left, int right})> tiles, int pips})>[];
    for (int p = 1; p <= prevGame.numberOfPlayers; p++) {
      if (p == _myPlayerNumber) continue;
      final hand = prevGame.gameState.handOf(p);
      final tileWidgets = hand.map((id) {
        final data = prevGame.gameState.tiles[id];
        return (left: data?['left'] ?? 0, right: data?['right'] ?? 0);
      }).toList();
      final pips = tileWidgets.fold(0, (s, t) => s + t.left + t.right);
      final name = _isPlayingVsBot ? _botName : prevGame.playerNameOf(p);
      opponentTiles.add((name: name, tiles: tileWidgets, pips: pips));
    }

    final scoreLines = StringBuffer();
    for (int p = 1; p <= newGame.numberOfPlayers; p++) {
      final name = p == _myPlayerNumber ? 'Tú'
          : (_isPlayingVsBot ? _botName : prevGame.playerNameOf(p));
      if (p > 1) scoreLines.write('  |  ');
      scoreLines.write('$name: ${newScores['player$p'] ?? 0}');
    }

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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 3,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(scoreLines.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            for (final opp in opponentTiles)
              if (opp.tiles.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.person, color: Colors.white54, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    '${opp.name} (${opp.tiles.length} fichas — ${opp.pips} puntos)',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ]),
                const SizedBox(height: 4),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: opp.tiles.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DominoTileWidget(left: t.left, right: t.right, width: 22, height: 40),
                    )).toList(),
                  ),
                ),
              ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final nextGame = _pendingNewGame;
                  setState(() {
                    _showRoundEndBanner = false;
                    _roundEndPrevGame = null;
                    _pendingNewGame = null;
                    if (nextGame != null) _currentGame = nextGame;
                  });
                  if (_currentGame != null) {
                    final isMyTurn = _currentGame!.isPlayerTurn(_currentUser!.uid);
                    if (isMyTurn) {
                      _startTurnTimer();
                    } else {
                      _stopTurnTimer();
                      if (_isOpponent(_currentGame!)) _scheduleOpponentTurn(_currentGame!);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: const Text('Siguiente ronda', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(DominoGameMatch game) {
    final bool iWon = game.winnerId == _currentUser!.uid;
    final Color titleColor = iWon ? _accentOrange : Colors.red[400]!;
    final String title = iWon ? '🏆 ¡Ganaste!' : '😞 Perdiste';
    final scores = game.getPlayerScores();
    final scoreLines = StringBuffer();
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      final name = p == _myPlayerNumber ? 'Tú' : (_isPlayingVsBot ? _botName : game.playerNameOf(p));
      scoreLines.write('$name: ${scores['player$p'] ?? 0}');
      if (p < game.numberOfPlayers) scoreLines.write(' | ');
    }

    return Positioned(
      left: 0, right: 0, bottom: 0,
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
            Text(scoreLines.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if ((game.betAmount ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                iWon
                    ? '+${game.betAmount! + (game.betAmount! * 0.7).ceil()} ${game.currencyType}'
                    : '-${game.betAmount} ${game.currencyType}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: iWon ? _accentOrange : Colors.red[300],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showGameOverBanner = false);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Salir', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineLandscapeHeader({
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
          // Round/target info
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
                      style: TextStyle(
                        color: _turnSecondsLeft <= 10 ? Colors.red[300] : Colors.green[300],
                        fontSize: 12, fontWeight: FontWeight.bold,
                      )),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, color: Colors.white54, size: 18),
                          Text(opp.name, style: const TextStyle(color: Colors.white60, fontSize: 9), overflow: TextOverflow.ellipsis),
                          Text('${opp.score}', style: TextStyle(color: opp.isActive ? _accentOrange : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: List.generate(
                          opp.handCount,
                          (_) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildFaceDownTile(width: 20, height: 38),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
          const SizedBox(width: 6),
          // My score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.white12 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isMyTurn ? Border.all(color: _accentOrange, width: 1.5) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 18),
                const Text('Tú', style: TextStyle(color: Colors.white60, fontSize: 9)),
                Text('$myScore', style: TextStyle(color: isMyTurn ? _accentOrange : Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineLandscapeFooter({
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
                _onlineInfoChip('Pozo: ${state.boneyard.length}'),
                const SizedBox(height: 3),
                if (state.chain.isNotEmpty)
                  _onlineInfoChip('${state.leftOpen ?? '-'} ↔ ${state.rightOpen ?? '-'}'),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: _buildOnlinePlayerArea(hand, state, isMyTurn)),
          if (isMyTurn && (canDraw || canPass)) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canDraw)
                    _onlineActionBtn('Tomar', Icons.add_box, Colors.blue[700]!, _drawFromBoneyard),
                  if (canPass)
                    _onlineActionBtn('Pasar', Icons.skip_next, Colors.orange[700]!, _passTurn),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _onlineInfoChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      );

  Widget _onlineActionBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
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

  Widget _buildOnlineChainArea(DominoGameState state) {
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

  Widget _buildOnlinePlayerArea(List<String> hand, DominoGameState state, bool isMyTurn) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                child: DominoTileWidget(
                  left: td['left']!,
                  right: td['right']!,
                  width: 34,
                  height: 64,
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
    return DominoTileWidget(left: 0, right: 0, width: width, height: height, faceDown: true);
  }
}

