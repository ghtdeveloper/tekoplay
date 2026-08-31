import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/ludo_game_match.dart';
import '../../../core/models/multiplayer_game_match_chess.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/ludo_game_service.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/bot_name_service.dart';
import '../../../core/service/payment_service.dart';
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../../generated/l10n.dart';
import '../../adds/banner_ad_widget.dart';
import '../../coins/diamond_purchase_dialog.dart';
import '../../../core/service/game_chat_service.dart';
import '../../../core/widgets/game_chat_widget.dart';
import 'ludo_board_painter.dart';
import 'multiplayer_ludo_screen.dart';

enum _LudoOnlineState { playerCountSelection, matchmaking, waitingRoom, gameActive }

class OnlineLudoScreen extends StatefulWidget {
  final String matchType;
  const OnlineLudoScreen({super.key, required this.matchType});

  @override
  State<OnlineLudoScreen> createState() => _OnlineLudoScreenState();
}

class _OnlineLudoScreenState extends State<OnlineLudoScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  final LudoGameService _gameService = LudoGameService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  _LudoOnlineState _screenState = _LudoOnlineState.playerCountSelection;
  int _selectedPlayerCount = 2;
  int? _selectedBetAmount;
  String _currencyType = 'coins';

  static const List<int> _betOptions = [10, 20, 50, 100, 250, 500, 1000, 5000, 10000];

  String? _activeGameId;
  int? _myPlayerNumber;
  LudoGameMatch? _currentRoomGame;
  StreamSubscription<LudoGameMatch?>? _gameSubscription;
  StreamSubscription<DocumentSnapshot>? _balanceSubscription;
  int _matchmakingSeconds = 0;
  Timer? _matchmakingTimer;
  Timer? _keepAliveTimer;
  bool _isSearching = false;
  bool _navigated = false;
  bool _isJoiningGame = false;

  String? _myName;
  String? _myPhotoUrl;
  int? _userCoins;
  int? _userDiamonds;

  bool _isPlayingAgainstBot = false;
  bool _botIsWeak = false;

  final GlobalKey<GameChatWidgetState> _chatKey = GlobalKey<GameChatWidgetState>();

  String? _lastMsgSenderId;
  String? _lastMsgText;
  String? _ownMsgText;
  Timer? _msgBubbleTimer;
  Timer? _ownMsgBubbleTimer;

  String _opponentName   = '';
  String _opponentEmoji  = '🎮';
  final Map<String, String> _botNames  = {};
  final Map<String, String> _botEmojis = {};

  LudoGameState _gameState = LudoGameState.initial();
  String _myColor   = 'yellow';
  List<String> _botColors = ['red'];
  List<String> _activePlayers = ['yellow', 'red'];
  String _currentPlayer = 'yellow';
  bool get _isMyTurn  => _currentPlayer == _myColor;
  bool get _isBotTurn => _isPlayingAgainstBot && !_isMyTurn;
  String get _currentBotName  => _botNames[_currentPlayer]  ?? _opponentName;

  int _dice1Value = 0;
  int _dice2Value = 0;
  bool _hasUsedDice1 = false;
  bool _hasUsedDice2 = false;
  int _consecutiveDoubles = 0;
  bool _isRollingDice = false;
  final Map<String, int?> _lastMovedPieceId = {};

  List<Map<String, dynamic>> _movablePieces = [];
  int? _selectedPieceId;
  final List<int> _validMovePositions = [];
  bool _bonusSelectionActive = false;
  bool _bonusHadDouble = false;
  int _bonusRemainingDie = 0;
  int _bonusRemainingDieNumber = 0;
  final List<Map<String, dynamic>> _pendingBonusMoves = [];
  Set<int> _bridgeBreakPieceIds = {};

  bool _gameEnded = false;
  double _boardSize = 0;
  DateTime? _gameStartTime;
  bool _botExecuting = false;
  Timer? _botSafetyTimer;
  final Map<String, int> _botMissedFive = {};
  int _humanHomeDoubles = 0;
  final Map<String, int> _botHomeDoubles = {};
  int _botTurnCounter = 0;
  Timer? _awayTimer;

  Timer? _turnTimer;
  int _turnTimerSeconds = 0;
  static const int _turnTimeoutSeconds = 30;
  DateTime? _turnStartedAt;

  String _toastMessage = '';
  bool _showToast = false;
  bool _showTurnBanner = false;
  String _turnBannerText = '';
  Color _turnBannerColor = Colors.orange;

  late AnimationController _pulseController;
  late AnimationController _diceAnimController;
  late Animation<double> _diceRotation;
  late AnimationController _toastController;
  late Animation<double> _toastAnim;
  late AnimationController _bannerController;
  late Animation<double> _bannerAnim;

  final Random _random = Random();

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

  bool get _isBetMode => _currencyType == 'diamonds';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currencyType = widget.matchType == S.of(context).bet ? 'diamonds' : 'coins';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserInfo();

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchmakingTimer?.cancel();
    _keepAliveTimer?.cancel();
    _turnTimer?.cancel();
    _botSafetyTimer?.cancel();
    _awayTimer?.cancel();
    _msgBubbleTimer?.cancel();
    _ownMsgBubbleTimer?.cancel();
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _pulseController.dispose();
    _diceAnimController.dispose();
    _toastController.dispose();
    _bannerController.dispose();
    _disableWakeLock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wakelockActive || (!_gameEnded && _screenState == _LudoOnlineState.gameActive)) {
        WakelockPlus.enable().then((_) => _wakelockActive = true).catchError((_) => false);
      }
      _awayTimer?.cancel();
      _awayTimer = null;
      if (_turnStartedAt != null && !_gameEnded && _isMyTurn) {
        final elapsed = DateTime.now().difference(_turnStartedAt!).inSeconds;
        final remaining = (_turnTimeoutSeconds - elapsed).clamp(0, _turnTimeoutSeconds);
        _turnTimer?.cancel();
        if (remaining > 0) {
          _startTurnTimer(remaining);
        } else {
          _autoAction();
        }
      } else if (!_gameEnded && _isBotTurn && !_botExecuting) {
        _scheduleBotMove();
      }
    }
    if (state == AppLifecycleState.paused) {
      _disableWakeLock();
      if (_isMyTurn && !_gameEnded) {
        _turnTimer?.cancel();
      }
      if (!_gameEnded && _screenState == _LudoOnlineState.gameActive) {
        _awayTimer?.cancel();
        _awayTimer = Timer(const Duration(minutes: 2), () {
          if (!mounted || _gameEnded) return;
          final winner = _activePlayers.firstWhere(
            (c) => c != _myColor,
            orElse: () => _botColors.first,
          );
          _showEventToast('Perdiste por inactividad', color: Colors.red);
          _endGame(winner);
        });
      }
    }
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
    final diamondsLabel = S.of(context).diamonds;
    final successMsg = S.of(context).purchaseSuccessful;
    final errorMsg = S.of(context).paymentProcessingError;
    try {
      final paymentService = PaymentService();
      final canPay = await paymentService.canMakePayments();
      if (!canPay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).googlePayNotAvailable), backgroundColor: Colors.orange),
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

  bool _wakelockActive = false;

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      _wakelockActive = true;
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    _wakelockActive = false;
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> _loadUserInfo() async {
    if (_currentUser == null) return;
    try {
      final doc = await _firestoreService.getUser(_currentUser!.uid);
      if (doc != null && mounted) {
        setState(() {
          _myName = doc.name;
          _myPhotoUrl = doc.urlPhoto;
        });
      }
    } catch (_) {}
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
          _userCoins = data['coins'] ?? 0;
          _userDiamonds = data['diamonds'] ?? 0;
        });
      }
    });
  }

  Future<void> _startMatchmaking() async {
    if (_currentUser == null || _isSearching) return;
    final isBet = _isBetMode;
    if (isBet && _selectedBetAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el monto de la apuesta antes de buscar partida.')),
      );
      return;
    }
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final minRequired = isBet ? _selectedBetAmount! : 100;
    if (balance < minRequired) { _showInsufficientFundsDialog(); return; }

    setState(() {
      _isSearching = true;
      _matchmakingSeconds = 0;
      _screenState = _LudoOnlineState.matchmaking;
    });
    _enableWakeLock();

    _matchmakingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _matchmakingSeconds++);

      if (_screenState == _LudoOnlineState.gameActive || _navigated) {
        t.cancel();
        return;
      }

      const int maxWait = 60;
      if (_matchmakingSeconds >= maxWait &&
          !_isPlayingAgainstBot &&
          (_screenState == _LudoOnlineState.matchmaking ||
           _screenState == _LudoOnlineState.waitingRoom) &&
          !_navigated) {
        t.cancel();
        _onMatchmakingTimeout();
        return;
      }

      if (!_isPlayingAgainstBot &&
          _matchmakingSeconds % 3 == 0 &&
          (_screenState == _LudoOnlineState.matchmaking ||
           _screenState == _LudoOnlineState.waitingRoom)) {
        _tryJoinExistingGame();
      }
    });

    await _findOrCreateGame();
  }

  Future<void> _tryJoinExistingGame() async {
    if (_isPlayingAgainstBot || _navigated || _isJoiningGame) return;
    if (_myPlayerNumber != null && _myPlayerNumber! > 1) return;
    final isSearching = _screenState == _LudoOnlineState.matchmaking ||
        _screenState == _LudoOnlineState.waitingRoom;
    if (!isSearching) return;

    _isJoiningGame = true;
    try {
      final ct = _currencyType;
      final waiting = await _gameService.findWaitingGames(
        numberOfPlayers: _selectedPlayerCount,
        currencyType: ct,
      );
      final myUid = _currentUser?.uid ?? '';
      final eligible = waiting.where((g) {
        if (g.gameSettings?['isOnlineMatchmaking'] != true) return false;
        if (DateTime.now().difference(g.createdAt).inSeconds >= 120) return false;
        if (g.playerCount >= _selectedPlayerCount) return false;
        if (g.hostId == myUid) return false;
        if (_activeGameId != null && g.id == _activeGameId) return false;
        if (ct == 'diamonds' && _selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
        return true;
      }).toList();

      if (eligible.isEmpty || !mounted || _navigated || _isPlayingAgainstBot) return;

      if (_screenState == _LudoOnlineState.waitingRoom && _activeGameId != null) {
        _gameSubscription?.cancel();
        _keepAliveTimer?.cancel();
        _firestore.collection('ludo_games').doc(_activeGameId).update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
        _activeGameId = null;
        setState(() => _screenState = _LudoOnlineState.matchmaking);
      }

      await _joinGame(eligible.first);
    } catch (_) {
    } finally {
      _isJoiningGame = false;
    }
  }

  Future<void> _findOrCreateGame() async {
    try {
      final ct = _currencyType;
      final waiting = await _gameService.findWaitingGames(
        numberOfPlayers: _selectedPlayerCount,
        currencyType: ct,
      );
      final eligible = waiting.where((g) {
        if (g.gameSettings?['isOnlineMatchmaking'] != true) return false;
        if (DateTime.now().difference(g.createdAt).inSeconds >= 120) return false;
        if (g.playerCount >= _selectedPlayerCount) return false;
        if (g.hostId == (_currentUser?.uid ?? '')) return false;
        if (ct == 'diamonds' && _selectedBetAmount != null && g.betAmount != _selectedBetAmount) return false;
        return true;
      }).toList();

      if (eligible.isNotEmpty) {
        await _joinGame(eligible.first);
      } else {
        await _createNewGame();
      }
    } catch (e) {
      if (kDebugMode) print('Error finding game: $e');
      await _createNewGame();
    }
  }

  Future<void> _createNewGame() async {
    if (!mounted || _navigated || _isPlayingAgainstBot) return;
    try {
      final gameId = await _gameService.createGame(
        hostId: _currentUser!.uid,
        hostName: _myName ?? 'Jugador',
        hostPhotoUrl: _myPhotoUrl,
        currencyType: _currencyType,
        betAmount: _isBetMode ? _selectedBetAmount : null,
        numberOfPlayers: _selectedPlayerCount,
        isOnlineMatchmaking: true,
      );
      if (gameId == null || !mounted) return;
      _activeGameId = gameId;
      _myPlayerNumber = 1;
      setState(() => _screenState = _LudoOnlineState.waitingRoom);
      _listenToRoomGame(gameId);
      _startKeepAlive(gameId);
    } catch (e) {
      if (kDebugMode) print('Error creating game: $e');
      if (mounted) {
        setState(() { _isSearching = false; _screenState = _LudoOnlineState.playerCountSelection; });
      }
    }
  }

  Future<void> _joinGame(LudoGameMatch game) async {
    if (!mounted || _navigated || _isPlayingAgainstBot) return;
    try {
      final success = await _gameService.joinGame(
        gameId: game.id,
        playerId: _currentUser!.uid,
        playerName: _myName ?? 'Jugador',
        playerPhotoUrl: _myPhotoUrl,
      );
      if (!success || !mounted) { await _createNewGame(); return; }
      _activeGameId = game.id;
      _myPlayerNumber = game.playerCount + 1;
      setState(() => _screenState = _LudoOnlineState.waitingRoom);
      _listenToRoomGame(game.id);
      _startKeepAlive(game.id);
    } catch (_) {
      await _createNewGame();
    }
  }

  void _listenToRoomGame(String gameId) {
    _gameSubscription?.cancel();
    _gameSubscription = _gameService.getGameStream(gameId).listen((game) {
      if (game == null || !mounted || _navigated || _isPlayingAgainstBot) return;
      setState(() => _currentRoomGame = game);
      if (game.isActive && !_navigated) {
        _navigated = true;
        _matchmakingTimer?.cancel();
        _keepAliveTimer?.cancel();
        _gameSubscription?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MultiplayerLudoScreen(
                  gameId: gameId,
                  playerNumber: _myPlayerNumber!,
                  matchType: widget.matchType,
                ),
              ),
            );
          }
        });
      } else if (game.status == 'cancelled' && !_navigated) {
        _gameSubscription?.cancel();
        _keepAliveTimer?.cancel();
        _activeGameId = null;
        _startBotGame();
      }
    });
  }

  void _startKeepAlive(String gameId) {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isPlayingAgainstBot) {
        _firestore.collection('ludo_games').doc(gameId).update({
          'lastActivity': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    });
  }


  void _onMatchmakingTimeout() {
    if (!mounted || _navigated || _isPlayingAgainstBot) return;
    if (_myPlayerNumber == 1 && _activeGameId != null) {
      final playerCount = _currentRoomGame?.playerCount ?? 1;
      if (playerCount >= 2) {
        _gameService.fillBotsAndStart(_activeGameId!);
        return;
      }
    }
    if (_myPlayerNumber != null && _myPlayerNumber! > 1 && _activeGameId != null) {
      return;
    }
    _startBotGame();
  }

  void _cancelMatchmaking() {
    _matchmakingTimer?.cancel();
    _keepAliveTimer?.cancel();
    _gameSubscription?.cancel();
    if (_activeGameId != null && !_isPlayingAgainstBot) {
      _firestore.collection('ludo_games').doc(_activeGameId).update({
        'status': 'cancelled',
        'finishedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    if (mounted) {
      setState(() {
        _isSearching = false;
        _activeGameId = null;
        _myPlayerNumber = null;
        _currentRoomGame = null;
        _screenState = _LudoOnlineState.playerCountSelection;
      });
    }
  }

  Future<void> _startBotGame() async {
    if (_isPlayingAgainstBot || _navigated) return;
    if (_screenState == _LudoOnlineState.gameActive) return;

    if (_activeGameId != null) {
      _firestore.collection('ludo_games').doc(_activeGameId).update({
        'status': 'cancelled',
        'finishedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    _keepAliveTimer?.cancel();
    _gameSubscription?.cancel();

    final isBet = _isBetMode;
    final cost = isBet ? (_selectedBetAmount ?? 25) : 100;
    if (_currentUser != null) {
      if (isBet) {
        _firestoreService.incrementUserDiamonds(_currentUser!.uid, -cost);
      } else {
        _firestoreService.incrementUserCoins(_currentUser!.uid, -cost);
      }
    }

    final isBetMode = _isBetMode;
    _botIsWeak = isBetMode && await BotNameService.shouldBotPlayWeak();

    const allColors = ['yellow', 'green', 'red', 'blue'];
    _myColor = 'yellow';
    final botCount = (_selectedPlayerCount) - 1;
    _botColors = allColors.skip(1).take(botCount).toList();
    _activePlayers = [_myColor, ..._botColors];
    _currentPlayer = 'yellow';

    _botNames.clear();
    _botEmojis.clear();
    for (final bc in _botColors) {
      final profile = await BotNameService.pickUnseenProfile(_random);
      _botNames[bc]  = profile['name']!;
      _botEmojis[bc] = profile['emoji']!;
    }
    _botMissedFive.clear();
    _humanHomeDoubles = 0;
    _botHomeDoubles.clear();

    _opponentName  = _botNames[_botColors.first] ?? 'Bot';
    _opponentEmoji = _botEmojis[_botColors.first] ?? '🤖';

    setState(() {
      _isPlayingAgainstBot = true;
      _gameState     = LudoGameState.initial();
      _gameEnded     = false;
      _gameStartTime = DateTime.now();
      _dice1Value    = 0;
      _dice2Value    = 0;
      _hasUsedDice1  = false;
      _hasUsedDice2  = false;
      _consecutiveDoubles = 0;
      _movablePieces.clear();
      _screenState = _LudoOnlineState.gameActive;
      if (isBet) {
        _userDiamonds = (_userDiamonds ?? 0) - cost;
      } else {
        _userCoins = (_userCoins ?? 0) - cost;
      }
    });

    _enableWakeLock();
    _showRivalFoundBanner();
    _showTurnBannerAnim(S.of(context).yourTurn, _getPlayerColor(_myColor));
    _startTurnTimer();
  }

  void _showRivalFoundBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
        content: Row(children: [
          Text(_opponentEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('¡$_opponentName se unió a la partida!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _startTurnTimer([int? initialSeconds]) {
    _turnTimer?.cancel();
    final secs = initialSeconds ?? _turnTimeoutSeconds;
    _turnStartedAt = DateTime.now().subtract(Duration(seconds: _turnTimeoutSeconds - secs));
    setState(() => _turnTimerSeconds = secs);
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
      _executeBonusMove(_myColor, m['pieceId'] as int, m['bonusPos'] as int, _bonusHadDouble);
      return;
    }

    if (_dice1Value == 0 && _dice2Value == 0) {
      await _rollDice();
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted || _gameEnded || !_isMyTurn) return;
      if (_movablePieces.isNotEmpty) {
        final m = _movablePieces.first;
        _executePieceMove(_myColor, m['pieceId'] as int,
            m['diceValue'] as int, m['diceNumber'] as int);
      }
    } else if (_movablePieces.isNotEmpty) {
      final m = _movablePieces.first;
      _executePieceMove(_myColor, m['pieceId'] as int,
          m['diceValue'] as int, m['diceNumber'] as int);
    } else {
      _endMyTurn();
    }
  }

  Future<void> _rollDice() async {
    if (!_isMyTurn || _gameEnded || _isRollingDice || _bonusSelectionActive) return;
    if (_dice1Value != 0 || _dice2Value != 0) return;

    final myPieces = _gameState.getPiecesByColor(_myColor);
    final allInHome = myPieces.every((p) => p.isHome);
    int d1 = 0, d2 = 0;

    do {
      setState(() => _isRollingDice = true);
      _diceAnimController.repeat();
      await Future.delayed(const Duration(milliseconds: 600));
      _diceAnimController.stop();
      _diceAnimController.reset();

      d1 = _random.nextInt(6) + 1;
      d2 = _random.nextInt(6) + 1;

      if (_isPlayingAgainstBot && _isBetMode && !_botIsWeak) {
        if (_random.nextInt(3) != 0) {
          if (d1 > 4) d1 = _random.nextInt(4) + 1;
          if (d2 > 4) d2 = _random.nextInt(4) + 1;
        }
      } else {
        final hasHomePieces = myPieces.any((p) => p.isHome);
        final humanMissed = _botMissedFive[_myColor] ?? 0;
        if (humanMissed >= 3 && hasHomePieces && d1 != 5 && d2 != 5) {
          if (_random.nextBool()) { d1 = 5; } else { d2 = 5; }
        }
        _botMissedFive[_myColor] = (hasHomePieces && d1 != 5 && d2 != 5) ? humanMissed + 1 : 0;
      }

      if (allInHome && d1 == d2 && d1 != 5) {
        _humanHomeDoubles++;
        setState(() { _dice1Value = d1; _dice2Value = d2; _isRollingDice = false; });
        if (_humanHomeDoubles >= 3) {
          _humanHomeDoubles = 0;
          _consecutiveDoubles = 0;
          _showEventToast(S.of(context).threeDoublesHome);
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; });
          _nextTurn();
          return;
        }
        _showEventToast(S.of(context).doubleHome);
        await Future.delayed(const Duration(milliseconds: 1200));
        setState(() { _dice1Value = 0; _dice2Value = 0; });
        continue;
      }
      _humanHomeDoubles = 0;
      break;
    } while (true);

    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    if (_consecutiveDoubles >= 3) {
      setState(() { _isRollingDice = false; _consecutiveDoubles = 0; });
      _showEventToast(S.of(context).tripleDouble);
      _applyTripleDoublesPenalty(_myColor);
      await Future.delayed(const Duration(milliseconds: 1500));
      _nextTurn();
      return;
    }

    _bridgeBreakPieceIds = (d1 == d2) ? _getBarreraIndices(_myColor) : {};

    setState(() {
      _dice1Value = d1; _dice2Value = d2;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _isRollingDice = false;
    });

    _calculateMovablePieces();
    if (_movablePieces.isEmpty) {
      _showEventToast(S.of(context).noValidMoves);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_gameEnded && mounted) _nextTurn();
    } else {
      _startTurnTimer();
    }
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
            (m) => m['pieceId'] == i, orElse: () => {});
        if (bm.isEmpty) continue;
        final pos = _getPieceScreenPos(pieces[i], _myColor, sq);
        if (pos == null) continue;
        final dist = (local - pos).distance;
        if (dist < bonusTapR && dist < closestDist) {
          closestDist = dist;
          closestId = i;
          closestBm = bm;
        }
      }

      if (closestId != null && closestBm != null) {
        _executeBonusMove(_myColor, closestId, closestBm['bonusPos'] as int, _bonusHadDouble);
      }
      return;
    }

    if (_movablePieces.isEmpty) return;
    for (int i = 0; i < pieces.length; i++) {
      if (!_movablePieces.any((m) => m['pieceId'] == i)) continue;
      final pos = _getPieceScreenPos(pieces[i], _myColor, sq);
      if (pos != null && (local - pos).distance < tapR) {
        _showMoveSelectionDialog(i);
        return;
      }
    }
  }

  void _showMoveSelectionDialog(int pieceId) {
    final opts = _movablePieces.where((m) => m['pieceId'] == pieceId).toList();
    if (opts.isEmpty) return;
    if (opts.length == 1) {
      _executePieceMove(_myColor, pieceId, opts[0]['diceValue'] as int, opts[0]['diceNumber'] as int);
      return;
    }
    showDialog(
      context: context, barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.of(ctx).whichDiceToUse,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...opts.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executePieceMove(_myColor, pieceId,
                        opt['diceValue'] as int, opt['diceNumber'] as int);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Dado ${opt['diceNumber']}: ${opt['diceValue']} casillas',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _executePieceMove(String color, int pieceId, int diceValue, int diceNumber) {
    if (_gameEnded) return;
    if (color == _myColor) _turnTimer?.cancel();

    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return;
    final piece = pieces[pieceId];
    final newPos = _calculateNewPosition(piece, diceValue, color);
    if (newPos == null || !_canLandOn(color, newPos, piece)) return;

    bool captured = false;
    final isExitingHome = newPos < 52 && piece.isHome && newPos == _getStartPosition(color);
    if (isExitingHome) {
      for (final ec in _activePlayers) {
        if (ec == color) continue;
        final enemyPiecesHere = _gameState.getPiecesByColor(ec)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPos)
            .toList();
        for (final ep in enemyPiecesHere) {
          ep.position = -1;
          captured = true;
        }
      }
    } else if (newPos < 52 && !_isSafeForColor(newPos, color)) {
      for (final ec in _activePlayers) {
        if (ec == color) continue;
        final enemyPiecesHere = _gameState.getPiecesByColor(ec)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPos)
            .toList();
        for (final ep in enemyPiecesHere) {
          ep.position = -1; captured = true;
        }
      }
    }

    piece.position = newPos;
    if (newPos == 57) piece.isFinished = true;
    _lastMovedPieceId[color] = pieceId;
    if (diceNumber == 1) {
      _hasUsedDice1 = true;
    } else {
      _hasUsedDice2 = true;
    }
    setState(() {});

    if (_checkVictory(color)) {
      _clearBotExecution();
      _endGame(color);
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;

    if (captured) {
      final remainingDie = !_hasUsedDice1 ? _dice1Value : (!_hasUsedDice2 ? _dice2Value : 0);
      final remainingNum = !_hasUsedDice1 ? 1 : (!_hasUsedDice2 ? 2 : 0);
      _bonusRemainingDie = hadDouble ? 0 : remainingDie;
      _bonusRemainingDieNumber = hadDouble ? 0 : remainingNum;
      _dice1Value = 0; _dice2Value = 0;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _movablePieces.clear();
      setState(() {});
      _prepareCaptureBonus(color, hadDouble);
      return;
    }

    _calculateMovablePieces();

    if (_movablePieces.isNotEmpty) {
      if (color == _myColor) {
        _startTurnTimer();
      } else {
        Future.delayed(Duration(milliseconds: 2400 + _random.nextInt(400)), _executeBotBestMove);
      }
      return;
    }

    _dice1Value = 0; _dice2Value = 0;
    _hasUsedDice1 = false; _hasUsedDice2 = false;
    _movablePieces.clear();
    setState(() {});

    if (hadDouble) {
      if (color == _myColor) {
        _startTurnTimer();
      } else {
        _clearBotExecution();
        _scheduleBotMove();
      }
    } else {
      if (color != _myColor) _clearBotExecution();
      _nextTurn();
    }
  }

  void _prepareCaptureBonus(String color, bool hadDouble) {
    final allPieces = _gameState.getPiecesByColor(color);
    _pendingBonusMoves.clear();

    for (int i = 0; i < allPieces.length; i++) {
      final p = allPieces[i];
      if (p.isFinished || p.isHome) continue;
      final bp = _calculateCaptureBonusPosition(p, color);
      if (bp == null) continue;
      _pendingBonusMoves.add({'pieceId': i, 'piece': p, 'bonusPos': bp});
    }

    if (_pendingBonusMoves.isEmpty) {
      if (hadDouble) {
        if (color == _myColor) {
          _startTurnTimer();
        } else {
          _clearBotExecution();
          _scheduleBotMove();
        }
      } else {
        if (color != _myColor) _clearBotExecution();
        _nextTurn();
      }
      return;
    }

    _bonusHadDouble = hadDouble;

    if (color == _myColor) {
      if (_pendingBonusMoves.length == 1) {
        final m = _pendingBonusMoves.first;
        _showEventToast('¡Capturaste! +20 casillas', color: Colors.green);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted || _gameEnded) return;
          _executeBonusMove(color, m['pieceId'] as int, m['bonusPos'] as int, hadDouble);
        });
      } else {
        _bonusSelectionActive = true;
        _movablePieces = _pendingBonusMoves.map((m) => {...m, 'diceValue': 20, 'diceNumber': 0}).toList();
        setState(() {});
        _showEventToast('¡Capturaste! Elige ficha para +20', color: Colors.green);
        _startTurnTimer();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _gameEnded) return;
        final best = _pendingBonusMoves.reduce((a, b) {
          final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition(color));
          final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition(color));
          return stA >= stB ? a : b;
        });
        _executeBonusMove(color, best['pieceId'] as int, best['bonusPos'] as int, hadDouble);
      });
    }
  }

  void _executeBonusMove(String color, int pieceId, int bonusPos, bool hadDouble) {
    _bonusSelectionActive = false;
    final pieces = _gameState.getPiecesByColor(color);
    if (pieceId >= pieces.length) return;
    final piece = pieces[pieceId];
    piece.position = bonusPos;
    if (bonusPos == 57) piece.isFinished = true;
    _pendingBonusMoves.clear();
    _movablePieces.clear();
    setState(() {});

    if (_checkVictory(color)) {
      _clearBotExecution();
      _endGame(color);
      return;
    }

    if (_bonusRemainingDie > 0) {
      if (_bonusRemainingDieNumber == 1) {
        _dice1Value = _bonusRemainingDie; _dice2Value = 0;
        _hasUsedDice1 = false; _hasUsedDice2 = true;
      } else {
        _dice1Value = 0; _dice2Value = _bonusRemainingDie;
        _hasUsedDice1 = true; _hasUsedDice2 = false;
      }
      _bonusRemainingDie = 0;
      _bonusRemainingDieNumber = 0;
      _calculateMovablePieces();
      if (_movablePieces.isNotEmpty) {
        if (color == _myColor) {
          _startTurnTimer();
        } else {
          Future.delayed(Duration(milliseconds: 2400 + _random.nextInt(400)), _executeBotBestMove);
        }
        return;
      }
    }

    if (hadDouble) {
      if (color == _myColor) {
        _startTurnTimer();
      } else {
        _clearBotExecution();
        _scheduleBotMove();
      }
    } else {
      if (color != _myColor) _clearBotExecution();
      _nextTurn();
    }
  }

  void _endMyTurn() {
    _dice1Value = 0; _dice2Value = 0;
    _hasUsedDice1 = false; _hasUsedDice2 = false;
    _movablePieces.clear();
    _bridgeBreakPieceIds = {};
    _nextTurn();
  }

  void _nextTurn() {
    if (_gameEnded || !mounted) return;
    final idx = _activePlayers.indexOf(_currentPlayer);
    final next = _activePlayers[(idx + 1) % _activePlayers.length];
    _humanHomeDoubles = 0;
    setState(() => _currentPlayer = next);

    if (next == _myColor) {
      _showTurnBannerAnim(S.of(context).yourTurn, _getPlayerColor(_myColor));
      _startTurnTimer();
    } else {
      _showTurnBannerAnim(
        'Turno de ${_botNames[next] ?? _opponentName}',
        _getPlayerColor(next),
      );
      Future.delayed(const Duration(milliseconds: 2800), _scheduleBotMove);
    }
  }

  void _applyTripleDoublesPenalty(String color) {
    final pieces = _gameState.getPiecesByColor(color);
    final active = pieces.where((p) => !p.isHome && !p.isFinished).toList();
    if (active.isEmpty) return;

    final lastId = _lastMovedPieceId[color];
    LudoPiece? target;
    if (lastId != null && lastId < pieces.length) {
      final last = pieces[lastId];
      if (!last.isHome && !last.isFinished) {
        target = last;
      }
    }
    if (target == null) {
      final sp = _getStartPosition(color);
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
      _showEventToast(S.of(context).tripleDouble, color: Colors.red.shade700);
    }
    setState(() {});
  }

  void _calculateMovablePieces() {
    _movablePieces.clear();
    final pieces = _gameState.getPiecesByColor(_currentPlayer);

    for (int i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (piece.isFinished) continue;

      if (piece.isHome) {
        if (!_hasUsedDice1 && _dice1Value == 5) {
          final sp = _getStartPosition(_currentPlayer);
          if (_canLandOn(_currentPlayer, sp, piece)) {
            _movablePieces.add({'pieceId': i, 'diceValue': 5, 'diceNumber': 1, 'piece': piece});
          }
        }
        if (!_hasUsedDice2 && _dice2Value == 5 && (_dice1Value != _dice2Value || _hasUsedDice1)) {
          final sp = _getStartPosition(_currentPlayer);
          if (_canLandOn(_currentPlayer, sp, piece)) {
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
      final pieces = _gameState.getPiecesByColor(_currentPlayer);
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

    if (mounted) setState(() {});
  }

  bool _canMovePieceWithValue(LudoPiece piece, int dv) {
    if (piece.isFinished) return false;
    if (piece.isHome) return dv == 5;
    final np = _calculateNewPosition(piece, dv, _currentPlayer);
    if (np == null) return false;
    if (_hasBarrierInPath(piece, dv, _currentPlayer)) return false;
    return _canLandOn(_currentPlayer, np, piece);
  }

  void _clearBotExecution() {
    _botSafetyTimer?.cancel();
    _botExecuting = false;
  }

  void _scheduleBotMove() {
    if (_gameEnded || !_isBotTurn) return;
    if (_botExecuting) return;
    _botExecuting = true;
    _botSafetyTimer?.cancel();
    _botSafetyTimer = Timer(const Duration(seconds: 25), () {
      if (!mounted || _gameEnded) return;
      _botExecuting = false;
      _dice1Value = 0;
      _dice2Value = 0;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _movablePieces.clear();
      if (_isBotTurn) _nextTurn();
    });
    final thinkTime = 2600 + _random.nextInt(800);
    Future.delayed(Duration(milliseconds: thinkTime), () {
      _executeBotTurn();
    });
  }

  (int, int) _chooseBotDice() {
    if (_botIsWeak) {
      int bestScore = double.maxFinite.toInt();
      int bestD1 = _random.nextInt(6) + 1;
      int bestD2 = _random.nextInt(6) + 1;
      for (int i = 0; i < 6; i++) {
        final cd1 = _random.nextInt(6) + 1;
        final cd2 = _random.nextInt(6) + 1;
        final score = _scoreDicePair(cd1, cd2);
        if (score < bestScore) { bestScore = score; bestD1 = cd1; bestD2 = cd2; }
      }
      return (bestD1, bestD2);
    }

    if (!_isBetMode) {
      int bestScore = -1;
      int bestD1 = _random.nextInt(6) + 1;
      int bestD2 = _random.nextInt(6) + 1;
      for (int i = 0; i < 16; i++) {
        final cd1 = _random.nextInt(6) + 1;
        final cd2 = _random.nextInt(6) + 1;
        final score = _scoreDicePair(cd1, cd2);
        if (score > bestScore) { bestScore = score; bestD1 = cd1; bestD2 = cd2; }
      }
      return (bestD1, bestD2);
    }

    _botTurnCounter++;
    final isWeakTurn = (_botTurnCounter % 3 == 0);

    if (isWeakTurn) {
      final d1 = _random.nextInt(2) + 1;
      final d2 = _random.nextInt(2) + 1;
      return (d1, d2);
    }

    int bestScore = -1;
    int bestD1 = 1, bestD2 = 1;
    for (int d1 = 1; d1 <= 6; d1++) {
      for (int d2 = 1; d2 <= 6; d2++) {
        if (_consecutiveDoubles >= 2 && d1 == d2) continue;
        final score = _scoreDicePair(d1, d2);
        if (score > bestScore) { bestScore = score; bestD1 = d1; bestD2 = d2; }
      }
    }
    return (bestD1, bestD2);
  }

  int _scoreDicePair(int d1, int d2) {
    final bc = _currentPlayer;
    final botPieces = _gameState.getPiecesByColor(bc);

    int bestSingle = 0;
    for (final dv in {d1, d2}) {
      for (final p in botPieces) {
        if (p.isFinished) continue;
        final np = _calculateNewPosition(p, dv, bc);
        if (np == null || !_canLandOn(bc, np, p)) continue;
        final s = _scoreSingleAction(p, np);
        if (s > bestSingle) bestSingle = s;
      }
    }

    int bestCombo = 0;
    for (final p1 in botPieces) {
      if (p1.isFinished) continue;
      final np1 = _calculateNewPosition(p1, d1, bc);
      if (np1 == null || !_canLandOn(bc, np1, p1)) continue;
      final s1 = _scoreSingleAction(p1, np1);

      int bestS2 = 0;
      for (final p2 in botPieces) {
        if (p2.isFinished) continue;
        final pos2 = (p2.id == p1.id) ? np1 : p2.position;
        final tempPiece = LudoPiece(id: p2.id, color: p2.color, position: pos2, isFinished: p2.isFinished);
        final np2 = _calculateNewPosition(tempPiece, d2, bc);
        if (np2 == null || !_canLandOn(bc, np2, tempPiece)) continue;
        final s2 = _scoreSingleAction(tempPiece, np2);
        if (s2 > bestS2) bestS2 = s2;
      }
      final combo = s1 + (bestS2 * 6 ~/ 10);
      if (combo > bestCombo) bestCombo = combo;
    }

    return max(bestSingle, bestCombo);
  }

  int _scoreSingleAction(LudoPiece piece, int np) {
    final bc = piece.color;
    int s = 0;
    if (np < 52 && !_isSafeForColor(np, bc)) {
      for (final ec in _activePlayers) {
        if (ec == bc) continue;
        final hit = _gameState.getPiecesByColor(ec)
            .where((ep) => !ep.isHome && !ep.isFinished && ep.position == np).length;
        if (hit == 1) {
          final ep = _gameState.getPiecesByColor(ec).firstWhere((e) => !e.isHome && !e.isFinished && e.position == np);
          final enemyAdv = _stepsFromStart(ep.position, _getStartPosition(ec));
          s += 10000 + enemyAdv * 20;
        }
      }
    }
    if (np == 57) {
      s += 900;
    } else if (np >= 52 && piece.position < 52) {s += 450;}
    else if (np >= 52) {s += np * 20;}
    if (piece.isHome) s += 600;
    if (!piece.isHome && piece.position < 52) {
      s += _stepsFromStart(piece.position, _getStartPosition(bc)) * 6;
    }

    if (np < 52 && _isSafeForColor(np, bc)) s += 80;
    if (np < 52) {
      final allies = _gameState.getPiecesByColor(bc)
          .where((bp) => !bp.isFinished && !bp.isHome && bp.id != piece.id && bp.position == np).length;
      if (allies == 1) s += 200;
    }
    return s;
  }

  Future<void> _executeBotTurn() async {
    if (_gameEnded || !mounted || _isMyTurn) { _clearBotExecution(); return; }
    final bc = _currentPlayer;

    final botPieces = _gameState.getPiecesByColor(bc);
    final allInHome = botPieces.every((p) => p.isHome);
    int d1 = 0, d2 = 0;

    do {
      (d1, d2) = _chooseBotDice();

      final hasHomePieces = botPieces.any((p) => p.isHome);
      final missedCount = _botMissedFive[bc] ?? 0;
      if (missedCount >= 3 && hasHomePieces && d1 != 5 && d2 != 5) {
        if (_random.nextBool()) { d1 = 5; } else { d2 = 5; }
      }
      _botMissedFive[bc] = (hasHomePieces && d1 != 5 && d2 != 5) ? missedCount + 1 : 0;

      if (allInHome && d1 == d2 && d1 != 5) {
        _botHomeDoubles[bc] = (_botHomeDoubles[bc] ?? 0) + 1;
        setState(() { _dice1Value = d1; _dice2Value = d2; });
        if ((_botHomeDoubles[bc] ?? 0) >= 3) {
          _botHomeDoubles[bc] = 0;
          _consecutiveDoubles = 0;
          _showEventToast('$_currentBotName: tres dobles en casa, pierde turno');
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; });
          _clearBotExecution();
          _nextTurn();
          return;
        }
        _showEventToast('$_currentBotName: doble en casa, vuelve a tirar');
        await Future.delayed(const Duration(milliseconds: 1200));
        setState(() { _dice1Value = 0; _dice2Value = 0; });
        continue;
      }
      _botHomeDoubles[bc] = 0;
      break;
    } while (true);

    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    if (_consecutiveDoubles >= 3) {
      _consecutiveDoubles = 0;
      _applyTripleDoublesPenalty(bc);
      setState(() {});
      _showEventToast('$_currentBotName perdió el turno (3 dobles)');
      await Future.delayed(const Duration(milliseconds: 1500));
      _clearBotExecution();
      _nextTurn();
      return;
    }

    setState(() {
      _dice1Value = d1; _dice2Value = d2;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
    });

    await Future.delayed(Duration(milliseconds: 4200 + _random.nextInt(800)));

    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      _showEventToast('$_currentBotName no tiene movimientos');
      await Future.delayed(const Duration(milliseconds: 1200));
      setState(() { _dice1Value = 0; _dice2Value = 0; });
      _clearBotExecution();
      _nextTurn();
      return;
    }

    await _executeBotBestMove();
  }

  Future<void> _executeBotBestMove() async {
    if (_gameEnded || _isMyTurn) { _clearBotExecution(); return; }
    final bc = _currentPlayer;
    _calculateMovablePieces();
    if (_movablePieces.isEmpty) {
      final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;
      _dice1Value = 0; _dice2Value = 0;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      setState(() {});
      _clearBotExecution();
      if (hadDouble) {
        _scheduleBotMove();
      } else {
        _nextTurn();
      }
      return;
    }

    int bestScore = _botIsWeak ? double.maxFinite.toInt() : -1;
    Map<String, dynamic>? bestMove;

    for (final move in _movablePieces) {
      final piece = move['piece'] as LudoPiece;
      final dv = move['diceValue'] as int;
      final np = _calculateNewPosition(piece, dv, bc);
      if (np == null) continue;

      int score = _scoreSingleAction(piece, np);

      if (np < 52 && !_isSafeForColor(np, bc) && !piece.isHome) {
        int threatCount = 0;
        for (final ec in _activePlayers) {
          if (ec == bc) continue;
          for (final ep in _gameState.getPiecesByColor(ec)) {
            if (ep.isHome || ep.isFinished) continue;
            for (int dv2 = 1; dv2 <= 6; dv2++) {
              if (_calculateNewPosition(ep, dv2, ec) == np) { threatCount++; break; }
            }
          }
        }
        if (threatCount > 0) score -= 350 * threatCount;
      }

      final better = _botIsWeak ? score < bestScore : score > bestScore;
      if (better) { bestScore = score; bestMove = move; }
    }
    bestMove ??= _movablePieces.first;
    await Future.delayed(Duration(milliseconds: 2400 + _random.nextInt(400)));

    if (mounted && !_gameEnded) {
      _executePieceMove(
        bc,
        bestMove['pieceId'] as int,
        bestMove['diceValue'] as int,
        bestMove['diceNumber'] as int,
      );
    }
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

  bool _hasBarrierInPath(LudoPiece piece, int dv, String color) {
    if (piece.isHome || piece.position >= 52) return false;
    final sp = _getStartPosition(color);
    for (int step = 1; step < dv; step++) {
      final ns = _stepsFromStart(piece.position, sp) + step;
      if (ns >= 51) break;
      final pos = (sp + ns) % 52;
      if (_isAnyBarrierAt(pos)) return true;
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

  bool _isEnemyBarrierAt(int pos, String movingColor) {
    for (final ec in _activePlayers) {
      if (ec == movingColor) continue;
      final count = _gameState.getPiecesByColor(ec)
          .where((p) => !p.isHome && !p.isFinished && p.position == pos).length;
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
    final myCount = _gameState.getPiecesByColor(color)
        .where((p) => p != moving && !p.isHome && !p.isFinished && p.position == newPos)
        .length;
    if (myCount >= 2) return false;
    if (moving.isHome && newPos == _getStartPosition(color) && _isEnemyBarrierAt(newPos, color)) {
      return true;
    }
    if (_isEnemyBarrierAt(newPos, color)) return false;
    return true;
  }

  int? _calculateCaptureBonusPosition(LudoPiece piece, String color) {
    if (piece.isFinished || piece.isHome) return null;
    if (piece.position >= 52) return null;
    final sp = _getStartPosition(color);
    final currentSteps = _stepsFromStart(piece.position, sp);
    for (int bonus = 1; bonus <= 20; bonus++) {
      final ns = currentSteps + bonus;
      final int candidatePos;
      if (ns >= 51) {
        final into = ns - 51;
        if (into > 5) return null;
        candidatePos = 52 + into;
      } else {
        candidatePos = (sp + ns) % 52;
      }
      if (candidatePos < 52 && _isAnyBarrierAt(candidatePos)) return null;
      if (candidatePos == 57 && bonus < 20) return null;
      if (bonus == 20) return candidatePos;
    }
    return null;
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
    const starPositions = {4, 8, 17, 21, 30, 34, 43, 47};
    if (starPositions.contains(pos)) return true;
    if (pos == _getStartPosition(color)) return true;
    return false;
  }

  Offset? _getPieceScreenPos(LudoPiece piece, String color, double sq) {
    if (piece.isHome) return _homeScreenPos(color, piece.id, sq);
    if (piece.isFinished) return null;
    if (piece.position >= 52 && piece.position <= 56) {
      return _homeStretchPos(color, piece.position, sq);
    }
    return _boardPos(piece, color, sq);
  }

  Offset _homeStretchPos(String color, int pos, double sq) {
    final si = pos - 52;
    switch (color) {
      case 'green':  return Offset(7.5 * sq, (1.0 + si) * sq);
      case 'red':    return Offset((1.0 + si) * sq, 7.5 * sq);
      case 'blue':   return Offset(7.5 * sq, (13.0 - si) * sq);
      case 'yellow': return Offset((13.0 - si) * sq, 7.5 * sq);
      default:       return Offset(7.5 * sq, 7.5 * sq);
    }
  }

  Offset? _boardPos(LudoPiece piece, String color, double sq) {
    if (piece.position < 0 || piece.position >= _boardPath.length) return null;
    final c = _boardPath[piece.position];
    final base = Offset((c.col + 0.5) * sq, (c.row + 0.5) * sq);
    final samePos = _gameState.getPiecesByColor(color)
        .where((p) => !p.isHome && !p.isFinished && p.position == piece.position).toList();
    if (samePos.length <= 1) return base;
    final idx = samePos.indexOf(piece);
    final off = sq * 0.28;
    return idx == 0 ? base - Offset(off, 0) : base + Offset(off, 0);
  }

  Offset _homeScreenPos(String color, int id, double sq) {
    const homes = {
      'green': _Coord(3, 3), 'yellow': _Coord(12, 3),
      'red': _Coord(3, 12), 'blue': _Coord(12, 12),
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
    _botSafetyTimer?.cancel();
    _awayTimer?.cancel();
    final isBet = _isBetMode;
    final isWin = winnerColor == _myColor;

    if (isBet && _isPlayingAgainstBot) {
      BotNameService.recordBetResult(playerWon: isWin);
    }

    if (isWin && _currentUser != null) {
      final betAmount = isBet ? (_selectedBetAmount ?? 25) : 100;
      final hasBots = _botColors.isNotEmpty;
      final int playerCount = _activePlayers.length;
      final int prize = hasBots
          ? (isBet ? (betAmount + (betAmount * 0.7).ceil()) : (betAmount * 2))
          : (isBet
              ? (betAmount * playerCount * 0.9).floor()
              : (betAmount * playerCount * 0.7).floor());
      if (isBet) {
        _firestoreService.incrementUserDiamondsEarned(_currentUser!.uid, prize);
      } else {
        _firestoreService.incrementUserCoins(_currentUser!.uid, prize);
        if (mounted) setState(() => _userCoins = (_userCoins ?? 0) + prize);
      }
    }

    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    final winnerEmoji = _botEmojis[winnerColor] ?? _opponentEmoji;
    final winnerName  = _botNames[winnerColor]  ?? _opponentName;
    _showGameEndDialog(isWin, '$winnerEmoji $winnerName');
  }

  Future<void> _recordResult(GameResultModel result) async {
    if (_gameStartTime == null || _currentUser == null) return;
    try {
      final dur = DateTime.now().difference(_gameStartTime!).inMinutes;
      await _firestoreService.recordGameMatch(
        userId: _currentUser!.uid,
        gameType: GameTypeModel.ludo,
        result: result,
        pointsEarned: result == GameResultModel.win ? 20 : -5,
        durationMinutes: dur > 0 ? dur : 1,
        opponentName: _opponentName,
        additionalData: {'matchType': widget.matchType, 'playerColor': _myColor, 'vsBot': true},
      );
    } catch (_) {}
  }

  void _showGameEndDialog(bool isWin, String opponentLabel) {
    if (!mounted) return;
    final isBet = _isBetMode;
    final betAmt = isBet ? (_selectedBetAmount ?? 25) : 100;
    final hasBots = _botColors.isNotEmpty;
    final int playerCount = _activePlayers.length;
    final int totalPrize = hasBots
        ? (isBet ? (betAmt + (betAmt * 0.7).ceil()) : (betAmt * 2))
        : (isBet
            ? (betAmt * playerCount * 0.9).floor()
            : (betAmt * playerCount * 0.7).floor());
    final netGain = totalPrize - betAmt;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isWin ? Colors.amber : const Color(0xFFEC7A34), width: 2),
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
                isWin ? S.of(ctx).victory : S.of(ctx).endOfGame,
                style: TextStyle(
                  color: isWin ? Colors.amber.shade700 : const Color(0xFFEC7A34),
                  fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(opponentLabel,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  textAlign: TextAlign.center),
              if (isWin && isBet) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '+$netGain 💎 ganados',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.of(ctx).pop(); Navigator.of(context).pop(); },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(S.of(ctx).exit),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _restartBotGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(S.of(ctx).playAgain, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _restartBotGame() {
    final isBet = _isBetMode;
    final cost = isBet ? (_selectedBetAmount ?? 25) : 100;
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    if (balance < cost) { _showInsufficientFundsDialog(); return; }

    if (_currentUser != null) {
      if (isBet) {
        _firestoreService.incrementUserDiamonds(_currentUser!.uid, -cost);
      } else {
        _firestoreService.incrementUserCoins(_currentUser!.uid, -cost);
      }
    }

    setState(() {
      if (isBet) {
        _userDiamonds = (_userDiamonds ?? 0) - cost;
      } else {
        _userCoins = (_userCoins ?? 0) - cost;
      }
      _gameState = LudoGameState.initial();
      _currentPlayer = 'yellow';
      _dice1Value = 0; _dice2Value = 0;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _consecutiveDoubles = 0;
      _movablePieces.clear();
      _bonusSelectionActive = false;
      _gameEnded = false;
      _gameStartTime = DateTime.now();
      _botMissedFive.clear();
      _humanHomeDoubles = 0;
      _botHomeDoubles.clear();
    });
    _showTurnBannerAnim(S.of(context).yourTurn, _getPlayerColor(_myColor));
    _startTurnTimer();
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(S.of(context).parchisOnline, style: const TextStyle(color: Colors.white)),
        elevation: 2,
        actions: [
          if (_screenState != _LudoOnlineState.gameActive && widget.matchType == 'Apuesta')
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
          if (_screenState == _LudoOnlineState.gameActive && !_gameEnded && _activeGameId != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: () => _chatKey.currentState?.toggleChat(),
              tooltip: 'Chat',
            ),
          if (_screenState == _LudoOnlineState.gameActive && !_gameEnded)
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(S.of(ctx).abandonGame),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          S.of(ctx).abandonWarningBet,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(S.of(ctx).cancel, style: const TextStyle(color: Colors.green)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(S.of(ctx).abandonGame),
                      ),
                    ],
                  ),
                );
                if (confirm == true) _endGame(_botColors.first);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildBody()),
              const BannerAdWidget(),
            ],
          ),
          if (_activeGameId != null)
            GameChatWidget(
              key: _chatKey,
              gameId: _activeGameId!,
              collectionName: 'ludo_games',
              currentUserId: _currentUser?.uid ?? '',
              currentUserName: _currentUser?.displayName ?? 'Jugador',
              showFloatingBubbles: false,
              onNewMessageFromOther: (senderId, _) {
                setState(() => _lastMsgSenderId = senderId);
                _msgBubbleTimer?.cancel();
                _msgBubbleTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _lastMsgSenderId = null);
                });
              },
              onNewMessageWithText: (senderId, _, text) {
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
                setState(() => _ownMsgText = text);
                _ownMsgBubbleTimer?.cancel();
                _ownMsgBubbleTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _ownMsgText = null);
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case _LudoOnlineState.playerCountSelection:
        return _buildPlayerCountSelection();
      case _LudoOnlineState.matchmaking:
        return _buildMatchmaking();
      case _LudoOnlineState.waitingRoom:
        return _buildWaitingRoom();
      case _LudoOnlineState.gameActive:
        return _buildGameActive();
    }
  }

  Widget _buildGameActive() {
    return Stack(
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
                          if (_isMyTurn && !_bonusSelectionActive) {
                            for (final m in _movablePieces) {
                              movableKeys.add('$_myColor-${m['pieceId']}');
                            }
                          }
                          if (_bonusSelectionActive) {
                            for (final m in _pendingBonusMoves) {
                              movableKeys.add('$_myColor-${m['pieceId']}');
                            }
                          }
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: sz, height: sz,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getPlayerColor(_currentPlayer).withValues(alpha: 0.35),
                                      blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 4),
                                    ),
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
                              _buildBoardChatBubbles(sz),
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
            _buildGameControls(),
          ],
        ),
        if (_showTurnBanner)
          Positioned(
            top: 80, left: 0, right: 0,
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
            bottom: 90, left: 20, right: 20,
            child: AnimatedBuilder(
              animation: _toastAnim,
              builder: (ctx, _) => Opacity(
                opacity: _toastAnim.value,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87, borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_toastMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoardPlayerLabels(double sz) {
    const pad = 8.0;
    final colorNames = <String, String>{
      _myColor: 'Yo',
      for (final bc in _botColors)
        bc: (_botNames[bc] ?? _opponentName).split(' ').first.isEmpty
            ? 'Bot'
            : (_botNames[bc] ?? _opponentName).split(' ').first,
    };

    Widget lbl(String color, {double? top, double? bottom, double? left, double? right}) {
      final name = colorNames[color];
      if (name == null) return const SizedBox.shrink();
      final pc = _getPlayerColor(color);
      final isActive = color == _currentPlayer;
      final isMe = color == _myColor;
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

  Widget _buildBoardChatBubbles(double sz) {
    const pad = 28.0;
    List<Widget> bubbles = [];

    if (_ownMsgText != null) {
      final pos = _bubblePositionForColor(_myColor, sz, pad);
      if (pos != null) {
        bubbles.add(Positioned(
          top: pos.top, bottom: pos.bottom, left: pos.left, right: pos.right,
          child: _buildLudoChatBubble(_ownMsgText!, isMe: true),
        ));
      }
    }

    if (_lastMsgText != null && _lastMsgSenderId != null) {
      String? senderColor;
      for (final bc in _botColors) {
        senderColor = bc;
        break;
      }
      if (senderColor != null) {
        final pos = _bubblePositionForColor(senderColor, sz, pad);
        if (pos != null) {
          bubbles.add(Positioned(
            top: pos.top, bottom: pos.bottom, left: pos.left, right: pos.right,
            child: _buildLudoChatBubble(_lastMsgText!, isMe: false),
          ));
        }
      }
    }

    if (bubbles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: sz, height: sz,
      child: Stack(children: bubbles),
    );
  }

  ({double? top, double? bottom, double? left, double? right})? _bubblePositionForColor(String color, double sz, double pad) {
    switch (color) {
      case 'green':
        return (top: pad, bottom: null, left: pad, right: null);
      case 'yellow':
        return (top: pad, bottom: null, left: null, right: pad);
      case 'red':
        return (top: null, bottom: pad, left: pad, right: null);
      case 'blue':
        return (top: null, bottom: pad, left: null, right: pad);
      default:
        return null;
    }
  }

  Widget _buildLudoChatBubble(String text, {required bool isMe}) {
    final isEmoji = text.characters.length <= 3 && !text.contains(RegExp(r'[a-zA-Z0-9]'));
    return TweenAnimationBuilder<double>(
      key: ValueKey('ludo_bubble_${isMe ? 'me' : 'other'}_$text'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: EdgeInsets.symmetric(horizontal: isEmoji ? 6 : 10, vertical: isEmoji ? 4 : 6),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFEC7A34) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isEmoji ? 28 : 12,
            color: isMe ? Colors.white : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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
                    onTap: () {
                      if (_activeGameId == null) return;
                      GameChatService(collectionName: 'ludo_games', gameId: _activeGameId!).sendMessage(
                        senderId: _currentUser?.uid ?? '',
                        senderName: _currentUser?.displayName ?? 'Jugador',
                        text: quickEmojis[i],
                      );
                      setState(() => _ownMsgText = quickEmojis[i]);
                      _ownMsgBubbleTimer?.cancel();
                      _ownMsgBubbleTimer = Timer(const Duration(seconds: 4), () {
                        if (mounted) setState(() => _ownMsgText = null);
                      });
                    },
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
            onTap: () => _chatKey.currentState?.toggleChat(),
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

  Widget _buildGameControls() {
    final canRoll = _isMyTurn && !_gameEnded && _dice1Value == 0 && _dice2Value == 0 && !_isRollingDice && !_bonusSelectionActive;
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
            child: !_isMyTurn
                ? Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: _getPlayerColor(_currentPlayer),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pensando $_currentBotName...',
                        style: TextStyle(
                          fontSize: 12, color: _getPlayerColor(_currentPlayer),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ])
                : canRoll
                    ? ElevatedButton.icon(
                        onPressed: _rollDice,
                        icon: const Icon(Icons.casino, size: 20),
                        label: const Text('Lanzar dados', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      )
                    : _bonusSelectionActive
                        ? const Text(
                            'Toca ficha para +20',
                            style: TextStyle(fontSize: 13, color: Colors.green,
                                fontWeight: FontWeight.bold),
                          )
                        : const Text(
                            'Toca una ficha para mover',
                            style: TextStyle(fontSize: 12, color: Color(0xFFEC7A34),
                                fontWeight: FontWeight.w600),
                          ),
          ),
          if (_isMyTurn && !_gameEnded && _turnTimerSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _turnTimerSeconds <= 10 ? Colors.red : Colors.green.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$_turnTimerSeconds"',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiceWidget(int value, bool used) {
    return AnimatedBuilder(
      animation: _diceRotation,
      builder: (ctx, _) => Transform.rotate(
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
                : CustomPaint(size: const Size(34, 34), painter: _DiceDotsPainter(value)),
          ),
        ),
      ),
    );
  }

  Widget _buildBetSelection() {
    final balance = _userDiamonds ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(S.of(context).howMuchBet,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Elige el monto de diamantes para esta partida',
            style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _betOptions.map((amount) {
              final isSelected = _selectedBetAmount == amount;
              final canAfford = balance >= amount;
              return GestureDetector(
                onTap: canAfford ? () => setState(() => _selectedBetAmount = amount) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.shade600
                        : (canAfford ? Colors.white : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.amber.shade700 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.diamond,
                          color: isSelected
                              ? Colors.white
                              : (canAfford ? Colors.amber.shade600 : Colors.grey.shade400),
                          size: 14),
                      const SizedBox(width: 4),
                      Text(
                        amount.toString(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (canAfford ? Colors.black87 : Colors.grey.shade500),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCountSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC7A34), Color(0xFFFF9A5C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: const Color(0xFFEC7A34).withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text('🎲', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context).parchisOnline,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(S.of(context).searchingRealPlayers,
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text(S.of(context).howManyPlayers,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Elige el número de jugadores para la partida',
              style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 20),

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
                    width: 80, height: 100,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFEC7A34) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: sel ? const Color(0xFFEC7A34) : Colors.grey.shade300,
                          width: sel ? 2 : 1),
                      boxShadow: sel
                          ? [BoxShadow(color: const Color(0xFFEC7A34).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_getCountIcon(n), style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text('$n jugadores',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: sel ? Colors.white : Colors.black87),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          if (_isBetMode) _buildBetSelection(),

          if (_userCoins != null || _userDiamonds != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isBetMode ? Icons.diamond : Icons.monetization_on,
                      color: _isBetMode ? Colors.blue : Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tu balance: ${_isBetMode ? '${_userDiamonds ?? 0} diamantes' : '${_userCoins ?? 0} monedas'}',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isBetMode && _selectedBetAmount == null)
                  ? null
                  : _startMatchmaking,
              icon: const Icon(Icons.search, size: 22),
              label: Text(S.of(context).searchGame,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showInviteFriendDialog(context),
              icon: const Icon(Icons.person_add, size: 20),
              label: Text(S.of(context).inviteFriend,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEC7A34),
                side: const BorderSide(color: Color(0xFFEC7A34), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text('Reglas clave',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700, fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                const Text('• Saca 5 con cualquier dado para salir de casa', style: TextStyle(fontSize: 12)),
                const Text('• Dobles = turno extra • 3 dobles seguidos = turno perdido', style: TextStyle(fontSize: 12)),
                const Text('• Capturar una ficha da +20 casillas de bonus', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCountIcon(int n) {
    switch (n) {
      case 2: return '👥';
      case 3: return '👨‍👩‍👦';
      case 4: return '👨‍👩‍👧‍👦';
      default: return '🎮';
    }
  }

  Widget _buildMatchmaking() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 80, height: 80,
              child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFEC7A34))),
            const SizedBox(height: 32),
            Text(S.of(context).searchingRealPlayers,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${(60 - _matchmakingSeconds).clamp(0, 60)}"',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _matchmakingSeconds >= 50 ? Colors.red : const Color(0xFFEC7A34),
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
              onPressed: _cancelMatchmaking,
              icon: const Icon(Icons.close),
              label: Text(S.of(context).cancelSearch),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
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
    final game = _currentRoomGame;
    final joined = game?.playerCount ?? 1;
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
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const Text('🎲', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(S.of(context).waitingRoom,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$joined / $_selectedPlayerCount jugadores',
                      style: const TextStyle(fontSize: 16, color: Color(0xFFEC7A34), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: joined / _selectedPlayerCount,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFFEC7A34), minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRoomPlayers(game),
                  const SizedBox(height: 12),
                  if (remaining > 0) ...[
                    const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFEC7A34))),
                    const SizedBox(height: 6),
                    Text('Esperando $remaining ${remaining == 1 ? 'jugador más' : 'jugadores más'}...',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      'Iniciando en ${(60 - _matchmakingSeconds).clamp(0, 60)}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _matchmakingSeconds >= 50 ? FontWeight.bold : FontWeight.normal,
                        color: _matchmakingSeconds >= 50 ? Colors.orange.shade700 : Colors.grey,
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    Text(S.of(context).allReadyStarting,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            if (_activeGameId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Código: ${_activeGameId!.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 16),
            if (_myPlayerNumber == 1 &&
                (_currentRoomGame?.playerCount ?? 1) < _selectedPlayerCount) ...[
              ElevatedButton.icon(
                onPressed: () => _showInviteFriendDialog(context),
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(S.of(context).inviteFriend),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC7A34),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _cancelMatchmaking,
              icon: const Icon(Icons.close),
              label: Text(S.of(context).cancel),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomPlayers(LudoGameMatch? game) {
    final names = [game?.hostName, game?.guest2Name, game?.guest3Name, game?.guest4Name];
    final playerColors = ['green', 'red', 'blue', 'yellow'];
    final assigned = game != null
        ? [game.player1Color, game.player2Color, game.player3Color, game.player4Color]
        : playerColors;
    final colorNames = {'green': 'Verde', 'red': 'Rojo', 'blue': 'Azul', 'yellow': 'Amarillo'};

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_selectedPlayerCount, (i) {
        final color = assigned[i] ?? playerColors[i];
        final col = _getPlayerColor(color);
        final name = names[i];
        final isMe = (i + 1) == _myPlayerNumber;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: name != null ? col : col.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: name != null ? col : Colors.grey.shade300, width: isMe ? 3 : 2),
                    ),
                    child: Center(
                      child: Icon(name != null ? Icons.person : Icons.person_outline,
                          color: name != null ? Colors.white : Colors.grey, size: 22),
                    ),
                  ),
                  if (isMe)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                name != null ? (isMe ? 'Yo' : name.split(' ').first) : (colorNames[color] ?? '?'),
                style: TextStyle(fontSize: 10,
                    color: name != null ? col : Colors.grey,
                    fontWeight: name != null ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showInviteFriendDialog(BuildContext context) {
    if (_currentUser == null) return;

    final isBet = _isBetMode;
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final minRequired = isBet ? (_selectedBetAmount ?? 25) : 100;
    if (balance < minRequired) {
      _showInsufficientFundsDialog();
      return;
    }

    final emailController = TextEditingController();
    final betController = TextEditingController();
    bool isLoading = false;
    String? betError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          bool isValid = emailController.text.trim().isNotEmpty &&
              (!isBet || (betController.text.isNotEmpty && betError == null));

          void validateBet(String v) {
            setDlg(() {
              final n = int.tryParse(v);
              if (v.isEmpty) {
                betError = 'Ingresa un monto';
              } else if (n == null || n < 1) {
                betError = 'Monto inválido';
              } else if (n > balance) {
                betError = 'Saldo insuficiente (tienes $balance)';
              } else {
                betError = null;
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(S.of(ctx).inviteFriend,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBet ? Icons.diamond : Icons.monetization_on,
                            color: isBet ? Colors.blue : Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tu saldo: $balance ${isBet ? 'diamantes' : 'monedas'}',
                            style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC7A34).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🎲', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text('$_selectedPlayerCount jugadores',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setDlg(() {}),
                      decoration: InputDecoration(
                        labelText: S.of(ctx).friendEmailLabel,
                        hintText: 'ejemplo@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (isBet) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: betController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        onChanged: validateBet,
                        decoration: InputDecoration(
                          labelText: 'Monto a apostar (diamantes)',
                          prefixIcon:
                              const Icon(Icons.diamond, color: Colors.amber),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          errorText: betError,
                          helperText: 'Disponible: $balance diamantes',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [10, 25, 50, 100, 250].map((n) {
                          final ok = n <= balance;
                          return ActionChip(
                            label: Text('$n'),
                            onPressed: ok && !isLoading
                                ? () {
                                    betController.text = '$n';
                                    validateBet('$n');
                                  }
                                : null,
                            backgroundColor: ok
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.grey.shade200,
                            labelStyle: TextStyle(
                                color: ok ? Colors.amber.shade800 : Colors.grey,
                                fontWeight: FontWeight.bold),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (isLoading || !isValid)
                            ? null
                            : () async {
                                setDlg(() => isLoading = true);
                                Navigator.of(ctx).pop();
                                await _inviteFriendAndStartWaiting(
                                  email: emailController.text.trim(),
                                  betAmount: isBet
                                      ? int.tryParse(betController.text.trim())
                                      : null,
                                );
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: Text(isLoading ? S.of(ctx).sending : S.of(ctx).sendInvitation,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _inviteFriendAndStartWaiting({
    required String email,
    int? betAmount,
  }) async {
    if (_currentUser == null || !mounted) return;

    final currencyType = _currencyType;

    final bool isNewGame = _activeGameId == null;
    String? gameId = _activeGameId;

    if (isNewGame) {
      try {
        gameId = await _gameService.createGame(
          hostId: _currentUser!.uid,
          hostName: _myName ?? 'Jugador',
          hostPhotoUrl: _myPhotoUrl,
          currencyType: currencyType,
          betAmount: betAmount,
          numberOfPlayers: _selectedPlayerCount,
          isOnlineMatchmaking: false,
        );
      } catch (e) {
        if (kDebugMode) print('Error creando sala para invitación: $e');
      }
    }

    if (gameId == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al crear la sala. Intenta de nuevo.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final error = await GameInvitationService().createInvitation(
      fromUserId: _currentUser!.uid,
      fromUserName: _myName ?? 'Jugador',
      toUserEmail: email,
      gameType: 'Parchís',
      betAmount: betAmount,
      currencyType: currencyType,
      existingGameId: gameId,
      numberOfPlayers: _selectedPlayerCount,
    );

    if (!mounted) return;

    if (error != null) {
      if (isNewGame) {
        _firestore.collection('ludo_games').doc(gameId).update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    if (isNewGame) {
      _activeGameId = gameId;
      _myPlayerNumber = 1;
      setState(() => _screenState = _LudoOnlineState.waitingRoom);
      _listenToRoomGame(gameId);
      _startKeepAlive(gameId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(S.of(context).invitationSentWaiting),
          backgroundColor: Colors.green),
    );
  }

  void _showInsufficientFundsDialog() {
    final isBet = _isBetMode;
    final required = isBet ? (_selectedBetAmount ?? 25) : 100;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fondos insuficientes'),
        content: Text(isBet
            ? 'Necesitas al menos $required diamantes para jugar.\nTienes: ${_userDiamonds ?? 0}.'
            : 'Necesitas al menos 100 monedas para jugar.\nTienes: ${_userCoins ?? 0}.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }
}

class _DiceDotsPainter extends CustomPainter {
  final int value;
  _DiceDotsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final r = size.width * 0.09;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final off = size.width * 0.28;

    const dotPositions = <List<List<double>>>[
      [[0, 0]],
      [[-1, -1], [1, 1]],
      [[-1, -1], [0, 0], [1, 1]],
      [[-1, -1], [1, -1], [-1, 1], [1, 1]],
      [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]],
      [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]],
    ];

    if (value >= 1 && value <= 6) {
      for (final pos in dotPositions[value - 1]) {
        canvas.drawCircle(Offset(cx + pos[0] * off, cy + pos[1] * off), r, paint);
      }
    }
  }

  @override  bool shouldRepaint(_DiceDotsPainter old) => old.value != value;
}

class _Coord {
  final int col;
  final int row;
  const _Coord(this.col, this.row);
}
