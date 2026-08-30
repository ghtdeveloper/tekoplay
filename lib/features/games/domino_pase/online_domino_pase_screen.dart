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
import '../../../core/service/auth_service.dart';
import '../../../core/service/domino_pase_game_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/payment_service.dart';
import '../../../core/utils/game_result.dart';
import '../../coins/diamond_purchase_dialog.dart';
import '../../../core/utils/game_type.dart';
import '../../../core/widgets/domino_board_widgets.dart';
import '../../../core/widgets/domino_webview_board.dart';
import '../../adds/banner_ad_widget.dart';
import '../../../core/widgets/game_chat_widget.dart';
import 'domino_pase_tutorial_screen.dart';
import '../../settings/settings_screen.dart';
import '../../../generated/l10n.dart';

enum _PaseOnlineState { playerCountSelection, matchmaking, waitingRoom, gameActive }

class OnlineDominoPaseScreen extends StatefulWidget {
  final String matchType;
  const OnlineDominoPaseScreen({super.key, required this.matchType});

  @override
  State<OnlineDominoPaseScreen> createState() => _OnlineDominoPaseScreenState();
}

class _OnlineDominoPaseScreenState extends State<OnlineDominoPaseScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final DominoPaseGameService _gameService = DominoPaseGameService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<GameChatWidgetState> _chatKey = GlobalKey<GameChatWidgetState>();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  _PaseOnlineState _screenState = _PaseOnlineState.playerCountSelection;
  int _selectedPlayerCount = 2;
  int? _selectedBetAmount;

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
  int? _userDiamonds;

  ({int left, int right})? _flyingTileData;
  late AnimationController _playerFlyAnimCtrl;
  late Animation<Offset> _playerFlyAnim;
  late AnimationController _mandatoryTileAnimCtrl;

  String? _selectedTileId;
  bool _needsSideChoice = false;
  bool _gameEnded = false;
  bool _autoPassPending = false;
  Timer? _turnTimer;
  int _turnSecondsLeft = 30;
  Timer? _opponentTimer;
  int _opponentSecondsLeft = 30;
  Timer? _awayTimer;
  int _awaySecondsLeft = 60;
  int _opponentConsecutiveTimeouts = 0;
  String? _lastTimeoutPlayer;
  final ScrollController _chainScrollCtrl = ScrollController();
  bool _isScreenKeepOnActive = false;
  int _unreadChatCount = 0;

  int? _passedPlayerNum;
  Timer? _passIndicatorTimer;
  int _lastConsecutivePasses = 0;

  String? _lastMsgSenderId;
  String? _lastMsgText;
  String? _ownMsgText;
  Timer? _msgBubbleTimer;
  Timer? _ownMsgBubbleTimer;

  bool _gameOverMinimized = false;
  bool _rematchRequested = false;
  bool _waitingForRematch = false;
  DateTime? _gameStartedAt;

  static const Color _accentColor = Color(0xFF9C27B0);
  static const Color _panelColor = Colors.white;

  @override
  void initState() {
    super.initState();
    DominoSpriteSheet.preload().then((_) { if (mounted) setState(() {}); });

    _playerFlyAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _playerFlyAnim = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _playerFlyAnimCtrl, curve: Curves.easeOut));

    _mandatoryTileAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        _showLoginRequiredDialog();
      }
    });

    _loadUserData();
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
        _awaySecondsLeft = 25;
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

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFFEC7A34)),
              const SizedBox(height: 16),
              Text(
                S.of(context).loginRequired,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                '${S.of(context).toUse} ${S.of(context).online} ${S.of(context).youNeedToLogin}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      child: Text(S.of(context).cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.isAnonymous) {
                          if (mounted) Navigator.of(context).pop();
                        } else {
                          _loadUserData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC7A34),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(S.of(context).login),
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
        _userDiamonds = (d['diamonds'] as num?)?.toInt() ?? 0;
      });
    });
  }

  void _showDiamondPurchaseDialog() {
    showDiamondPurchaseDialog(
      context,
      onPurchase: (diamondAmount, price) {
        _processDiamondPurchase(diamondAmount, price);
      },
    );
  }

  Future<void> _processDiamondPurchase(int diamonds, double price) async {
    final notAvailableMsg = S.of(context).googlePayNotAvailable;
    final diamondsLabel = S.of(context).diamonds;
    final successMsg = S.of(context).purchaseSuccessful;
    final errorMsg = S.of(context).paymentProcessingError;
    try {
      final paymentService = PaymentService();
      final canPay = await paymentService.canMakePayments();
      if (!canPay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notAvailableMsg), backgroundColor: Colors.orange),
        );
        return;
      }
      final result = await paymentService.makePayment(
        label: '$diamonds $diamondsLabel',
        amount: price,
        productId: 'diamonds_$diamonds',
      );
      if (result != null && result['success'] == true) {
        await AuthService().addDiamonds(diamonds);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$successMsg +$diamonds $diamondsLabel'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error en compra: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
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
    if (_activeGameId != null &&
        (_screenState == _PaseOnlineState.matchmaking || _screenState == _PaseOnlineState.waitingRoom) &&
        !_navigated) {
      _firestore.collection('domino_pase_games').doc(_activeGameId!).update({
        'status': 'cancelled',
        'finishedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _matchmakingTimer?.cancel();
    _turnTimer?.cancel();
    _opponentTimer?.cancel();
    _awayTimer?.cancel();
    _msgBubbleTimer?.cancel();
    _ownMsgBubbleTimer?.cancel();
    _passIndicatorTimer?.cancel();
    _chainScrollCtrl.dispose();
    _playerFlyAnimCtrl.dispose();
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
    setState(() => _screenState = _PaseOnlineState.playerCountSelection);
    if (gameId != null) {
      try {
        await _firestore.collection('domino_pase_games').doc(gameId).update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _startMatchmaking() async {
    if (_currentUser == null) return;
    if (_selectedBetAmount == null) return;

    final required = DominoPaseGameService.requiredBalance(_selectedBetAmount!);
    final balance = _userDiamonds ?? 0;
    if (balance < required) {
      _showSnack(S.of(context).insufficientDiamondsForRematch(required));
      return;
    }

    setState(() {
      _screenState = _PaseOnlineState.matchmaking;
      _matchmakingSeconds = 0;
    });

    await _enableWakeLock();

    _matchmakingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _matchmakingSeconds++);

      if (_matchmakingSeconds % 5 == 0 && !_navigated && _screenState == _PaseOnlineState.matchmaking) {
        _retryMatchmaking();
      }

      if (_matchmakingSeconds >= 90 && !_navigated) {
        t.cancel();
        _showSnack(S.of(context).opponentNotFound);
        _cancelMatchmaking();
      }
    });

    await _tryJoinOrCreate();
  }

  Future<void> _tryJoinOrCreate() async {
    if (!mounted || _navigated) return;
    try {
      final games = await _gameService.findWaitingGames(
        numberOfPlayers: _selectedPlayerCount,
        betAmount: _selectedBetAmount,
      );
      final uid = _currentUser!.uid;
      final eligible = games.where((g) {
        if (g.hostId == uid) return false;
        if (g.guestId == uid || g.guest2Id == uid || g.guest3Id == uid) return false;
        return true;
      }).toList();
      eligible.sort((a, b) => b.currentPlayerCount.compareTo(a.currentPlayerCount));

      if (eligible.isNotEmpty && !_navigated) {
        final game = eligible.first;
        final joined = await _gameService.joinGame(
          gameId: game.id,
          guestId: uid,
          guestName: _myName ?? 'Jugador',
          guestPhotoUrl: _myPhotoUrl,
        );
        if (joined && !_navigated) {
          final doc = await _firestore.collection('domino_pase_games').doc(game.id).get();
          final updatedGame = doc.exists ? DominoGameMatch.fromFirestore(doc) : null;
          if (updatedGame != null && updatedGame.isActive) {
            _navigated = true;
            _matchmakingTimer?.cancel();
            final myNum = updatedGame.getPlayerNumber(uid);
            _openGame(game.id, myNum > 0 ? myNum : 2);
          } else {
            setState(() {
              _activeGameId = game.id;
              _screenState = _PaseOnlineState.waitingRoom;
            });
            _listenForPlayers(game.id);
          }
          return;
        }
      }

      if (!_navigated) {
        final result = await _gameService.createGame(
          hostId: uid,
          hostName: _myName ?? 'Jugador',
          hostPhotoUrl: _myPhotoUrl,
          betAmount: _selectedBetAmount!,
          numberOfPlayers: _selectedPlayerCount,
          isOnlineMatchmaking: true,
        );
        if (result != null && !_navigated) {
          setState(() {
            _activeGameId = result['gameId'];
            _screenState = _PaseOnlineState.waitingRoom;
          });
          _listenForPlayers(result['gameId']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Pase matchmaking error: $e');
    }
  }

  Future<void> _retryMatchmaking() async {
    if (!mounted || _navigated || _activeGameId == null || _isRetrying) return;
    _isRetrying = true;
    try {
      final currentDoc = await _firestore.collection('domino_pase_games').doc(_activeGameId!).get();
      if (!currentDoc.exists || !mounted || _navigated) return;
      final currentGame = DominoGameMatch.fromFirestore(currentDoc);

      if (currentGame.status == 'cancelled') {
        _gameSubscription?.cancel();
        _activeGameId = null;
        if (mounted) {
          setState(() => _screenState = _PaseOnlineState.matchmaking);
          await _tryJoinOrCreate();
        }
        return;
      }

      if (currentGame.isActive) return;

      final uid = _currentUser!.uid;
      final amHost = currentGame.hostId == uid;

      if (amHost && currentGame.currentPlayerCount == 1) {
        final games = await _gameService.findWaitingGames(
          numberOfPlayers: _selectedPlayerCount,
          betAmount: _selectedBetAmount,
        );
        final eligible = games.where((g) {
          if (g.hostId == uid) return false;
          if (g.guestId == uid || g.guest2Id == uid || g.guest3Id == uid) return false;
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
            try {
              await _firestore.collection('domino_pase_games').doc(_activeGameId!).update({
                'status': 'cancelled',
                'finishedAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}

            final doc = await _firestore.collection('domino_pase_games').doc(target.id).get();
            final updatedGame = doc.exists ? DominoGameMatch.fromFirestore(doc) : null;
            if (updatedGame != null && updatedGame.isActive) {
              _navigated = true;
              _matchmakingTimer?.cancel();
              final myNum = updatedGame.getPlayerNumber(uid);
              _openGame(target.id, myNum > 0 ? myNum : 2);
            } else {
              setState(() {
                _activeGameId = target.id;
                _screenState = _PaseOnlineState.waitingRoom;
              });
              _listenForPlayers(target.id);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Retry matchmaking error: $e');
    } finally {
      _isRetrying = false;
    }
  }

  void _listenForPlayers(String gameId) {
    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted || _navigated) return;
      if (game == null) return;

      if (game.status == 'cancelled') {
        _gameSubscription?.cancel();
        _activeGameId = null;
        if (mounted && !_navigated) {
          setState(() => _screenState = _PaseOnlineState.matchmaking);
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

  void _openGame(String gameId, int playerNumber) {
    setState(() {
      _activeGameId = gameId;
      _myPlayerNumber = playerNumber;
      _screenState = _PaseOnlineState.gameActive;
      _gameEnded = false;
      _selectedTileId = null;
      _needsSideChoice = false;
      _rematchRequested = false;
      _waitingForRematch = false;
      _gameStartedAt = DateTime.now();
    });

    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (!mounted) return;
      if (game != null) _lastServerGame = game;

      if (game == null || _gameEnded) {
        setState(() => _currentGame = game);
        if (game != null && _gameEnded && !_waitingForRematch) {
          final rematchGameId =
              game.gameSettings?['rematchGameId'] as String?;
          if (rematchGameId != null && _rematchRequested) {
            setState(() => _waitingForRematch = true);
            _openGame(rematchGameId, _myPlayerNumber);
          }
        }
        return;
      }

      final serverPlayerNum = game.getPlayerNumber(_currentUser!.uid);

      if (game.isFinished || game.isAbandoned) {
        _stopTurnTimer();
        _stopOpponentTimer();
        setState(() { _currentGame = game; _gameEnded = true; });
        _disableWakeLock();
        if (game.isFinished) {
          _gameService.distributeRewards(gameId: gameId);
        }
        _showGameOverDialog(game);
        return;
      }

      if (serverPlayerNum == 0) {
        final elapsed = _gameStartedAt != null
            ? DateTime.now().difference(_gameStartedAt!).inSeconds
            : 999;
        if (elapsed < 5) return;
        setState(() { _gameEnded = true; });
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (serverPlayerNum != _myPlayerNumber) {
        _myPlayerNumber = serverPlayerNum;
      }

      final newPasses = game.gameState.consecutivePasses;
      if (newPasses > _lastConsecutivePasses && _lastConsecutivePasses >= 0) {
        final currentTurnStr = game.currentTurn;
        final currentTurnNum = int.tryParse(currentTurnStr.replaceAll('player', '')) ?? 0;
        final nPlayers = game.numberOfPlayers;
        final passedNum = ((currentTurnNum - 2) % nPlayers) + 1;
        if (passedNum != _myPlayerNumber) {
          setState(() => _passedPlayerNum = passedNum);
          _passIndicatorTimer?.cancel();
          _passIndicatorTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _passedPlayerNum = null);
          });
        }
      }
      _lastConsecutivePasses = newPasses;

      setState(() => _currentGame = game);

      final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
      if (isMyTurn) {
        _stopOpponentTimer();
        final myHand = game.getHand(_myPlayerNumber);
        final state = game.gameState;
        if (!state.canPlayAny(myHand)) {
          if (!_autoPassPending) {
            _autoPassPending = true;
            Future.delayed(const Duration(milliseconds: 2000), () {
              _autoPassPending = false;
              if (mounted && !_gameEnded) {
                _showSnack(S.of(context).passAutomatic);
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
        _opponentConsecutiveTimeouts = 0;
        _lastTimeoutPlayer = null;
        _startOpponentTimer();
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

  void _startOpponentTimer() {
    _opponentTimer?.cancel();
    final currentTurn = _currentGame?.currentTurn;
    if (currentTurn != _lastTimeoutPlayer) {
      _opponentConsecutiveTimeouts = 0;
      _lastTimeoutPlayer = currentTurn;
    }
    _opponentSecondsLeft = 30;
    _opponentTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameEnded) {
        t.cancel();
        return;
      }
      setState(() => _opponentSecondsLeft--);
      if (_opponentSecondsLeft <= 0) {
        t.cancel();
        _handleOpponentTimeout();
      }
    });
  }

  void _stopOpponentTimer() {
    _opponentTimer?.cancel();
    _opponentTimer = null;
  }

  void _handleOpponentTimeout() {
    _opponentConsecutiveTimeouts++;
    if (_opponentConsecutiveTimeouts >= 2) {
      _abandonInactiveOpponent();
      return;
    }
    _autoPlayForOpponent();
  }

  Future<void> _autoPlayForOpponent() async {
    if (_activeGameId == null || _gameEnded) return;
    final game = _currentGame;
    if (game == null) return;
    final turnStr = game.currentTurn;
    final turnNum = int.tryParse(turnStr.replaceAll('player', '')) ?? 0;
    final opponentId = game.playerIdOf(turnNum);
    if (opponentId == null || opponentId == _currentUser?.uid) return;

    final opponentHand = game.getHand(turnNum);
    final state = game.gameState;
    final playable = opponentHand.where((id) => state.canPlay(id)).toList();

    if (playable.isNotEmpty) {
      final tileId = playable.first;
      final tileData = state.tiles[tileId]!;
      String side;
      if (state.chain.isEmpty) {
        side = 'right';
      } else {
        final canLeft =
            tileData['left'] == state.leftOpen ||
            tileData['right'] == state.leftOpen;
        side = canLeft ? 'left' : 'right';
      }
      await _gameService.playTile(
        gameId: _activeGameId!,
        playerId: opponentId,
        tileId: tileId,
        side: side,
      );
    } else {
      await _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: opponentId,
      );
    }
  }

  Future<void> _abandonInactiveOpponent() async {
    if (_activeGameId == null || _gameEnded) return;
    final game = _currentGame;
    if (game == null) return;
    final turnStr = game.currentTurn;
    final turnNum = int.tryParse(turnStr.replaceAll('player', '')) ?? 0;
    final opponentId = game.playerIdOf(turnNum);
    if (opponentId == null || opponentId == _currentUser?.uid) return;
    await _gameService.abandonGame(
      gameId: _activeGameId!,
      playerId: opponentId,
    );
  }

  Future<void> _autoPlayOrPass() async {
    if (_activeGameId == null || _gameEnded) return;
    final game = _currentGame;
    if (game == null) return;
    final myHand = game.getHand(_myPlayerNumber);
    final state = game.gameState;
    final playable = myHand.where((id) => state.canPlay(id)).toList();
    if (playable.isNotEmpty) {
      playable.shuffle(Random());
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
    } else {
      await _gameService.passTurn(
        gameId: _activeGameId!,
        playerId: _currentUser!.uid,
      );
    }
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
      _showSnack(S.of(context).tileDoesntConnect);
      return;
    }

    setState(() => _selectedTileId = tileId);

    final tileData = state.tiles[tileId]!;
    final canLeft = tileData['left'] == state.leftOpen || tileData['right'] == state.leftOpen;
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
      _showSnack(S.of(context).couldNotPlayTile);
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
    if (side == 'left') { chain.insert(0, placement); } else { chain.add(placement); }

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
      betAmount: game.betAmount,
      currencyType: game.currencyType,
      quotasCollected: game.quotasCollected,
      rewardsDistributed: game.rewardsDistributed,
      totalPot: game.totalPot,
      gameSettings: game.gameSettings,
      numberOfPlayers: game.numberOfPlayers,
    );
  }

  Future<void> _passTurn() async {
    await _gameService.passTurn(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
    );
  }

  Future<void> _abandonGame() async {
    if (_gameEnded) { Navigator.of(context).pop(); return; }
    final s = S.of(context);
    final quotasCollected = _currentGame?.quotasCollected ?? false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.abandonGame),
        content: Text(quotasCollected
            ? s.abandonWarningPase
            : s.abandonGameWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.abandonGame, style: const TextStyle(color: Colors.white)),
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
    setState(() => _gameEnded = true);
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
        gameType: GameTypeModel.dominoPase,
        result: result,
        pointsEarned: iWon ? 20 : -5,
        durationMinutes: dur > 0 ? dur : 1,
        opponentName: opponentName,
        additionalData: {
          'matchType': widget.matchType,
          'mode': 'online',
          'betAmount': game.betAmount,
          'currencyType': 'diamonds',
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error recording domino pase history: $e');
    }
  }

  Future<void> _requestRematch() async {
    if (_activeGameId == null || _rematchRequested) return;
    setState(() => _rematchRequested = true);

    final result = await _gameService.requestRematch(
      gameId: _activeGameId!,
      playerId: _currentUser!.uid,
    );

    if (result == 'CREATE_NEW' && _currentGame != null) {
      setState(() => _waitingForRematch = true);
      final newGame = await _gameService.createRematchGame(previousGame: _currentGame!);
      if (newGame != null && mounted) {
        final newGameId = newGame['gameId'] as String;
        await _firestore
            .collection('domino_pase_games')
            .doc(_activeGameId!)
            .update({'gameSettings.rematchGameId': newGameId});
        _openGame(newGameId, _myPlayerNumber);
      } else if (mounted) {
        _showSnack(S.of(context).cannotCreateRematch);
        setState(() => _waitingForRematch = false);
      }
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2000),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final inGame = _screenState == _PaseOnlineState.gameActive;
    return PopScope(
      canPop: !inGame || _gameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inGame && !_gameEnded) _abandonGame();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _accentColor,
          elevation: 2,
          title: Text(S.of(context).dominoPaseTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!inGame)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_userDiamonds ?? 0}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.diamond, color: Colors.white, size: 16),
                      SizedBox(
                        width: 32, height: 32,
                        child: IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: _showDiamondPurchaseDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!inGame)
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: S.of(context).tutorial,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DominoPaseTutorialScreen())),
              ),
            if (inGame)
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    if (_unreadChatCount > 0)
                      Positioned(
                        right: -4, top: -4,
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
              ),
            if (inGame && !_gameEnded)
              TextButton(
                onPressed: _abandonGame,
                child: Text(S.of(context).exit, style: TextStyle(color: Colors.red[300])),
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
                collectionName: 'domino_pase_games',
                currentUserId: _currentUser?.uid ?? '',
                currentUserName: _currentUser?.displayName ?? 'Jugador',
                showFloatingBubbles: false,
                onUnreadCountChanged: (c) {
                  if (mounted) setState(() => _unreadChatCount = c);
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
      case _PaseOnlineState.playerCountSelection:
        return _buildPlayerCountSelection();
      case _PaseOnlineState.matchmaking:
        return _buildMatchmaking();
      case _PaseOnlineState.waitingRoom:
        return _buildWaitingRoom();
      case _PaseOnlineState.gameActive:
        return _buildGame();
    }
  }


  Widget _buildPlayerCountSelection() {
    final balance = _userDiamonds ?? 0;
    final requiredBal = _selectedBetAmount != null
        ? DominoPaseGameService.requiredBalance(_selectedBetAmount!)
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentColor, const Color(0xFFBA68C8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
                      Text(S.of(context).dominoPaseTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(S.of(context).diamondsOnlyChallenge, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Icon(Icons.diamond, color: Colors.white, size: 18),
                    const SizedBox(height: 2),
                    Text('$balance', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(S.of(context).howManyPlayers, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final sel = _selectedPlayerCount == n;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPlayerCount = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    height: 96,
                    decoration: BoxDecoration(
                      color: sel ? _accentColor : _panelColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: sel ? _accentColor : Colors.grey.shade300, width: sel ? 2 : 1),
                      boxShadow: sel ? [BoxShadow(color: _accentColor.withValues(alpha: 0.4), blurRadius: 10)] : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(n == 3 ? '👥+' : '👨‍👩‍👧‍👦', style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 6),
                        Text('$n jugadores', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87)),
                        Text(n == 3 ? '7 fichas fuera' : '0 fichas fuera', style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Bet selection
          Text(S.of(context).selectYourBet, style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(S.of(context).needDoubleForBet, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _betOptions.map((amount) {
              final required = DominoPaseGameService.requiredBalance(amount);
              final isSelected = _selectedBetAmount == amount;
              final canAfford = balance >= required;
              return GestureDetector(
                onTap: canAfford ? () => setState(() => _selectedBetAmount = amount) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _accentColor : canAfford ? _panelColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _accentColor : canAfford ? Colors.grey.shade300 : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.diamond, size: 14, color: canAfford ? Colors.blue[300] : Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text('$amount', style: TextStyle(color: isSelected ? Colors.white : canAfford ? Colors.black87 : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Text('req: $required', style: TextStyle(fontSize: 9, color: isSelected ? Colors.white70 : Colors.grey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          if (_selectedBetAmount != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  _infoRow(S.of(context).nominalBet, '$_selectedBetAmount ${S.of(context).diamonds}'),
                  _infoRow(S.of(context).backupAmount, '$_selectedBetAmount ${S.of(context).diamonds}'),
                  _infoRow(S.of(context).totalRequired, '$requiredBal ${S.of(context).diamonds}'),
                  _infoRow(S.of(context).tekoplayCommission, '${DominoPaseGameService.commission(_selectedBetAmount!, _selectedPlayerCount)} ${S.of(context).diamonds}'),
                  _infoRow(S.of(context).passValueLabel, '${DominoPaseGameService.passValue(_selectedBetAmount!)} ${S.of(context).diamonds}'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedBetAmount == null ? null : _startMatchmaking,
              icon: const Icon(Icons.search),
              label: Text(S.of(context).searchGame, style: const TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildMatchmaking() {
    final remaining = (90 - _matchmakingSeconds).clamp(0, 90);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFF9C27B0)),
            ),
            const SizedBox(height: 32),
            Text(S.of(context).searchingRealPlayers,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _matchmakingSeconds >= 70 ? Colors.red : _accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text('$_selectedPlayerCount jugadores · $_selectedBetAmount diamantes',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(S.of(context).realPlayersNoBots, style: const TextStyle(fontSize: 11, color: Colors.purple)),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _cancelMatchmaking,
              icon: const Icon(Icons.close),
              label: Text(S.of(context).cancel),
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
                  Text(S.of(context).dominoPaseWaitingRoom,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$joined / $_selectedPlayerCount jugadores',
                      style: const TextStyle(fontSize: 16, color: Color(0xFF9C27B0), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: joined / _selectedPlayerCount,
                      backgroundColor: Colors.grey.shade200,
                      color: _accentColor,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (remaining > 0) ...[
                    const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF9C27B0)),
                    ),
                    const SizedBox(height: 6),
                    Text('Esperando $remaining ${remaining == 1 ? 'jugador más' : 'jugadores más'}...',
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ] else ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    Text(S.of(context).allReadyStarting,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
              label: Text(S.of(context).cancel),
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
    if (game == null) return const Center(child: CircularProgressIndicator());

    final myHand = game.getHand(_myPlayerNumber);
    final isMyTurn = game.isPlayerTurn(_currentUser!.uid);
    final state = game.gameState;
    final canPass = !state.canPlayAny(myHand);

    final payments = Map<String, dynamic>.from(game.gameSettings?['passPayments'] ?? {});
    final myPayments = payments['player$_myPlayerNumber'] as Map<String, dynamic>?;
    final myReceived = (myPayments?['received'] as int?) ?? 0;
    final myPaid = (myPayments?['paid'] as int?) ?? 0;

    final opponents = <({int playerNum, String name, bool isActive, String? playerId, int passReceived, int passPaid})>[];
    final nPlayers = game.numberOfPlayers;
    final rotationOrder = <int>[];
    int cur = (_myPlayerNumber % nPlayers) + 1;
    for (int i = 0; i < nPlayers - 1; i++) {
      rotationOrder.add(cur);
      cur = (cur % nPlayers) + 1;
    }
    for (final p in rotationOrder.reversed) {
      final pid = game.playerIdOf(p);
      final pPayments = payments['player$p'] as Map<String, dynamic>?;
      opponents.add((
        playerNum: p,
        name: game.playerNameOf(p),
        isActive: game.currentTurn == 'player$p',
        playerId: pid,
        passReceived: (pPayments?['received'] as int?) ?? 0,
        passPaid: (pPayments?['paid'] as int?) ?? 0,
      ));
    }

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _buildOpponentHeader(opponents, state),
              _buildChainArea(state),
              _buildPlayerFooter(myHand, state, isMyTurn, canPass, myReceived, myPaid),
            ],
          ),
          Positioned(
            left: 8,
            bottom: 100,
            child: _buildMyPanel(isMyTurn, myReceived, myPaid),
          ),
          if (_ownMsgText != null)
            Positioned(
              right: 12,
              bottom: 110,
              child: _buildChatBubble(_ownMsgText!, isMe: true),
            ),
          for (final entry in opponents.asMap().entries)
            if (_lastMsgText != null && entry.value.playerId == _lastMsgSenderId)
              Positioned(
                top: 80,
                left: entry.key * (MediaQuery.of(context).size.width / opponents.length) + 8,
                child: _buildChatBubble(_lastMsgText!, isMe: false),
              ),
          if (_flyingTileData != null) _buildPlayerFlyOverlay(),
          if (_gameEnded && _currentGame != null && !_gameOverMinimized)
            _buildGameOverOverlay(_currentGame!),
          if (_gameEnded && _gameOverMinimized)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: _accentColor,
                onPressed: () => setState(() => _gameOverMinimized = false),
                child: const Icon(Icons.expand_less, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpponentHeader(
    List<({int playerNum, String name, bool isActive, String? playerId, int passReceived, int passPaid})> opponents,
    DominoGameState state,
  ) {
    final tileW = opponents.length > 1 ? 16.0 : 20.0;
    final tileH = opponents.length > 1 ? 30.0 : 38.0;

    return Container(
      height: 80,
      color: const Color(0xFF1A0A2E),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: opponents.map((opp) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: opp.isActive ? Colors.white12 : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: opp.isActive ? Border.all(color: _accentColor, width: 1.5) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_passedPlayerNum == opp.playerNum)
                    Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('pass_${opp.playerNum}_${DateTime.now().millisecondsSinceEpoch ~/ 2000}'),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: v.clamp(0.0, 1.0), child: child)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(S.of(context).passed, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          opp.name,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (opp.passReceived > 0 || opp.passPaid > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (opp.passReceived - opp.passPaid) >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${opp.passReceived - opp.passPaid >= 0 ? '+' : ''}${opp.passReceived - opp.passPaid}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      if (opp.isActive && _opponentTimer != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '⏱$_opponentSecondsLeft"',
                          style: TextStyle(
                            color: _opponentSecondsLeft <= 10 ? Colors.red[300] : Colors.orange[300],
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.generate(
                        state.handOf(opp.playerNum).length,
                        (_) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: DominoTileWidget(left: 0, right: 0, width: tileW, height: tileH, faceDown: true),
                        ),
                      ),
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

  Widget _buildChainArea(DominoGameState state) {
    final showHints = _needsSideChoice && _selectedTileId != null;
    final openingIdx = state.openingTileId != null
        ? state.chain.indexWhere((t) => t.id == state.openingTileId)
        : -1;
    return Expanded(
      child: Container(
        color: const Color(0xFF429936),
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
    );
  }

  Widget _buildPlayerFooter(
    List<String> hand,
    DominoGameState state,
    bool isMyTurn,
    bool canPass,
    int myReceived,
    int myPaid,
  ) {
    final req = isMyTurn ? _requiredOpeningDouble(state, hand) : -1;
    final isOpeningMove = state.chain.isEmpty && req != -1;

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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF8B5E3C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE65100), width: 1.5),
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
                        boxShadow: [BoxShadow(
                          color: Colors.amber.withValues(alpha: _mandatoryTileAnimCtrl.value * 0.8),
                          blurRadius: 18 * _mandatoryTileAnimCtrl.value,
                          spreadRadius: 5 * _mandatoryTileAnimCtrl.value,
                        )],
                      ),
                      child: child,
                    ),
                    child: tileWidget,
                  );
                }).toList(),
              ),
            ),
          ),
          if (isMyTurn && canPass) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: ElevatedButton.icon(
                onPressed: _passTurn,
                icon: const Icon(Icons.skip_next, size: 13),
                label: Text(S.of(context).pass, style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyPanel(bool isActive, int myReceived, int myPaid) {
    final passNet = myReceived - myPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: _accentColor, width: 1.5) : null,
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
              if (myReceived > 0 || myPaid > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: passNet >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${passNet >= 0 ? '+' : ''}$passNet',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
          color: isMe ? _accentColor : Colors.white,
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

  Widget _buildGameOverOverlay(DominoGameMatch game) {
    if (!game.quotasCollected) {
      return _buildNoQuotasGameOverOverlay(game);
    }

    final bool iWon = game.winnerId == _currentUser!.uid;
    final String title = iWon ? S.of(context).youWonHand : S.of(context).youLostHand;
    final Color titleColor = iWon ? Colors.green : Colors.red[400]!;
    final betAmount = game.betAmount ?? 0;
    final required = DominoPaseGameService.requiredBalance(betAmount);
    final nPlayers = game.numberOfPlayers;
    final commissionAmt = game.gameSettings?['commissionAmount'] as int? ??
        DominoPaseGameService.commission(betAmount, nPlayers);
    final totalPot = required * nPlayers;
    final winnerPrize = totalPot - commissionAmt;

    final payments = Map<String, dynamic>.from(game.gameSettings?['passPayments'] ?? {});
    final myPayments = payments['player$_myPlayerNumber'] as Map<String, dynamic>?;
    final myPassNet = ((myPayments?['received'] as int?) ?? 0) - ((myPayments?['paid'] as int?) ?? 0);

    final totalResult = game.quotasCollected
        ? (iWon ? (winnerPrize - required + myPassNet) : (-required + myPassNet))
        : 0;

    final playerTiles = <({String name, int pips, int tileCount})>[];
    for (int p = 1; p <= nPlayers; p++) {
      final hand = game.gameState.handOf(p);
      if (hand.isEmpty) continue;
      final pips = game.gameState.handPipCount(hand);
      final name = p == _myPlayerNumber ? (_myName ?? 'Yo') : game.playerNameOf(p);
      playerTiles.add((name: name, pips: pips, tileCount: hand.length));
    }

    final rematchFailed = game.gameSettings?['rematchFailed'] == true;
    final playerExited = List<String>.from(game.gameSettings?['playerExited'] ?? []);
    final someoneLeft = playerExited.isNotEmpty;

    final rematchAccepted = Map<String, dynamic>.from(
        game.gameSettings?['rematchAccepted'] ?? {});
    final myPlayerKey = 'player$_myPlayerNumber';
    final iRequested = rematchAccepted[myPlayerKey] == true;
    final opponentRematchNames = <String>[];
    for (int p = 1; p <= nPlayers; p++) {
      if (p == _myPlayerNumber) continue;
      if (rematchAccepted['player$p'] == true) {
        final name = game.playerNameOf(p);
        opponentRematchNames.add(name);
      }
    }
    final opponentWantsRematch = opponentRematchNames.isNotEmpty;

    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20D0A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _gameOverMinimized = true),
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _gameOverMinimized = true),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.expand_more, color: Colors.white38, size: 22),
                ),
              ),
            ),
            Text(title, style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.bold)),

            if (game.isAbandoned) ...[
              const SizedBox(height: 4),
              Text(S.of(context).playerAbandonedGame, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],

            const SizedBox(height: 8),

            for (final pt in playerTiles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '${pt.name}: ${pt.tileCount} fichas (${pt.pips} puntos)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),

            const SizedBox(height: 8),

            Text(
              '${totalResult >= 0 ? '+' : ''}$totalResult diamantes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: totalResult >= 0 ? Colors.green : Colors.red[300],
              ),
            ),
            if (myPassNet != 0)
              Text(
                'Pases: ${myPassNet >= 0 ? '+' : ''}$myPassNet',
                style: TextStyle(fontSize: 12, color: myPassNet >= 0 ? Colors.green[300] : Colors.red[300]),
              ),

            const SizedBox(height: 16),

            if (!game.isAbandoned && !rematchFailed && !someoneLeft) ...[
              if (opponentWantsRematch && !iRequested)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${opponentRematchNames.join(", ")} ${S.of(context).wantsRematch}',
                    style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              if ((!iWon && (_userDiamonds ?? 0) >= required) || opponentWantsRematch) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_waitingForRematch || iRequested) ? null : _requestRematch,
                    icon: Icon(
                        iRequested
                            ? Icons.hourglass_top
                            : opponentWantsRematch
                                ? Icons.check
                                : Icons.replay,
                        size: 18),
                    label: Text(
                      _waitingForRematch
                          ? S.of(context).creatingRematch
                          : iRequested
                              ? S.of(context).waitingOthers
                              : opponentWantsRematch
                                  ? S.of(context).acceptRematch
                                  : S.of(context).rematch,
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: opponentWantsRematch && !iRequested
                          ? Colors.green
                          : _accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],

            if (rematchFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  S.of(context).rematchCancelled,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            if (!iWon && !game.isAbandoned && !rematchFailed &&
                !someoneLeft && (_userDiamonds ?? 0) < required)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  S.of(context).insufficientDiamondsForRematch(required),
                  style:
                      const TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  if (_activeGameId != null && _currentUser != null) {
                    _firestore.collection('domino_pase_games').doc(_activeGameId!).update({
                      'gameSettings.playerExited': FieldValue.arrayUnion([_currentUser!.uid]),
                    }).catchError((_) {});
                  }
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(S.of(context).exit, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoQuotasGameOverOverlay(DominoGameMatch game) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xF20D0A1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _gameOverMinimized = true),
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _gameOverMinimized = true),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.expand_more, color: Colors.white38, size: 22),
                ),
              ),
            ),
            const Icon(Icons.info_outline, color: Colors.orange, size: 40),
            const SizedBox(height: 12),
            Text(S.of(context).playerAbandonedGame,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(S.of(context).exit, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
