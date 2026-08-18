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
import '../../../core/service/firestore_service.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
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
  DominoGameMatch? _lastServerGame;
  StreamSubscription<DominoGameMatch?>? _gameSubscription;
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;

  int _matchmakingSeconds = 0;
  Timer? _matchmakingTimer;
  bool _navigated = false;
  bool _isRetrying = false;

  String? _myName;
  String? _myPhotoUrl;
  int? _userCoins;
  int? _userDiamonds;

  bool _isPlayingVsBot = false;
  bool _botGameRewardHandled = false;

  ({int left, int right})? _flyingTileData;
  late AnimationController _playerFlyAnimCtrl;
  late Animation<Offset> _playerFlyAnim;

  bool _boneyardFlyActive = false;
  bool _isDrawing = false;
  bool _autoPassPending = false;
  late AnimationController _boneyardFlyAnimCtrl;
  late Animation<Offset> _boneyardFlyAnim;
  late AnimationController _mandatoryTileAnimCtrl;

  String? _selectedTileId;
  bool _needsSideChoice = false;
  bool _isOpponentThinking = false;
  bool _gameEnded = false;
  bool _showRoundEndBanner = false;
  bool _showGameOverBanner = false;
  DominoGameMatch? _gameOverGame;
  DominoGameMatch? _pendingNewGame;
  DominoGameMatch? _roundEndPrevGame;
  int? _roundWinnerNum;
  bool _roundWasBlocked = false;
  Timer? _roundEndTimer;
  int _roundEndCountdown = 15;
  Timer? _botMoveTimer;
  Timer? _turnTimer;
  int _turnSecondsLeft = 60;
  Timer? _awayTimer;
  int _awaySecondsLeft = 60;
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _isScreenKeepOnActive = false;
  int _unreadChatCount = 0;
  String? _lastMsgSenderId;
  String? _lastMsgText;
  String? _ownMsgText;
  Timer? _msgBubbleTimer;
  Timer? _ownMsgBubbleTimer;

  static const Color _panelColor   = Colors.white;
  static const Color _accentOrange = Color(0xFFEC7A34);

  @override
  void initState() {
    super.initState();
    DominoSpriteSheet.preload().then((_) { if (mounted) setState(() {}); });

    _playerFlyAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _playerFlyAnim = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _playerFlyAnimCtrl, curve: Curves.easeOut));

    _boneyardFlyAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550),
    );
    _boneyardFlyAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 4.0),
    ).animate(CurvedAnimation(parent: _boneyardFlyAnimCtrl, curve: Curves.easeIn));
    _mandatoryTileAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

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
    // Cancel any waiting game left in Firestore when leaving during matchmaking
    if (_activeGameId != null && (_screenState == _DominoOnlineState.matchmaking || _screenState == _DominoOnlineState.waitingRoom) && !_navigated) {
      final gameId = _activeGameId!;
      _firestore.collection('domino_games').doc(gameId).update({
        'status': 'cancelled',
        'finishedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
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
    _msgBubbleTimer?.cancel();
    _ownMsgBubbleTimer?.cancel();
    _roundEndTimer?.cancel();
    _chainScrollCtrl.dispose();
    _playerFlyAnimCtrl.dispose();
    _boneyardFlyAnimCtrl.dispose();
    _mandatoryTileAnimCtrl.dispose();
    _disableWakeLock();
    super.dispose();
  }

  Future<void> _cancelMatchmaking() async {
    _matchmakingTimer?.cancel();
    _gameSubscription?.cancel();
    final gameId = _activeGameId;
    _activeGameId = null;
    _navigated = false;
    setState(() => _screenState = _DominoOnlineState.playerCountSelection);
    // Cancel the waiting game in Firestore so others don't find it
    if (gameId != null) {
      try {
        await _firestore.collection('domino_games').doc(gameId).update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
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

      if (_matchmakingSeconds % 5 == 0 && !_navigated && _screenState == _DominoOnlineState.matchmaking) {
        _retryMatchmaking();
      }

      if (_matchmakingSeconds >= 60 && !_navigated) {
        t.cancel();
        if (_selectedPlayerCount == 2) {
          _startBotGame();
        } else {
          _fillBotsAndStart();
        }
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
        isOnlineMatchmaking: true,
      );
      final uid = _currentUser!.uid;
      final eligible = games.where((g) {
        if (g.hostId == uid) return false;
        if (g.guestId == uid || g.guest2Id == uid || g.guest3Id == uid) return false;
        if (_selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
        return true;
      }).toList();
      // Prefer games closest to being full (most players first)
      eligible.sort((a, b) => b.currentPlayerCount.compareTo(a.currentPlayerCount));

      if (eligible.isNotEmpty && !_navigated) {
        final game = eligible.first;
        final joined = await _gameService.joinGame(
          gameId: game.id,
          guestId: _currentUser!.uid,
          guestName: _myName ?? 'Jugador',
          guestPhotoUrl: _myPhotoUrl,
        );
        if (joined && !_navigated) {
          final doc = await _firestore.collection('domino_games').doc(game.id).get();
          final updatedGame = doc.exists ? DominoGameMatch.fromFirestore(doc) : null;
          if (updatedGame != null && updatedGame.isActive) {
            _navigated = true;
            _matchmakingTimer?.cancel();
            final myNum = updatedGame.getPlayerNumber(_currentUser!.uid);
            _openGame(game.id, myNum > 0 ? myNum : 2);
          } else {
            setState(() {
              _activeGameId = game.id;
              _screenState = _DominoOnlineState.waitingRoom;
            });
            _listenForOpponent(game.id);
          }
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

  Future<void> _retryMatchmaking() async {
    if (!mounted || _navigated || _activeGameId == null || _isRetrying) return;
    _isRetrying = true;
    try {
      final currentDoc = await _firestore.collection('domino_games').doc(_activeGameId!).get();
      if (!currentDoc.exists || !mounted || _navigated) return;
      final currentGame = DominoGameMatch.fromFirestore(currentDoc);

      if (currentGame.status == 'cancelled') {
        _gameSubscription?.cancel();
        _activeGameId = null;
        if (mounted) {
          setState(() => _screenState = _DominoOnlineState.matchmaking);
          await _tryJoinOrCreate();
        }
        return;
      }

      if (currentGame.isActive) return;

      final uid = _currentUser!.uid;
      final amHost = currentGame.hostId == uid;
      final playerCount = currentGame.currentPlayerCount;

      if (_selectedPlayerCount >= 3) {
        if (!amHost) return;

        if (playerCount == 1) {
          final games = await _gameService.findWaitingGames(
            currencyType: _currencyType,
            numberOfPlayers: _selectedPlayerCount,
            isOnlineMatchmaking: true,
          );
          final eligible = games.where((g) {
            if (g.hostId == uid) return false;
            if (g.guestId == uid || g.guest2Id == uid || g.guest3Id == uid) return false;
            if (_selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
            return true;
          }).toList();
          eligible.sort((a, b) => b.currentPlayerCount.compareTo(a.currentPlayerCount));

          if (eligible.isNotEmpty && !_navigated) {
            final target = eligible.first;
            final joined = await _gameService.joinGame(
              gameId: target.id,
              guestId: uid,
              guestName: _myName ?? 'Jugador',
              guestPhotoUrl: _myPhotoUrl,
            );
            if (joined && !_navigated) {
              // Cancel our empty game
              try {
                await _firestore.collection('domino_games').doc(_activeGameId!).update({
                  'status': 'cancelled',
                  'finishedAt': FieldValue.serverTimestamp(),
                });
              } catch (_) {}

              final doc = await _firestore.collection('domino_games').doc(target.id).get();
              final updatedGame = doc.exists ? DominoGameMatch.fromFirestore(doc) : null;
              if (updatedGame != null && updatedGame.isActive) {
                _navigated = true;
                _matchmakingTimer?.cancel();
                final myNum = updatedGame.getPlayerNumber(uid);
                _openGame(target.id, myNum > 0 ? myNum : 2);
              } else {
                setState(() {
                  _activeGameId = target.id;
                  _screenState = _DominoOnlineState.waitingRoom;
                });
                _listenForOpponent(target.id);
              }
            }
          }
          return;
        }

        if (playerCount > 1 && !currentGame.isFullyJoined) {
          final games = await _gameService.findWaitingGames(
            currencyType: _currencyType,
            numberOfPlayers: _selectedPlayerCount,
            isOnlineMatchmaking: true,
          );
          final olderGame = games.where((g) {
            if (g.id == _activeGameId) return false;
            if (_selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
            return g.createdAt.isBefore(currentGame.createdAt);
          }).toList();

          if (olderGame.isNotEmpty && !_navigated) {
            try {
              await _firestore.collection('domino_games').doc(_activeGameId!).update({
                'status': 'cancelled',
                'finishedAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
            _gameSubscription?.cancel();
            _activeGameId = null;
            if (mounted) {
              setState(() => _screenState = _DominoOnlineState.matchmaking);
              await _tryJoinOrCreate();
            }
          }
        }
        return;
      }

      final games = await _gameService.findWaitingGames(
        currencyType: _currencyType,
        numberOfPlayers: _selectedPlayerCount,
        isOnlineMatchmaking: true,
      );
      final eligible = games.where((g) {
        if (g.hostId == uid) return false;
        if (g.guestId == uid) return false;
        if (_selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
        return true;
      }).toList();

      if (eligible.isNotEmpty && !_navigated) {
        final game = eligible.first;
        final joined = await _gameService.joinGame(
          gameId: game.id,
          guestId: uid,
          guestName: _myName ?? 'Jugador',
          guestPhotoUrl: _myPhotoUrl,
        );
        if (joined && !_navigated) {
          try {
            final oldId = _activeGameId;
            if (oldId != null && oldId != game.id) {
              await _firestore.runTransaction((tx) async {
                final oldDoc = await tx.get(_firestore.collection('domino_games').doc(oldId));
                if (!oldDoc.exists) return;
                final old = DominoGameMatch.fromFirestore(oldDoc);
                if (old.status == 'waiting' && old.guestId == null) {
                  tx.update(oldDoc.reference, {'status': 'cancelled', 'finishedAt': FieldValue.serverTimestamp()});
                }
              });
            }
          } catch (_) {}

          final doc = await _firestore.collection('domino_games').doc(game.id).get();
          final updatedGame = doc.exists ? DominoGameMatch.fromFirestore(doc) : null;
          if (updatedGame != null && updatedGame.isActive) {
            _navigated = true;
            _matchmakingTimer?.cancel();
            final myNum = updatedGame.getPlayerNumber(uid);
            _openGame(game.id, myNum > 0 ? myNum : 2);
          } else {
            setState(() {
              _activeGameId = game.id;
              _screenState = _DominoOnlineState.waitingRoom;
            });
            _listenForOpponent(game.id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Retry matchmaking error: $e');
    } finally {
      _isRetrying = false;
    }
  }

  void _listenForOpponent(String gameId) {
    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted || _navigated) return;
      if (game == null) return;

      if (game.status == 'cancelled') {
        _gameSubscription?.cancel();
        _activeGameId = null;
        if (mounted && !_navigated) {
          setState(() => _screenState = _DominoOnlineState.matchmaking);
          _tryJoinOrCreate();
        }
        return;
      }

      if (game.status == 'waiting') setState(() => _currentGame = game);
      if (game.isActive && game.isFullyJoined) {
        _navigated = true;
        _matchmakingTimer?.cancel();
        final myNum = game.getPlayerNumber(_currentUser!.uid);
        _openGame(gameId, myNum > 0 ? myNum : 1);
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

    if (widget.matchType == 'Apuesta' && (_selectedBetAmount ?? 0) > 0 && _currentUser != null) {
      await _firestoreService.incrementUserDiamonds(_currentUser!.uid, -_selectedBetAmount!);
    }

    if (!mounted) return;

    setState(() {
      _isPlayingVsBot = true;
    });

    _openGame(_activeGameId!, 1);
  }

  Future<void> _fillBotsAndStart() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    _matchmakingTimer?.cancel();

    try {
      if (_activeGameId == null) {
        final result = await _gameService.createGame(
          hostId: _currentUser!.uid,
          hostName: _myName ?? 'Jugador',
          hostPhotoUrl: _myPhotoUrl,
          currencyType: _currencyType,
          betAmount: widget.matchType == 'Apuesta' ? _selectedBetAmount : 0,
          isOnlineMatchmaking: true,
          numberOfPlayers: _selectedPlayerCount,
        );
        if (result == null || !mounted) return;
        _activeGameId = result['gameId'];
      }

      bool filled = false;
      for (int attempt = 0; attempt < 3 && !filled; attempt++) {
        filled = await _gameService.fillRemainingWithBots(_activeGameId!);
        if (!filled && attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (!filled || !mounted) {
        if (mounted) {
          _showSnack('Error al iniciar partida. Intenta de nuevo.');
          Navigator.of(context).pop();
        }
        return;
      }
      final doc = await _firestore.collection('domino_games').doc(_activeGameId!).get();
      if (!doc.exists || !mounted) return;
      final game = DominoGameMatch.fromFirestore(doc);
      final myNum = game.getPlayerNumber(_currentUser!.uid);

      bool allBots = true;
      for (int p = 1; p <= game.numberOfPlayers; p++) {
        if (p == myNum) continue;
        final pid = game.playerIdOf(p);
        if (pid != null && !pid.startsWith('bot_')) { allBots = false; break; }
      }

      if (allBots) {
        setState(() => _isPlayingVsBot = true);
      }

      _openGame(_activeGameId!, myNum > 0 ? myNum : 1);
    } catch (e) {
      if (kDebugMode) print('Error in _fillBotsAndStart: $e');
      if (mounted) {
        _showSnack('Error al iniciar partida. Intenta de nuevo.');
        Navigator.of(context).pop();
      }
    }
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

      if (game != null) _lastServerGame = game;

      if (game == null || _gameEnded) {
        setState(() => _currentGame = game);
        return;
      }

      final serverPlayerNum = game.getPlayerNumber(_currentUser!.uid);

      if (game.isFinished || game.isAbandoned) {
        _stopTurnTimer();
        setState(() { _currentGame = game; _gameEnded = true; });
        _disableWakeLock();
        if (_isPlayingVsBot) _handleBotGameReward(game);
        _showGameOverDialog(game);
        return;
      }

      if (serverPlayerNum == 0) {
        setState(() { _gameEnded = true; });
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (serverPlayerNum != _myPlayerNumber) {
        _myPlayerNumber = serverPlayerNum;
      }

      if (_showRoundEndBanner) {
        setState(() => _pendingNewGame = game);
        return;
      }

      final prevRound = _currentGame?.gameState.roundNumber;
      if (prevRound != null && game.gameState.roundNumber > prevRound) {
        final prevScoresNow = _currentGame!.getPlayerScores();
        final newScoresNow = game.getPlayerScores();
        int? detectedWinner;
        for (int p = 1; p <= game.numberOfPlayers; p++) {
          if ((newScoresNow['player$p'] ?? 0) > (prevScoresNow['player$p'] ?? 0)) {
            detectedWinner = p;
            break;
          }
        }
        final wasBlockedNow = _currentGame!.gameState.consecutivePasses >= _currentGame!.numberOfPlayers - 1;
        setState(() {
          _roundEndPrevGame = _currentGame;
          _pendingNewGame = game;
          _showRoundEndBanner = true;
          _roundEndCountdown = 15;
          _roundWinnerNum = detectedWinner;
          _roundWasBlocked = wasBlockedNow;
        });
        _stopTurnTimer();
        _roundEndTimer?.cancel();
        _roundEndTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          if (_roundEndCountdown <= 1) {
            t.cancel();
            _advanceToNextRound();
          } else {
            setState(() => _roundEndCountdown--);
          }
        });
        return;
      }

      setState(() { _currentGame = game; _isDrawing = false; });

      final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
      if (isMyTurn) {
        final myHand = game.getHand(_myPlayerNumber);
        final state = game.gameState;
        if (!state.canPlayAny(myHand) && state.boneyard.isEmpty) {
          if (!_autoPassPending) {
            _autoPassPending = true;
            Future.delayed(const Duration(milliseconds: 800), () {
              _autoPassPending = false;
              if (mounted && !_gameEnded) {
                _showSnack('Sin opciones, pasas automáticamente');
                _passTurn();
              }
            });
          }
        } else {
          _autoPassPending = false;
          _startTurnTimer();
        }
      } else {
        _autoPassPending = false;
        _stopTurnTimer();
        if (_isOpponent(game)) _scheduleOpponentTurn(game);
      }
    });

    _enableWakeLock();
  }

  void _advanceToNextRound() {
    _roundEndTimer?.cancel();
    _roundEndTimer = null;
    final nextGame = _pendingNewGame;
    setState(() {
      _showRoundEndBanner = false;
      _roundEndPrevGame = null;
      _pendingNewGame = null;
      _roundEndCountdown = 15;
      _roundWinnerNum = null;
      _roundWasBlocked = false;
      if (nextGame != null) _currentGame = nextGame;
    });
    _autoPassPending = false;
    if (_currentGame != null) {
      final game = _currentGame!;
      final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
      if (isMyTurn) {
        final myHand = game.getHand(_myPlayerNumber);
        final state = game.gameState;
        if (!state.canPlayAny(myHand) && state.boneyard.isEmpty) {
          _autoPassPending = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            _autoPassPending = false;
            if (mounted && !_gameEnded) {
              _showSnack('Sin opciones, pasas automáticamente');
              _passTurn();
            }
          });
        } else {
          _startTurnTimer();
        }
      } else {
        _stopTurnTimer();
        if (_isOpponent(game)) _scheduleOpponentTurn(game);
      }
    }
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
      await _gameService.playTile(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
        tileId: tileId,
        side: side,
      );
    } else if (state.boneyard.isNotEmpty) {
      await _gameService.drawFromBoneyard(gameId: _activeGameId!, playerId: _currentUser!.uid);
    } else {
      await _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
      );
    }
  }

  Future<void> _handleBotGameReward(DominoGameMatch game) async {
    if (game.quotasCollected) return;
    if (_botGameRewardHandled) return;
    _botGameRewardHandled = true;

    final betAmount = game.betAmount ?? 0;
    if (betAmount <= 0 || _currentUser == null) return;

    final iWon = game.winnerId == _currentUser!.uid;
    if (!iWon) return;

    final isCoins = (game.currencyType) == 'coins';
    final commission = isCoins ? 0.30 : 0.10;
    final prize = ((betAmount * game.numberOfPlayers) * (1 - commission)).floor();

    if (isCoins) {
      await _firestoreService.incrementUserCoins(_currentUser!.uid, prize);
    } else {
      await _firestoreService.incrementUserDiamonds(_currentUser!.uid, prize);
      final netGain = prize - betAmount;
      if (netGain > 0) {
        await _firestoreService.incrementUserDiamondsEarned(_currentUser!.uid, netGain);
      }
    }
  }

  bool _isOpponent(DominoGameMatch game) {
    final turnNum = int.tryParse(game.currentTurn.replaceAll('player', '')) ?? 0;
    final turnPlayerId = game.playerIdOf(turnNum);
    if (turnPlayerId == null || !turnPlayerId.startsWith('bot_')) return false;
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      final pid = game.playerIdOf(p);
      if (pid != null && !pid.startsWith('bot_')) return pid == _currentUser!.uid;
    }
    return false;
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

  void _onBotActionDone({bool success = true, required DominoGameMatch fallback}) {
    if (!mounted) return;
    setState(() => _isOpponentThinking = false);
    final latest = _lastServerGame ?? _currentGame ?? fallback;
    if (latest.isPlayerTurn(_currentUser!.uid)) return;
    if (_isOpponent(latest)) {
      _scheduleOpponentTurn(latest);
    }
  }

  void _makeBotMove(DominoGameMatch snapshot) {
    if (!mounted) return;
    final game = _lastServerGame ?? snapshot;
    final botNum = int.tryParse(game.currentTurn.replaceAll('player', '')) ?? 0;
    if (botNum == 0) {
      setState(() => _isOpponentThinking = false);
      return;
    }
    final botId = game.playerIdOf(botNum);
    if (botId == null || !botId.startsWith('bot_')) {
      setState(() => _isOpponentThinking = false);
      return;
    }

    final botHand = game.getHand(botNum);
    final state = game.gameState;

    if (state.chain.isEmpty) {
      String? tileId;
      int maxDouble = -1;
      for (final id in botHand) {
        final t = state.tiles[id];
        if (t != null && t['left'] == t['right'] && t['left']! > maxDouble) {
          maxDouble = t['left']!;
          tileId = id;
        }
      }
      if (tileId == null && botHand.isNotEmpty) {
        final shuffled = List<String>.from(botHand)..shuffle(_random);
        tileId = shuffled.first;
      }
      if (tileId == null) {
        setState(() => _isOpponentThinking = false);
        return;
      }
      _gameService.playTile(
        gameId: _activeGameId!,
        playerId: botId,
        tileId: tileId,
        side: 'right',
      ).then((success) {
        _onBotActionDone(success: success, fallback: game);
      }).catchError((_) {
        _onBotActionDone(success: false, fallback: game);
      });
      return;
    }

    final playable = botHand.where((id) => state.canPlay(id)).toList();
    final isBetMode = widget.matchType == 'Apuesta';

    if (playable.isNotEmpty) {
      String tileId;
      String side;

      if (isBetMode) {
        final pick = _pickSmartMove(state, botHand, playable, botNum, game);
        tileId = pick.tileId;
        side = pick.side;
      } else {
        playable.shuffle(_random);
        tileId = playable.first;
        final tileData = state.tiles[tileId]!;
        final tl = tileData['left']!;
        final tr = tileData['right']!;
        final canLeft = tl == state.leftOpen || tr == state.leftOpen;
        final canRight = tl == state.rightOpen || tr == state.rightOpen;
        if (canLeft && !canRight) {
          side = 'left';
        } else if (canRight && !canLeft) {
          side = 'right';
        } else {
          side = _random.nextBool() ? 'left' : 'right';
        }
      }

      _gameService.playTile(
        gameId: _activeGameId!,
        playerId: botId,
        tileId: tileId,
        side: side,
      ).then((success) {
        _onBotActionDone(success: success, fallback: game);
      }).catchError((_) {
        _onBotActionDone(success: false, fallback: game);
      });
    } else if (state.boneyard.isNotEmpty) {
      _gameService.drawFromBoneyard(gameId: _activeGameId!, playerId: botId).then((_) {
        _onBotActionDone(fallback: game);
      }).catchError((_) {
        _onBotActionDone(success: false, fallback: game);
      });
    } else {
      _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: botId,
      ).then((_) {
        _onBotActionDone(fallback: game);
      }).catchError((_) {
        _onBotActionDone(success: false, fallback: game);
      });
    }
  }

  ({String tileId, String side}) _pickSmartMove(
    DominoGameState state,
    List<String> botHand,
    List<String> playable,
    int botNum,
    DominoGameMatch game,
  ) {
    final humanHand = <String>[];
    final allyBotHands = <List<String>>[];
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      if (p == botNum) continue;
      final pid = game.playerIdOf(p);
      final hand = game.getHand(p);
      if (pid != null && pid.startsWith('bot_')) {
        allyBotHands.add(hand);
      } else {
        humanHand.addAll(hand);
      }
    }

    ({String tileId, String side})? bestMove;
    int bestScore = -99999;

    for (final tid in playable) {
      final td = state.tiles[tid]!;
      final tl = td['left']!;
      final tr = td['right']!;
      final isDouble = tl == tr;

      for (final s in ['left', 'right']) {
        final openVal = s == 'left' ? state.leftOpen : state.rightOpen;
        if (openVal == null) continue;
        if (tl != openVal && tr != openVal) continue;

        int newOpen;
        if (isDouble) {
          newOpen = tl;
        } else if (s == 'left') {
          newOpen = (tr == openVal) ? tl : tr;
        } else {
          newOpen = (tl == openVal) ? tr : tl;
        }

        final newLeft = s == 'left' ? newOpen : state.leftOpen!;
        final newRight = s == 'right' ? newOpen : state.rightOpen!;

        final remaining = botHand.where((id) => id != tid).toList();

        if (remaining.isEmpty) return (tileId: tid, side: s);

        int score = 0;

        int botPlayable = 0;
        for (final id in remaining) {
          final t = state.tiles[id]!;
          if (t['left'] == newLeft || t['right'] == newLeft ||
              t['left'] == newRight || t['right'] == newRight) {
            botPlayable++;
          }
        }
        score += botPlayable * 15;

        int allyPlayable = 0;
        for (final allyHand in allyBotHands) {
          for (final id in allyHand) {
            final t = state.tiles[id]!;
            if (t['left'] == newLeft || t['right'] == newLeft ||
                t['left'] == newRight || t['right'] == newRight) {
              allyPlayable++;
            }
          }
        }
        score += allyPlayable * 10;

        int humanPlayable = 0;
        for (final id in humanHand) {
          final t = state.tiles[id]!;
          if (t['left'] == newLeft || t['right'] == newLeft ||
              t['left'] == newRight || t['right'] == newRight) {
            humanPlayable++;
          }
        }
        score -= humanPlayable * 25;

        if (humanPlayable == 0 && state.boneyard.isEmpty) score += 800;
        if (humanPlayable == 0) score += 200;

        score += (tl + tr);

        if (isDouble) score += 5;

        if (score > bestScore) {
          bestScore = score;
          bestMove = (tileId: tid, side: s);
        }
      }
    }

    if (bestMove != null) return bestMove;

    final tid = playable.first;
    final td = state.tiles[tid]!;
    final canLeft = td['left'] == state.leftOpen || td['right'] == state.leftOpen;
    return (tileId: tid, side: canLeft ? 'left' : 'right');
  }

  int _requiredOpeningDouble(DominoGameState state, List<String> hand) {
    int maxDouble = -1;
    for (final id in hand) {
      final t = state.tiles[id];
      if (t != null && t['left'] == t['right'] && t['left']! > maxDouble) {
        maxDouble = t['left']!;
      }
    }
    return maxDouble;
  }

  bool _isTilePlayable(String tileId, DominoGameState state, List<String> myHand) {
    if (state.chain.isEmpty) {
      final req = _requiredOpeningDouble(state, myHand);
      if (req == -1) return true;
      final t = state.tiles[tileId];
      return t != null && t['left'] == t['right'] && t['left'] == req;
    }
    return state.canPlay(tileId);
  }

  void _onTileTap(String tileId) {
    final game = _currentGame;
    if (game == null || !game.isPlayerTurn(_currentUser!.uid)) return;

    final state = game.gameState;
    final myHand = game.getHand(_myPlayerNumber);

    if (state.chain.isEmpty) {
      final req = _requiredOpeningDouble(state, myHand);
      if (req != -1) {
        final td = state.tiles[tileId];
        if (td == null || !(td['left'] == td['right'] && td['left'] == req)) {
          _showSnack('Debes abrir con el doble $req-$req');
          return;
        }
      }
      setState(() => _selectedTileId = tileId);
      _placeSelectedTile(tileId, 'right');
      return;
    }

    if (!state.canPlay(tileId)) {
      _showSnack('Esta ficha no conecta con los extremos');
      return;
    }

    setState(() => _selectedTileId = tileId);

    final tileData = state.tiles[tileId]!;
    final canLeft  = tileData['left'] == state.leftOpen  || tileData['right'] == state.leftOpen;
    final canRight = tileData['left'] == state.rightOpen || tileData['right'] == state.rightOpen;

    if (canLeft && canRight && state.leftOpen != state.rightOpen) {
      setState(() => _needsSideChoice = true);
    } else {
      _placeSelectedTile(tileId, canRight ? 'right' : 'left');
    }
  }

  void _placeSelectedTile(String tileId, String side) async {
    final game = _currentGame;
    if (game == null) return;

    final td = game.gameState.tiles[tileId];
    if (td != null) {
      final dx = side == 'left' ? -2.0 : 2.0;
      _playerFlyAnim = Tween<Offset>(begin: Offset(dx, 1.5), end: Offset.zero)
          .animate(CurvedAnimation(parent: _playerFlyAnimCtrl, curve: Curves.easeOut));
      setState(() => _flyingTileData = (left: td['left']!, right: td['right']!));
      _playerFlyAnimCtrl.forward(from: 0);
    }

    setState(() {
      _selectedTileId = null;
      _needsSideChoice = false;
    });

    if (_flyingTileData != null) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (mounted) setState(() => _flyingTileData = null);
    }

    final baseGame = _lastServerGame ?? game;
    final optimistic = _applyTileLocally(baseGame, tileId, side);
    if (optimistic != null) {
      setState(() => _currentGame = optimistic);
      _scrollChainToEnd();
    }

    final success = await _gameService.playTile(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
      tileId: tileId,
      side: side,
    );

    if (!success && mounted) {
      setState(() => _currentGame = _lastServerGame ?? game);
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
    if (_isDrawing) return;
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

    setState(() { _isDrawing = true; _boneyardFlyActive = true; });
    _boneyardFlyAnimCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _boneyardFlyActive = false);

    try {
      final ok = await _gameService.drawFromBoneyard(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
      );
      if (!ok && mounted) setState(() => _isDrawing = false);
    } catch (_) {
      if (mounted) setState(() => _isDrawing = false);
    }
  }

  Future<void> _passTurn() async {
    await _gameService.passTurn(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
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
      setState(() => _gameEnded = true);
      await _gameService.abandonGame(gameId: _activeGameId!, playerId: _currentUser!.uid);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showGameOverDialog(DominoGameMatch game) {
    if (!mounted) return;
    _recordGameHistory(game);
    setState(() {
      _gameOverGame = game;
      _showGameOverBanner = true;
    });
  }

  Future<void> _recordGameHistory(DominoGameMatch game) async {
    try {
      final uid = _currentUser!.uid;
      final iWon = game.winnerId == uid;
      final result = iWon ? GameResultModel.win : GameResultModel.loss;
      final dur = game.startedAt != null
          ? DateTime.now().difference(game.startedAt!).inMinutes
          : 1;
      final opponentName = _myPlayerNumber == 1
          ? (game.guestName ?? 'Oponente')
          : game.hostName;
      await _firestoreService.recordGameMatch(
        userId: uid,
        gameType: GameTypeModel.domino,
        result: result,
        pointsEarned: iWon ? 20 : -5,
        durationMinutes: dur > 0 ? dur : 1,
        opponentName: opponentName,
        additionalData: {
          'matchType': widget.matchType,
          'mode': 'online',
          'betAmount': game.betAmount,
          'currencyType': game.currencyType,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error recording domino history: $e');
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
          actionsPadding: EdgeInsets.zero,
          actions: [
            if (inGame)
              IconButton(
                padding: EdgeInsets.zero,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    if (_unreadChatCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _unreadChatCount > 9 ? '9+' : '$_unreadChatCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  _chatKey.currentState?.toggleChat();
                  if (mounted) setState(() => _unreadChatCount = 0);
                },
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
            if (_activeGameId != null)
              GameChatWidget(
                key: _chatKey,
                gameId: _activeGameId!,
                collectionName: 'domino_games',
                currentUserId: _currentUser?.uid ?? '',
                currentUserName: _currentUser?.displayName ?? 'Jugador',
                showFloatingBubbles: false,
                onUnreadCountChanged: (count) {
                  if (mounted) setState(() => _unreadChatCount = count);
                },
                onNewMessageFromOther: (senderId, _) {
                  if (!mounted) return;
                  setState(() => _lastMsgSenderId = senderId);
                  _msgBubbleTimer?.cancel();
                  _msgBubbleTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _lastMsgSenderId = null);
                  });
                },
                onNewMessageWithText: (senderId, _, text) {
                  if (!mounted) return;
                  setState(() {
                    _lastMsgSenderId = senderId;
                    _lastMsgText = text;
                  });
                  _msgBubbleTimer?.cancel();
                  _msgBubbleTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() { _lastMsgSenderId = null; _lastMsgText = null; });
                  });
                },
                onOwnMessageSent: (text) {
                  if (!mounted) return;
                  setState(() => _ownMsgText = text);
                  _ownMsgBubbleTimer?.cancel();
                  _ownMsgBubbleTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) setState(() => _ownMsgText = null);
                  });
                },
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
              onPressed: () => _cancelMatchmaking(),
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

    final opponents = <({int playerNum, String name, int handCount, int score, bool isActive, String? photoUrl, String? playerId})>[];
    final nPlayers = game.numberOfPlayers;
    final rotationOrder = <int>[];
    int cur = (_myPlayerNumber % nPlayers) + 1;
    for (int i = 0; i < nPlayers - 1; i++) {
      rotationOrder.add(cur);
      cur = (cur % nPlayers) + 1;
    }
    for (final p in rotationOrder.reversed) {
      final pid = game.playerIdOf(p);
      final isBot = pid != null && pid.startsWith('bot_');
      final isRoundWinner = _showRoundEndBanner && !_roundWasBlocked && p == _roundWinnerNum;
      opponents.add((
        playerNum: p,
        name: game.playerNameOf(p),
        handCount: isRoundWinner ? 0 : game.gameState.handOf(p).length,
        score: scores['player$p'] ?? 0,
        isActive: game.currentTurn == 'player$p',
        photoUrl: isBot ? null : (p == 1 ? game.hostPhotoUrl : p == 2 ? game.guestPhotoUrl : null),
        playerId: pid,
      ));
    }
    final myScore = scores['player$_myPlayerNumber'] ?? 0;

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _buildOnlineLandscapeHeader(opponents: opponents, activeSpeakerId: _lastMsgSenderId, activeSpeakerText: _lastMsgText),
              _buildOnlineChainArea(state, canDraw: canDraw),
              _buildOnlineLandscapeFooter(
                hand: myHand,
                state: state,
                isMyTurn: isMyTurn,
                canDraw: canDraw,
                canPass: canPass,
              ),
            ],
          ),
          Positioned(
            left: 8,
            bottom: 92.0 + (state.boneyard.isNotEmpty ? 54 : 0) + 10,
            child: _buildMyPanel(isMyTurn, myScore),
          ),
          if (_ownMsgText != null)
            Positioned(
              right: 12,
              bottom: 92.0 + (state.boneyard.isNotEmpty ? 54 : 0) + 10,
              child: _buildChatBubble(_ownMsgText!, isMe: true),
            ),
          for (final entry in opponents.asMap().entries)
            if (_lastMsgText != null && entry.value.playerId == _lastMsgSenderId)
              Positioned(
                top: 80,
                left: entry.key * (MediaQuery.of(context).size.width / opponents.length) + 8,
                child: _buildChatBubble(_lastMsgText!, isMe: false),
              ),
          if (_showRoundEndBanner) _buildRoundEndOverlay(),
          if (_showGameOverBanner && _gameOverGame != null) _buildGameOverOverlay(_gameOverGame!),
          if (_flyingTileData != null) _buildPlayerFlyOverlay(),
          if (_boneyardFlyActive) _buildBoneyardFlyOverlay(),
        ],
      ),
    );
  }

  Widget _buildPlayerFlyOverlay() {
    final t = _flyingTileData!;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: SlideTransition(
            position: _playerFlyAnim,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 18, spreadRadius: 2)],
              ),
              child: DominoTileWidget(left: t.left, right: t.right, width: 46, height: 84),
            ),
          ),
        ),
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

    final roundWinnerNum = _roundWinnerNum;
    final wasBlocked = _roundWasBlocked;

    final String title = iWon ? 'Ronda ganada' : wasBlocked ? 'Bloqueado' : 'Ronda perdida';
    final Color titleColor = iWon ? _accentOrange : wasBlocked ? Colors.amber[600]! : Colors.red[400]!;

    final opponentTiles = <({String name, List<({int left, int right})> tiles, int pips})>[];
    for (int p = 1; p <= prevGame.numberOfPlayers; p++) {
      if (!wasBlocked && p == roundWinnerNum) continue;
      final hand = prevGame.gameState.handOf(p);
      if (hand.isEmpty) continue;
      final tileWidgets = hand.map((id) {
        final data = prevGame.gameState.tiles[id];
        return (left: data?['left'] ?? 0, right: data?['right'] ?? 0);
      }).toList();
      final pips = tileWidgets.fold(0, (s, t) => s + t.left + t.right);
      final name = p == _myPlayerNumber
          ? (_myName ?? 'Yo')
          : prevGame.playerNameOf(p);
      opponentTiles.add((name: name, tiles: tileWidgets, pips: pips));
    }

    final scoreLines = StringBuffer();
    for (int p = 1; p <= newGame.numberOfPlayers; p++) {
      final name = p == _myPlayerNumber ? (_myName ?? 'Yo')
          : prevGame.playerNameOf(p);
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
                    children: List.generate(opp.tiles.length, (i) {
                      final t = opp.tiles[i];
                      final n = opp.tiles.length;
                      final start = n <= 1 ? 0.0 : (i / n) * 0.7;
                      final end = min(start + 0.5, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1400),
                          curve: Interval(start, end, curve: Curves.easeInOut),
                          builder: (_, value, __) {
                            final revealed = value >= 0.5;
                            final scaleX = revealed
                                ? (value - 0.5) * 2
                                : 1.0 - value * 2;
                            return Transform(
                              transform: Matrix4.identity()
                                ..scale(scaleX.clamp(0.01, 1.0), 1.0),
                              alignment: Alignment.center,
                              child: DominoTileWidget(
                                left: revealed ? t.left : 0,
                                right: revealed ? t.right : 0,
                                width: 22,
                                height: 40,
                                faceDown: !revealed,
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _advanceToNextRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                child: Text('Siguiente ronda ($_roundEndCountdown)', style: const TextStyle(fontSize: 13)),
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
      final name = p == _myPlayerNumber ? (_myName ?? 'Yo') : game.playerNameOf(p);
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
                () {
                  final bet = game.betAmount!;
                  final commission = game.currencyType == 'diamonds' ? 0.10 : 0.30;
                  final prize = ((bet * game.numberOfPlayers) * (1 - commission)).floor();
                  return iWon ? '+$prize ${game.currencyType}' : '-$bet ${game.currencyType}';
                }(),
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

  Widget _buildMyPanel(bool isActive, int myScore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: _accentOrange, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, color: Colors.white70, size: 20),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_myName ?? 'Yo', style: const TextStyle(color: Colors.white70, fontSize: 9)),
              Text(
                '$myScore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isActive && _turnTimer != null)
                Text(
                  '⏱ $_turnSecondsLeft"',
                  style: TextStyle(
                    color: _turnSecondsLeft <= 10 ? Colors.red[300] : Colors.green[300],
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isMe}) {
    final isEmoji = text.characters.length <= 3 && !text.contains(RegExp(r'[a-zA-Z0-9]'));
    return TweenAnimationBuilder<double>(
      key: ValueKey('bubble_${isMe ? 'me' : 'other'}_$text'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: EdgeInsets.symmetric(horizontal: isEmoji ? 6 : 10, vertical: isEmoji ? 4 : 6),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFF57F17) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isEmoji ? 28 : 13,
            color: isMe ? Colors.white : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildOnlineLandscapeHeader({
    required List<({int playerNum, String name, int handCount, int score, bool isActive, String? photoUrl, String? playerId})> opponents,
    String? activeSpeakerId,
    String? activeSpeakerText,
  }) {
    final tileW = opponents.length > 1 ? 16.0 : 20.0;
    final tileH = opponents.length > 1 ? 30.0 : 38.0;

    return Container(
      height: 80,
      color: const Color(0xFF0D2010),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      clipBehavior: Clip.none,
      child: Row(
        children: opponents.map((opp) {
          final isSpeaking = activeSpeakerId != null && opp.playerId == activeSpeakerId;
          final bubbleText = isSpeaking ? activeSpeakerText : null;
          return Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: opp.isActive ? Colors.white12 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: opp.isActive ? Border.all(color: _accentOrange, width: 1.5) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              opp.name,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isSpeaking && bubbleText == null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.chat_bubble, color: Colors.green, size: 12),
                            ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: opp.score > 0 ? _accentOrange : Colors.white24,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${opp.score}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: List.generate(
                            opp.handCount,
                            (_) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _buildFaceDownTile(width: tileW, height: tileH),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
          Expanded(child: _buildOnlinePlayerArea(hand, state, isMyTurn)),
          if (isMyTurn && canPass) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 90,
              child: _onlineActionBtn('Pasar', Icons.skip_next, Colors.orange[700]!, _passTurn),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _buildOnlineChainArea(DominoGameState state, {required bool canDraw}) {
    final showHints = _needsSideChoice && _selectedTileId != null;
    final openingIdx = state.openingTileId != null
        ? state.chain.indexWhere((t) => t.id == state.openingTileId)
        : -1;
    return Expanded(
      child: Container(
        color: const Color(0xFF429936),
        child: Column(
          children: [
            Expanded(
              child: DominoBoardWebView(
                tiles: state.chain
                    .map<DominoChainEntry>((t) => DominoChainEntry(left: t.displayLeft, right: t.displayRight))
                    .toList(),
                openingIndex: openingIdx,
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
            if (state.boneyard.isNotEmpty) _buildBoneyardRow(canDraw, state.boneyard.length),
          ],
        ),
      ),
    );
  }

  Widget _buildBoneyardRow(bool canDraw, int tileCount) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        children: List.generate(tileCount, (i) {
          return GestureDetector(
            onTap: canDraw ? _drawFromBoneyard : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: canDraw ? 1.0 : 0.5,
                child: const DominoTileWidget(
                  left: 0,
                  right: 0,
                  width: 24,
                  height: 44,
                  faceDown: true,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBoneyardFlyOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, 0.5),
          child: SlideTransition(
            position: _boneyardFlyAnim,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 18, spreadRadius: 2)],
              ),
              child: const DominoTileWidget(left: 0, right: 0, width: 40, height: 72, faceDown: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlinePlayerArea(List<String> hand, DominoGameState state, bool isMyTurn) {
    final req = isMyTurn ? _requiredOpeningDouble(state, hand) : -1;
    final isOpeningMove = state.chain.isEmpty && req != -1;

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
          final isPlayable = isMyTurn && _isTilePlayable(tileId, state, hand);
          final isSelected = _selectedTileId == tileId;
          final isMandatory = isOpeningMove && td['left'] == td['right'] && td['left'] == req;

          final tileWidget = GestureDetector(
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
                  isMandatory: isMandatory,
                ),
              ),
            ),
          );

          if (!isMandatory) return tileWidget;

          return AnimatedBuilder(
            animation: _mandatoryTileAnimCtrl,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: _mandatoryTileAnimCtrl.value * 0.8),
                    blurRadius: 18 * _mandatoryTileAnimCtrl.value,
                    spreadRadius: 5 * _mandatoryTileAnimCtrl.value,
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

