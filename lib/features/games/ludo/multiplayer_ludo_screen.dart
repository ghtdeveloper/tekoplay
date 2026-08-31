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
import '../../../core/utils/game_result.dart';
import '../../../core/utils/game_type.dart';
import '../../adds/banner_ad_widget.dart';
import 'ludo_board_painter.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/game_chat_service.dart';
import '../../../core/service/payment_service.dart';
import '../../../core/widgets/game_chat_widget.dart';
import '../../../generated/l10n.dart';
import '../../coins/diamond_purchase_dialog.dart';

enum _FriendLudoState { setup, waitingRoom, gameActive }

class MultiplayerLudoScreen extends StatefulWidget {
  final String? gameId;
  final int playerNumber;
  final String matchType;

  const MultiplayerLudoScreen({
    super.key,
    this.gameId,
    this.playerNumber = 1,
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
  bool get _isMyTurn => _currentTurn == 'player$_myPlayerNumber';

  int _dice1Value = 0;
  int _dice2Value = 0;
  bool _hasUsedDice1 = false;
  bool _hasUsedDice2 = false;
  bool _isRollingDice = false;
  int _consecutiveDoubles = 0;
  int? _lastMovedPieceId;
  final Random _random = Random();
  final Map<String, int> _botMissedFive = {};
  int _humanHomeDoubles = 0;
  final Map<String, int> _botHomeDoubles = {};
  int _botTurnCounter = 0;

  int _rollBotDie() {
    final r = _random.nextDouble();
    if (r < 0.02) return 1;
    if (r < 0.05) return 2;
    if (r < 0.10) return 3;
    if (r < 0.18) return 4;
    if (r < 0.55) return 5;
    return 6;
  }

  int _rollBotDieNoDouble({int exclude = -1}) {
    int v;
    do { v = _rollBotDie(); } while (v == exclude);
    return v;
  }


  List<Map<String, dynamic>> _movablePieces = [];
  int? _selectedPieceId;
  final List<int> _validMovePositions = [];
  bool _bonusSelectionActive = false;
  bool _localMoveInProgress = false;
  bool _bonusHadDouble = false;
  int _bonusRemainingDie = 0;
  int _bonusRemainingDieNumber = 0;
  final List<Map<String, dynamic>> _pendingBonusMoves = [];
  Set<int> _bridgeBreakPieceIds = {};

  double _boardSize = 0;
  List<String> _activePlayers = ['yellow', 'red', 'green', 'blue'];

  bool _gameEnded = false;
  bool _hasUserExited = false;
  DateTime? _gameStartTime;

  _FriendLudoState _screenState = _FriendLudoState.setup;
  int _myPlayerNumber = 1;
  String? _activeGameId;
  final GlobalKey<GameChatWidgetState> _chatKey = GlobalKey<GameChatWidgetState>();
  int _selectedPlayerCount = 2;
  int? _selectedBetAmount;
  StreamSubscription<LudoGameMatch?>? _waitingSubscription;

  static const List<int> _betOptions = [10, 25, 50, 100, 250, 500];

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

  Timer? _waitRoomTimer;
  int _waitRoomCountdown = 60;
  DateTime? _waitRoomPausedAt;
  final Set<String> _botColors = {};
  bool _botTurnScheduled = false;
  bool get _isHost => _myPlayerNumber == 1;

  String? _lastMsgSenderId;
  String? _lastMsgText;
  String? _ownMsgText;
  Timer? _msgBubbleTimer;
  Timer? _ownMsgBubbleTimer;


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
    _myPlayerNumber = widget.playerNumber;

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

    if (widget.gameId != null) {
      _activeGameId = widget.gameId;
      _screenState = _FriendLudoState.gameActive;
      _gameStartTime = DateTime.now();
      _enableWakeLock();
      _initializeGame();
    } else {
      _screenState = _FriendLudoState.setup;
      _setupBalanceListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waitingSubscription?.cancel();
    _gameSubscription?.cancel();
    _balanceSubscription?.cancel();
    _turnTimer?.cancel();
    _waitRoomTimer?.cancel();
    _msgBubbleTimer?.cancel();
    _ownMsgBubbleTimer?.cancel();
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
      if (_wakelockActive || (!_gameEnded && _screenState == _FriendLudoState.gameActive)) {
        WakelockPlus.enable().then((_) => _wakelockActive = true).catchError((_) => false);
      }
      if (_waitRoomPausedAt != null && _screenState == _FriendLudoState.waitingRoom) {
        final elapsed = DateTime.now().difference(_waitRoomPausedAt!).inSeconds;
        _waitRoomPausedAt = null;
        final remaining = (_waitRoomCountdown - elapsed).clamp(0, 60);
        if (remaining <= 0) {
          if (_isHost && (_currentGame?.status == 'waiting')) _fillBotsAndStart();
        } else {
          _startWaitRoomTimer(remaining);
        }
      } else {
        _waitRoomPausedAt = null;
      }
      if (!_gameEnded && _screenState == _FriendLudoState.gameActive) {
        final deadline = _currentGame?.turnDeadline;
        if (deadline != null) {
          _syncTimerToDeadline(deadline);
        }
      }
    } else if (state == AppLifecycleState.paused) {
      _disableWakeLock();
      if (_screenState == _FriendLudoState.waitingRoom) {
        _waitRoomPausedAt = DateTime.now();
        _waitRoomTimer?.cancel();
      }
      if (!_gameEnded) {
        _turnTimer?.cancel();
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

  void _initializeGame() {
    if (_activeGameId == null) return;
    _gameSubscription = _gameService
        .getGameStream(_activeGameId!)
        .listen(_handleGameUpdate, onError: (e) {
      if (kDebugMode) print('Ludo stream error: $e');
    });
    _setupBalanceListener();
  }

  void _startWaitingRoom(String gameId) {
    _activeGameId = gameId;
    setState(() {
      _screenState = _FriendLudoState.waitingRoom;
      _waitRoomCountdown = 60;
    });

    _waitRoomPausedAt = null;
    _startWaitRoomTimer(_waitRoomCountdown);

    _waitingSubscription = _gameService
        .getGameStream(gameId)
        .listen((game) {
      if (!mounted || game == null) return;
      setState(() => _currentGame = game);

      if (game.status == 'active' && _screenState == _FriendLudoState.waitingRoom) {
        _waitingSubscription?.cancel();
        _waitingSubscription = null;
        _setupPlayerColor(game);
        _setupActivePlayers(game);
        _gameStartTime = DateTime.now();
        _enableWakeLock();
        setState(() {
          _gameState = game.gameState;
          _currentTurn = game.currentTurn;
          _dice1Value = game.dice1;
          _dice2Value = game.dice2;
          _screenState = _FriendLudoState.gameActive;
        });
        _initializeGame();
      }
    }, onError: (e) {
      if (kDebugMode) print('Ludo waiting error: $e');
    });
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
    final turnChangedToMe = newTurn != prevTurn && newTurn == 'player$_myPlayerNumber';
    final isMyTurnNow = newTurn == 'player$_myPlayerNumber';

    final acceptRemoteState = (!isMyTurnNow && !_localMoveInProgress) || turnChangedToMe || game.isFinished || game.isAbandoned;
    setState(() {
      if (acceptRemoteState) {
        _gameState = game.gameState;
        _dice1Value = game.dice1;
        _dice2Value = game.dice2;
        _hasUsedDice1 = game.hasUsedDice1;
        _hasUsedDice2 = game.hasUsedDice2;
      }
      _currentTurn = newTurn;
    });

    if (isMyTurnNow && !_bonusSelectionActive) _calculateMovablePieces();

    final prevDeadline = prevGame?.turnDeadline;
    final newDeadline = game.turnDeadline;
    final turnChanged = prevTurn != _currentTurn;
    final deadlineChanged = newDeadline != null && newDeadline != prevDeadline;
    if ((turnChanged || deadlineChanged) && !_gameEnded) {
      if (turnChanged && _isMyTurn) _showTurnBannerAnim(S.of(context).yourTurn, _getPlayerColor(_myColor));
      if (newDeadline != null) {
        _syncTimerToDeadline(newDeadline);
      } else if (turnChanged) {
        _startTurnTimer();
      }
    }


    if (!_gameEnded && _isHost && _botColors.isNotEmpty) {
      final curColor = _colorForCurrentTurn();
      if (_botColors.contains(curColor) && !_botTurnScheduled &&
          _dice1Value == 0 && _dice2Value == 0) {
        _scheduleMultiplayerBotMove(curColor);
      }
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
    switch (_myPlayerNumber) {
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

    // Detectar slots de bot (guest IDs que comienzan con 'bot_')
    _botColors.clear();
    final slots = [
      (game.guest2Id, game.player2Color),
      (game.guest3Id, game.player3Color),
      (game.guest4Id, game.player4Color),
    ];
    for (final (id, color) in slots) {
      if ((id?.startsWith('bot_') ?? false) && color != null) {
        _botColors.add(color);
      }
    }
  }

  Future<void> _fillBotsAndStart() async {
    if (_activeGameId == null || !mounted) return;
    await _gameService.fillBotsAndStart(_activeGameId!);
  }

  void _startWaitRoomTimer(int fromSeconds) {
    _waitRoomTimer?.cancel();
    setState(() => _waitRoomCountdown = fromSeconds);
    _waitRoomTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _screenState != _FriendLudoState.waitingRoom) { t.cancel(); return; }
      setState(() => _waitRoomCountdown--);
      if (_waitRoomCountdown <= 0) {
        t.cancel();
        if (_isHost && (_currentGame?.status == 'waiting')) {
          _fillBotsAndStart();
        }
      }
    });
  }

  void _startTurnTimer([int? initialSeconds]) {
    _turnTimer?.cancel();
    final secs = initialSeconds ?? _turnTimeoutSeconds;
    setState(() => _turnTimerSeconds = secs);
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameEnded) { t.cancel(); return; }
      setState(() => _turnTimerSeconds--);
      if (_turnTimerSeconds <= 0) {
        t.cancel();
        _handleTurnTimeout();
      }
    });
  }

  void _syncTimerToDeadline(DateTime deadline) {
    _turnTimer?.cancel();
    final remaining = deadline.difference(DateTime.now()).inSeconds.clamp(0, _turnTimeoutSeconds);
    if (remaining <= 0) {
      setState(() => _turnTimerSeconds = 0);
      if (!_gameEnded) _handleTurnTimeout();
      return;
    }
    setState(() => _turnTimerSeconds = remaining);
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _gameEnded) { t.cancel(); return; }
      final rem = deadline.difference(DateTime.now()).inSeconds.clamp(0, _turnTimeoutSeconds);
      setState(() => _turnTimerSeconds = rem);
      if (rem <= 0) {
        t.cancel();
        if (!_gameEnded) _handleTurnTimeout();
      }
    });
  }

  void _handleTurnTimeout() {
    if (_gameEnded || !mounted) return;
    if (_isMyTurn) {
      _autoAction();
    } else if (_shouldHandleAbsentOpponent()) {
      final absentColor = _colorForCurrentTurn();
      if (!_botTurnScheduled) {
        _botTurnScheduled = true;
        Future.delayed(const Duration(milliseconds: 1500), () {
          _botTurnScheduled = false;
          if (!mounted || _gameEnded) return;
          if (_colorForCurrentTurn() != absentColor) return;
          _executeBotRollAndMove(absentColor);
        });
      }
    }
  }

  bool _shouldHandleAbsentOpponent() {
    if (_currentGame == null) return false;
    final absentTurn = _currentTurn;
    final absentNum = int.tryParse(absentTurn.replaceAll('player', '')) ?? 0;
    for (int n = 1; n <= 4; n++) {
      if (n == absentNum) continue;
      final pid = _currentGame!.getPlayerIdByNumber(n);
      if (pid == null) continue;
      if (_botColors.contains(_colorForPlayerNumber(n))) continue;
      return n == _myPlayerNumber;
    }
    return false;
  }

  String _colorForPlayerNumber(int num) {
    if (_currentGame == null) return '';
    switch (num) {
      case 1: return _currentGame!.player1Color;
      case 2: return _currentGame!.player2Color ?? '';
      case 3: return _currentGame!.player3Color ?? '';
      case 4: return _currentGame!.player4Color ?? '';
      default: return '';
    }
  }

  Future<void> _writeTurnDeadline() async {
    if (_activeGameId == null) return;
    try {
      await _firestore.collection('ludo_games').doc(_activeGameId!).update({
        'turnDeadline': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: _turnTimeoutSeconds)),
        ),
      });
    } catch (e) {
      if (kDebugMode) print('Error writing turnDeadline: $e');
    }
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

    final myPieces = _gameState.getPiecesByColor(_myColor);
    final allInHome = myPieces.every((p) => p.isHome);
    int d1 = 0, d2 = 0;

    do {
      setState(() { _isRollingDice = true; });
      _diceAnimController.repeat();
      await Future.delayed(const Duration(milliseconds: 600));
      _diceAnimController.stop();
      _diceAnimController.reset();

      d1 = _random.nextInt(6) + 1;
      d2 = _random.nextInt(6) + 1;

      final hasBots = _botColors.isNotEmpty;
      if (hasBots && widget.matchType == 'Apuesta') {
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
          await _advanceTurn();
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
      setState(() {
        _isRollingDice = false;
        _consecutiveDoubles = 0;
      });
      _showEventToast(S.of(context).tripleDouble);
      await _applyTripleDoublesPenalty();
      return;
    }

    _bridgeBreakPieceIds = (d1 == d2) ? _getBarreraIndices(_myColor) : {};

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
      _showEventToast(S.of(context).noValidMoves);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_gameEnded && mounted) await _advanceTurn();
    } else {
      _startTurnTimer();
      unawaited(_writeTurnDeadline());
    }
  }

  Future<void> _syncDiceToFirestore(int d1, int d2, bool u1, bool u2) async {
    try {
      await _firestore.collection('ludo_games').doc(_activeGameId!).update({
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
      _showEventToast(S.of(context).tripleDouble, color: Colors.red.shade700);
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

    final isDoubles = _dice1Value > 0 && _dice1Value == _dice2Value;

    if (isDoubles && !_hasUsedDice1 && !_hasUsedDice2) {
      final barrIndices = _getBarreraIndices(color);
      if (barrIndices.isNotEmpty) {
        final barrMoves = _movablePieces.where((m) => barrIndices.contains(m['pieceId'])).toList();
        if (barrMoves.isNotEmpty) _movablePieces = barrMoves;
      }
    }
    if (isDoubles && _hasUsedDice1 && !_hasUsedDice2 && _bridgeBreakPieceIds.isNotEmpty) {
      _movablePieces.removeWhere((m) {
        final pid = m['pieceId'] as int;
        if (!_bridgeBreakPieceIds.contains(pid)) return false;
        final piece = pieces[pid];
        final np = _calculateNewPosition(piece, _dice2Value, color);
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
              Text(S.of(ctx).whichDiceToUse,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    if ((color != _myColor && !_botColors.contains(color)) || _gameEnded) return;
    if (color == _myColor) _turnTimer?.cancel();
    _localMoveInProgress = true;

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
          ep.position = -1;
          captured = true;
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
      final remainingDie = !_hasUsedDice1 ? _dice1Value : (!_hasUsedDice2 ? _dice2Value : 0);
      final remainingNum = !_hasUsedDice1 ? 1 : (!_hasUsedDice2 ? 2 : 0);
      _bonusRemainingDie = hadDouble ? 0 : remainingDie;
      _bonusRemainingDieNumber = hadDouble ? 0 : remainingNum;
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

    _bonusHadDouble = hadDouble;

    if (_botColors.contains(color)) {
      final best = _pendingBonusMoves.reduce((a, b) {
        final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition(color));
        final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition(color));
        return stA >= stB ? a : b;
      });
      _showEventToast('¡Bot capturó! +20 casillas', color: Colors.green);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted || _gameEnded) return;
        _pendingBonusMoves.clear();
        final pieces = _gameState.getPiecesByColor(color);
        final pid = best['pieceId'] as int;
        if (pid < pieces.length) {
          pieces[pid].position = best['bonusPos'] as int;
          if (best['bonusPos'] == 57) pieces[pid].isFinished = true;
        }
        setState(() {});
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
          _syncGameState(advanceTurn: false);
          _scheduleMultiplayerBotMove(color);
          return;
        }
        if (hadDouble) {
          _syncGameState(advanceTurn: false);
          _scheduleMultiplayerBotMove(color);
        } else {
          _syncGameState(advanceTurn: true);
        }
      });
      return;
    }

    _bonusSelectionActive = true;
    _showEventToast('¡Capturaste! Elige una ficha para el bonus +20', color: Colors.green);

    _movablePieces = _pendingBonusMoves.map((m) => {
      ...m, 'diceValue': 20, 'diceNumber': 0,
    }).toList();
    setState(() {});
    _startTurnTimer();
  }

  void _executeBonusMove(int pieceId, int bonusPos) {
    _bonusSelectionActive = false;
    _localMoveInProgress = true;
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
      setState(() {});
      _calculateMovablePieces();
      if (_movablePieces.isNotEmpty) {
        _syncGameState(advanceTurn: false);
        _startTurnTimer();
        return;
      }
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
    if (!mounted) { _localMoveInProgress = false; return; }
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
        updates['turnDeadline'] = Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: _turnTimeoutSeconds)),
        );
      }

      await _firestore.collection('ludo_games').doc(_activeGameId!).update(updates);
    } catch (e) {
      if (kDebugMode) print('Error syncing game state: $e');
    }
    _localMoveInProgress = false;
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


  void _scheduleMultiplayerBotMove(String botColor) {
    if (_botTurnScheduled || _gameEnded || !mounted) return;
    _botTurnScheduled = true;
    final delay = 3200 + _random.nextInt(800);
    Future.delayed(Duration(milliseconds: delay), () {
      _botTurnScheduled = false;
      if (!mounted || _gameEnded) return;
      if (_colorForCurrentTurn() != botColor) return;
      _executeBotRollAndMove(botColor);
    });
  }

  Future<void> _executeBotRollAndMove(String botColor) async {
    if (_gameEnded || !mounted) return;
    if (_colorForCurrentTurn() != botColor) return;

    final botPieces = _gameState.getPiecesByColor(botColor);
    final allInHome = botPieces.every((p) => p.isHome);
    int d1 = 0, d2 = 0;

    final isBetMode = widget.matchType == 'Apuesta';
    do {
      _botTurnCounter++;
      final isWeakTurn = isBetMode && (_botTurnCounter % 3 == 0);

      if (isWeakTurn) {
        d1 = _random.nextInt(2) + 1; // 1 or 2
        d2 = _random.nextInt(2) + 1; // 1 or 2
      } else {
        d1 = (_consecutiveDoubles >= 2) ? _rollBotDieNoDouble() : _rollBotDie();
        d2 = (_consecutiveDoubles >= 2) ? _rollBotDieNoDouble(exclude: d1) : _rollBotDie();

        final hasHomePieces = botPieces.any((p) => p.isHome);
        final missedCount = _botMissedFive[botColor] ?? 0;
        if (missedCount >= 3 && hasHomePieces && d1 != 5 && d2 != 5) {
          if (_random.nextBool()) { d1 = 5; } else { d2 = 5; }
        }
        _botMissedFive[botColor] = (hasHomePieces && d1 != 5 && d2 != 5) ? missedCount + 1 : 0;

        final piecesInStretch = botPieces
            .where((p) => p.position >= 52 && !p.isFinished)
            .toList();
        if (piecesInStretch.isNotEmpty && _random.nextDouble() < 0.80) {
          final usefulValues = <int>{};
          for (final p in piecesInStretch) {
            final rem = 57 - p.position;
            if (rem >= 1 && rem <= 6) usefulValues.add(rem);
          }
          if (usefulValues.isNotEmpty) {
            final list = usefulValues.toList()..sort();
            d1 = list[_random.nextInt(list.length)];
            int d2c = list.length > 1
                ? list[_random.nextInt(list.length)]
                : (_random.nextInt(3) + 1); // 1-3 fallback
            if (_consecutiveDoubles >= 2 && d2c == d1) {
              d2c = d1 == 1 ? 2 : d1 - 1;
            }
            d2 = d2c;
          }
        }
      }

      if (allInHome && d1 == d2 && d1 != 5) {
        _botHomeDoubles[botColor] = (_botHomeDoubles[botColor] ?? 0) + 1;
        setState(() { _dice1Value = d1; _dice2Value = d2; });
        await _syncDiceToFirestore(d1, d2, false, false);
        if ((_botHomeDoubles[botColor] ?? 0) >= 3) {
          _botHomeDoubles[botColor] = 0;
          _consecutiveDoubles = 0;
          _showEventToast('Bot: tres dobles en casa, pierde turno');
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() { _dice1Value = 0; _dice2Value = 0; });
          await _advanceTurn();
          return;
        }
        _showEventToast('Bot: doble en casa, vuelve a tirar');
        await Future.delayed(const Duration(milliseconds: 1200));
        setState(() { _dice1Value = 0; _dice2Value = 0; });
        continue;
      }
      _botHomeDoubles[botColor] = 0;
      break;
    } while (true);

    final hadDouble = d1 == d2;
    if (hadDouble) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    setState(() {
      _dice1Value = d1; _dice2Value = d2;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
    });
    await _syncDiceToFirestore(d1, d2, false, false);
    await Future.delayed(Duration(milliseconds: 4200 + _random.nextInt(800)));
    if (!mounted || _gameEnded) return;

    await _doBotMoves(botColor, hadDouble);
  }

  int _scoreBotAction(LudoPiece piece, int np, String botColor) {
    int s = 0;
    if (np < 52 && !_isSafeForColor(np, botColor)) {
      for (final ec in _activePlayers) {
        if (ec == botColor) continue;
        final enemies = _gameState.getPiecesByColor(ec)
            .where((ep) => !ep.isHome && !ep.isFinished && ep.position == np).toList();
        if (enemies.length == 1) {
          s += 10000 + _stepsFromStart(enemies.first.position, _getStartPosition(ec)) * 20;
        }
      }
    }
    if (np == 57) {
      s += 900;
    } else if (np >= 52 && piece.position < 52){
      s += 450;
    }
    else if (np >= 52) {
      s += np * 20;
    }
    if (piece.isHome) s += 600;
    if (!piece.isHome && piece.position < 52) {
      s += _stepsFromStart(piece.position, _getStartPosition(botColor)) * 6;
    }
    if (np < 52 && _isSafeForColor(np, botColor)) s += 80;
    if (np < 52) {
      final allies = _gameState.getPiecesByColor(botColor)
          .where((bp) => !bp.isFinished && !bp.isHome && bp.id != piece.id && bp.position == np)
          .length;
      if (allies == 1) s += 200;
    }
    return s;
  }

  Map<String, dynamic> _pickBestBotMove(String botColor) {
    int bestScore = -1;
    Map<String, dynamic>? best;
    for (final move in _movablePieces) {
      final piece = move['piece'] as LudoPiece;
      final dv = move['diceValue'] as int;
      final np = _calculateNewPosition(piece, dv, botColor);
      if (np == null) continue;
      int score = _scoreBotAction(piece, np, botColor);
      if (np < 52 && !_isSafeForColor(np, botColor) && !piece.isHome) {
        int threats = 0;
        for (final ec in _activePlayers) {
          if (ec == botColor) continue;
          for (final ep in _gameState.getPiecesByColor(ec)) {
            if (ep.isHome || ep.isFinished) continue;
            for (int d = 1; d <= 6; d++) {
              if (_calculateNewPosition(ep, d, ec) == np) { threats++; break; }
            }
          }
        }
        if (threats > 0) score -= 350 * threats;
      }
      if (score > bestScore) { bestScore = score; best = move; }
    }
    return best ?? _movablePieces.first;
  }

  Future<void> _doBotMoves(String botColor, bool hadDouble) async {
    if (!mounted || _gameEnded) return;
    _localMoveInProgress = true;

    _calculateMovablePieces(botColor);

    if (_movablePieces.isEmpty) {
      setState(() { _dice1Value = 0; _dice2Value = 0; _hasUsedDice1 = false; _hasUsedDice2 = false; });
      await _syncGameState(advanceTurn: !hadDouble);
      if (hadDouble) _scheduleMultiplayerBotMove(botColor);
      return;
    }

    final move = _pickBestBotMove(botColor);
    final pid = move['pieceId'] as int;
    final dv  = move['diceValue'] as int;
    final dn  = move['diceNumber'] as int;

    final pieces = _gameState.getPiecesByColor(botColor);
    if (pid >= pieces.length) { await _syncGameState(advanceTurn: true); return; }

    final piece  = pieces[pid];
    final newPos = _calculateNewPosition(piece, dv, botColor);
    if (newPos == null) { await _syncGameState(advanceTurn: true); return; }

    // Mover pieza
    final wasHome = piece.isHome;
    piece.position = newPos;
    if (newPos == 57) piece.isFinished = true;
    if (dn == 1) {
      _hasUsedDice1 = true;
    } else {
      _hasUsedDice2 = true;
    }

    bool captured = false;
    final isExitingHome = newPos < 52 && wasHome && newPos == _getStartPosition(botColor);
    if (isExitingHome) {
      for (final ec in _activePlayers) {
        if (ec == botColor) continue;
        final enemyHere = _gameState.getPiecesByColor(ec)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPos).toList();
        for (final ep in enemyHere) { ep.position = -1; captured = true; }
      }
    } else if (newPos < 52 && !_isSafeForColor(newPos, botColor)) {
      for (final ec in _activePlayers) {
        if (ec == botColor) continue;
        final enemyHere = _gameState.getPiecesByColor(ec)
            .where((p) => !p.isHome && !p.isFinished && p.position == newPos).toList();
        for (final ep in enemyHere) { ep.position = -1; captured = true; }
      }
    }
    setState(() {});

    if (_checkVictory(botColor)) {
      await _syncGameState(advanceTurn: false);
      _endGame(botColor);
      return;
    }

    if (captured) {
      _pendingBonusMoves.clear();
      for (int i = 0; i < pieces.length; i++) {
        final p = pieces[i];
        final bp = _calculateCaptureBonusPosition(p, botColor);
        if (bp != null) _pendingBonusMoves.add({'pieceId': i, 'piece': p, 'bonusPos': bp});
      }
      if (_pendingBonusMoves.isNotEmpty) {
        final best = _pendingBonusMoves.reduce((a, b) {
          final stA = _stepsFromStart((a['piece'] as LudoPiece).position, _getStartPosition(botColor));
          final stB = _stepsFromStart((b['piece'] as LudoPiece).position, _getStartPosition(botColor));
          return stA >= stB ? a : b;
        });
        await Future.delayed(const Duration(milliseconds: 2900));
        if (!mounted || _gameEnded) return;
        final bpid = best['pieceId'] as int;
        final bpos = best['bonusPos'] as int;
        if (bpid < pieces.length) {
          pieces[bpid].position = bpos;
          if (bpos == 57) pieces[bpid].isFinished = true;
        }
        _pendingBonusMoves.clear();
        setState(() {});
      }
      setState(() { _dice1Value = 0; _dice2Value = 0; _hasUsedDice1 = false; _hasUsedDice2 = false; });
      await _syncGameState(advanceTurn: !hadDouble);
      if (hadDouble) _scheduleMultiplayerBotMove(botColor);
      return;
    }

    _calculateMovablePieces(botColor);
    if (_movablePieces.isNotEmpty) {
      await _syncGameState(advanceTurn: false);
      await Future.delayed(const Duration(milliseconds: 2600));
      if (!mounted || _gameEnded) return;
      await _doBotMoves(botColor, hadDouble);
      return;
    }

    setState(() { _dice1Value = 0; _dice2Value = 0; _hasUsedDice1 = false; _hasUsedDice2 = false; });
    await _syncGameState(advanceTurn: !hadDouble);
    if (hadDouble) _scheduleMultiplayerBotMove(botColor);
  }

  void _endGame(String winnerColor) {
    if (_gameEnded) return;
    setState(() => _gameEnded = true);
    _turnTimer?.cancel();

    final isWin = winnerColor == _myColor;
    if (isWin && _currentUser != null && _activeGameId != null) {
      _gameService.finishGame(gameId: _activeGameId!, winnerId: _currentUser!.uid);
    }
    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    _showEndDialog(isWin ? S.of(context).victory : '${_getColorName(winnerColor)} ganó', _currentGame, forceIsWin: isWin);
  }

  void _handleGameEnd(LudoGameMatch game) {
    final isWin = game.winnerId == _currentUser?.uid;
    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    _showEndDialog(isWin ? S.of(context).victory : S.of(context).endOfGame, game, forceIsWin: isWin);
  }

  void _handleAbandon(LudoGameMatch game) {
    final abandonedBy = game.abandonedBy;
    if (abandonedBy != null && abandonedBy != _currentUser?.uid) {
      _showCancelledByOtherDialog(game);
    } else {
      if (!_hasUserExited) {
        _recordResult(GameResultModel.loss);
      }
      _showEndDialog('Partida abandonada.', game, forceIsWin: false);
    }
  }

  void _showCancelledByOtherDialog(LudoGameMatch game) {
    if (!mounted) return;
    final betAmount = game.betAmount;
    final isBetGame = betAmount != null && betAmount > 0;
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
            border: Border.all(color: Colors.grey.shade400, width: 2),
            boxShadow: [BoxShadow(
              color: Colors.grey.withValues(alpha: 0.25),
              blurRadius: 24, spreadRadius: 4,
            )],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❌', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                'PARTIDA CANCELADA',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Un jugador abandonó la partida.',
                style: TextStyle(color: Colors.black87, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (isBetGame) ...[
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
                      const Icon(Icons.diamond, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tu apuesta de $betAmount 💎 será devuelta',
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(S.of(ctx).exit, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reloadUserCurrency() async {
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

  void _showEndDialog(String message, LudoGameMatch? game, {bool? forceIsWin}) {
    if (!mounted) return;
    final isWin = forceIsWin ?? (game?.winnerId == _currentUser?.uid);
    final betAmount = game?.betAmount;
    final isBetGame = betAmount != null && betAmount > 0 && game?.currencyType == 'diamonds';
    final int realPlayerCount = _activePlayers
        .where((c) => !_botColors.contains(c))
        .length
        .clamp(1, 4);
    final winnerPrize = !isBetGame
        ? 0
        : (betAmount * realPlayerCount * 0.90).floor();
    final netGain = isBetGame ? winnerPrize - betAmount : 0;

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
                isWin ? S.of(ctx).victory : S.of(ctx).endOfGame,
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
                            ? '+$netGain 💎 ganados'
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
                  child: Text(S.of(ctx).exit, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            title: Text(S.of(ctx).abandonGame,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  S.of(ctx).abandonWarningFun,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(S.of(ctx).cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(S.of(ctx).abandonGame,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
      gameId: _activeGameId!,
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

  String _getCountIcon(int n) {
    switch (n) {
      case 2: return '👥';
      case 3: return '👨‍👩‍👦';
      default: return '👨‍👩‍👧‍👦';
    }
  }

  Widget _buildSetupScaffold() {
    final isBet = widget.matchType == 'Apuesta';
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(S.of(context).parchisVsFriend, style: const TextStyle(color: Colors.white)),
        elevation: 2,
        actions: [
          if (widget.matchType == 'Apuesta')
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC7A34), Color(0xFFd4622a)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🎲', style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.of(context).parchisVsFriend,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(S.of(context).inviteFriend,
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

            if (isBet) ...[
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
                  spacing: 8, runSpacing: 8,
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
                                color: isSelected ? Colors.white : (canAfford ? Colors.amber.shade600 : Colors.grey.shade400),
                                size: 14),
                            const SizedBox(width: 4),
                            Text(
                              amount.toString(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : (canAfford ? Colors.black87 : Colors.grey.shade500),
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
                  Icon(isBet ? Icons.diamond : Icons.monetization_on,
                      color: isBet ? Colors.blue : Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tu balance: ${isBet ? '${_userDiamonds ?? 0} diamantes' : '${_userCoins ?? 0} monedas'}',
                    style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isBet && _selectedBetAmount == null)
                    ? null
                    : () => _showFriendInviteDialog(),
                icon: const Icon(Icons.person_add, size: 22),
                label: Text(S.of(context).inviteFriend,
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
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingRoomScaffold() {
    final game = _currentGame;
    final joined = game?.playerCount ?? 1;
    final remaining = _selectedPlayerCount - joined;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7A34),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(S.of(context).waitingRoom, style: const TextStyle(color: Colors.white)),
        elevation: 2,
      ),
      body: Center(
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
                        value: _selectedPlayerCount > 0 ? joined / _selectedPlayerCount : 0,
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFFEC7A34), minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (remaining > 0) ...[
                      const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFEC7A34))),
                      const SizedBox(height: 6),
                      Text('Esperando $remaining ${remaining == 1 ? 'jugador más' : 'jugadores más'}...',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        'Iniciando en $_waitRoomCountdown"',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _waitRoomCountdown <= 10 ? FontWeight.bold : FontWeight.normal,
                          color: _waitRoomCountdown <= 10 ? Colors.orange.shade700 : Colors.grey,
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
                const SizedBox(height: 12),
                Text(
                  'Código: ${_activeGameId!.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black45),
                ),
              ],
              const SizedBox(height: 16),
              if (remaining > 0)
                ElevatedButton.icon(
                  onPressed: () => _showFriendInviteDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: Text(S.of(context).inviteAnotherFriend),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  if (_activeGameId != null) {
                    _firestore.collection('ludo_games').doc(_activeGameId).update({
                      'status': 'cancelled',
                      'finishedAt': FieldValue.serverTimestamp(),
                    }).catchError((_) {});
                  }
                  _waitingSubscription?.cancel();
                  if (mounted) Navigator.of(context).pop();
                },
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
      ),
    );
  }

  void _showFriendInviteDialog() {
    if (_currentUser == null) return;

    final isBet = widget.matchType == 'Apuesta';
    final balance = isBet ? (_userDiamonds ?? 0) : (_userCoins ?? 0);
    final emailController = TextEditingController();
    final betController = TextEditingController();
    bool isLoading = false;
    String? betError;

    if (isBet && _selectedBetAmount != null) {
      betController.text = '$_selectedBetAmount';
    }

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
                          Icon(isBet ? Icons.diamond : Icons.monetization_on,
                              color: isBet ? Colors.blue : Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Tu saldo: $balance ${isBet ? 'diamantes' : 'monedas'}',
                            style: TextStyle(color: Colors.green.shade800,
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          labelText: S.of(ctx).betAmountDiamonds,
                          prefixIcon: const Icon(Icons.diamond, color: Colors.amber),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            backgroundColor: ok ? Colors.amber.withValues(alpha: 0.15) : Colors.grey.shade200,
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
                                await _createAndInvite(
                                  email: emailController.text.trim(),
                                  betAmount: isBet ? int.tryParse(betController.text.trim()) : null,
                                );
                              },
                        icon: isLoading
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: Text(isLoading ? S.of(ctx).sending : S.of(ctx).sendInvitation,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEC7A34), foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _createAndInvite({required String email, int? betAmount}) async {
    if (_currentUser == null || !mounted) return;

    final isBet = widget.matchType == 'Apuesta';
    final currencyType = isBet ? 'diamonds' : 'coins';
    final effectiveBet = betAmount ?? _selectedBetAmount;

    final bool isNewGame = _activeGameId == null;
    String? gameId = _activeGameId;

    if (isNewGame) {
      gameId = await _gameService.createGame(
        hostId: _currentUser!.uid,
        hostName: _currentUser!.displayName ?? 'Jugador',
        hostPhotoUrl: _currentUser!.photoURL,
        currencyType: currencyType,
        betAmount: effectiveBet,
        numberOfPlayers: _selectedPlayerCount,
        isOnlineMatchmaking: false,
      );
    }

    if (gameId == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.of(context).errorCreatingRoom),
            backgroundColor: Colors.red));
      }
      return;
    }

    final error = await GameInvitationService().createInvitation(
      fromUserId: _currentUser!.uid,
      fromUserName: _currentUser!.displayName ?? 'Jugador',
      toUserEmail: email,
      gameType: 'Parchís',
      betAmount: effectiveBet,
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
      if (isBet && betAmount != null) setState(() => _selectedBetAmount = betAmount);
      _startWaitingRoom(gameId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.of(context).invitationSentWaiting),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_screenState == _FriendLudoState.setup) return _buildSetupScaffold();
    if (_screenState == _FriendLudoState.waitingRoom) return _buildWaitingRoomScaffold();

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
          title: Text(S.of(context).parchisVsFriend,
              style: const TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: () => _chatKey.currentState?.toggleChat(),
              tooltip: 'Chat',
            ),
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
            Stack(
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
      colorNames[color] = (n == _myPlayerNumber) ? 'Yo' : (name ?? 'J$n').split(' ').first;
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
      final isMe = name == 'Yo';
      final showTimer = isActive && _turnTimerSeconds > 0;
      final timerLow = _turnTimerSeconds <= 10;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: (isMe || isActive) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (showTimer) ...[
                const SizedBox(width: 4),
                Text(
                  '$_turnTimerSeconds"',
                  style: TextStyle(
                    color: timerLow ? Colors.orange.shade200 : Colors.white,
                    fontSize: 11, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
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

  String? _colorForPlayerId(String playerId) {
    if (_currentGame == null) return null;
    if (playerId == _currentGame!.hostId) return _currentGame!.player1Color;
    if (playerId == _currentGame!.guest2Id) return _currentGame!.player2Color;
    if (playerId == _currentGame!.guest3Id) return _currentGame!.player3Color;
    if (playerId == _currentGame!.guest4Id) return _currentGame!.player4Color;
    return null;
  }

  Widget _buildBoardChatBubbles(double sz) {
    const pad = 28.0;
    final myColor = _myColor;

    List<Widget> bubbles = [];

    if (_ownMsgText != null) {
      final pos = _bubblePositionForColor(myColor, sz, pad);
      if (pos != null) {
        bubbles.add(Positioned(
          top: pos.top, bottom: pos.bottom, left: pos.left, right: pos.right,
          child: _buildLudoChatBubble(_ownMsgText!, isMe: true),
        ));
      }
    }

    if (_lastMsgText != null && _lastMsgSenderId != null) {
      final senderColor = _colorForPlayerId(_lastMsgSenderId!);
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

  ({double? top, double? bottom, double? left, double? right}) ? _bubblePositionForColor(String color, double sz, double pad) {
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
          if (!_gameEnded && _turnTimerSeconds > 0)
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
      label: Text(S.of(context).rollDice, style: const TextStyle(fontWeight: FontWeight.bold)),
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
