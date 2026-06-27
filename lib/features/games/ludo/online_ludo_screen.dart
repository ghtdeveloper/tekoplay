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

  static const List<Map<String, String>> _botProfiles = [
    {'name': 'Carlos_MX99',   'emoji': '😎'},
    {'name': 'luisR_2024',    'emoji': '🎮'},
    {'name': 'PepitaFlores',  'emoji': '👑'},
    {'name': 'Andreita_07',   'emoji': '🔥'},
    {'name': 'j_Coronado',    'emoji': '🏆'},
    {'name': 'marcoG_55',     'emoji': '⚡'},
    {'name': 'SofiaV_play',   'emoji': '🌟'},
    {'name': 'reydelParchis', 'emoji': '🎲'},
  ];

  String _opponentName   = '';
  String _opponentEmoji  = '🎮';

  LudoGameState _gameState = LudoGameState.initial();
  String _myColor   = 'yellow';
  String _botColor  = 'red';
  List<String> _activePlayers = ['yellow', 'red'];
  String _currentPlayer = 'yellow';
  bool get _isMyTurn => _currentPlayer == _myColor;

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
  final List<Map<String, dynamic>> _pendingBonusMoves = [];

  bool _gameEnded = false;
  double _boardSize = 0;
  DateTime? _gameStartTime;
  bool _isScreenKeepOnActive = false;
  bool _isBotThinking = false;
  bool _botExecuting = false;
  Timer? _botSafetyTimer;

  Timer? _turnTimer;
  int _turnTimerSeconds = 0;
  static const int _turnTimeoutSeconds = 30;

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
    if (state == AppLifecycleState.resumed && _isScreenKeepOnActive) _enableWakeLock();
    if (state == AppLifecycleState.paused) _disableWakeLock();
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
        if (mounted) setState(() => _isScreenKeepOnActive = true);
      }
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
        if (mounted) setState(() => _isScreenKeepOnActive = false);
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
    final isBet = widget.matchType == 'Apuesta';
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

    _matchmakingTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _matchmakingSeconds += 2);

      if (_screenState == _LudoOnlineState.gameActive || _navigated) {
        t.cancel();
        return;
      }

      const int maxWait = 30;
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
          (_screenState == _LudoOnlineState.matchmaking ||
           _screenState == _LudoOnlineState.waitingRoom)) {
        _tryJoinExistingGame();
      }
    });

    await _findOrCreateGame();
  }

  Future<void> _tryJoinExistingGame() async {
    if (_isPlayingAgainstBot || _navigated || _isJoiningGame) return;
    final isSearching = _screenState == _LudoOnlineState.matchmaking ||
        _screenState == _LudoOnlineState.waitingRoom;
    if (!isSearching) return;

    _isJoiningGame = true;
    try {
      final ct = widget.matchType == 'Apuesta' ? 'diamonds' : 'coins';
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
      final ct = widget.matchType == 'Apuesta' ? 'diamonds' : 'coins';
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
        currencyType: widget.matchType == 'Apuesta' ? 'diamonds' : 'coins',
        betAmount: widget.matchType == 'Apuesta' ? _selectedBetAmount : null,
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
      _matchmakingTimer?.cancel();
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

    if (_selectedPlayerCount == 2) {
      _startBotGame();
      return;
    }

    _cancelMatchmaking();
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

  void _startBotGame() {
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

    final isBet = widget.matchType == 'Apuesta';
    final cost = isBet ? (_selectedBetAmount ?? 25) : 100;
    if (_currentUser != null) {
      if (isBet) {
        _firestoreService.incrementUserDiamonds(_currentUser!.uid, -cost);
      } else {
        _firestoreService.incrementUserCoins(_currentUser!.uid, -cost);
      }
    }

    final profile = _botProfiles[_random.nextInt(_botProfiles.length)];

    _myColor   = 'yellow';
    _botColor  = 'red';
    _activePlayers = ['yellow', 'red'];
    _currentPlayer = 'yellow';

    setState(() {
      _isPlayingAgainstBot = true;
      _opponentName  = profile['name']!;
      _opponentEmoji = profile['emoji']!;
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
    _showTurnBannerAnim('¡TU TURNO!', _getPlayerColor(_myColor));
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

  void _startTurnTimer() {
    _turnTimer?.cancel();
    setState(() => _turnTimerSeconds = _turnTimeoutSeconds);
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

    setState(() => _isRollingDice = true);
    _diceAnimController.repeat();
    await Future.delayed(const Duration(milliseconds: 600));
    _diceAnimController.stop();
    _diceAnimController.reset();

    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;

    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    if (_consecutiveDoubles >= 3) {
      setState(() { _isRollingDice = false; _consecutiveDoubles = 0; });
      _showEventToast('¡Tres dobles! Turno perdido.');
      _applyTripleDoublesPenalty(_myColor);
      await Future.delayed(const Duration(milliseconds: 1500));
      _nextTurn();
      return;
    }

    setState(() {
      _dice1Value = d1; _dice2Value = d2;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
      _isRollingDice = false;
    });

    _calculateMovablePieces();
    if (_movablePieces.isEmpty) {
      _showEventToast('Sin movimientos válidos. Turno perdido.');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_gameEnded && mounted) _nextTurn();
    } else {
      _startTurnTimer();
    }
  }

  void _handleBoardTap(Offset local) {
    if (!_isMyTurn || _gameEnded || _boardSize == 0) return;
    if (_dice1Value == 0 && _dice2Value == 0) return;

    final sq = _boardSize / 15;
    final tapR = sq * 0.7;
    final pieces = _gameState.getPiecesByColor(_myColor);

    if (_bonusSelectionActive) {
      for (int i = 0; i < pieces.length; i++) {
        final bm = _pendingBonusMoves.firstWhere(
            (m) => m['pieceId'] == i, orElse: () => {});
        if (bm.isEmpty) continue;
        final pos = _getPieceScreenPos(pieces[i], _myColor, sq);
        if (pos != null && (local - pos).distance < tapR) {
          _executeBonusMove(_myColor, i, bm['bonusPos'] as int, _bonusHadDouble);
          return;
        }
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
              const Text('¿Qué dado usar?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    if (newPos < 52 && !_isSafeForColor(newPos, color)) {
      for (final ec in _activePlayers) {
        if (ec == color) continue;
        for (final ep in _gameState.getPiecesByColor(ec)) {
          if (!ep.isHome && !ep.isFinished && ep.position == newPos) {
            ep.position = -1; captured = true;
          }
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
      Future.delayed(const Duration(milliseconds: 400), () => _endGame(color));
      return;
    }

    final hadDouble = _dice1Value == _dice2Value && _dice1Value > 0;

    if (captured) {
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
        Future.delayed(Duration(milliseconds: 400 + _random.nextInt(400)), _executeBotBestMove);
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
      if (bp < 52 && _isEnemyBarrierAt(bp, color)) continue;
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
      // Si solo hay una ficha elegible, ejecutar bonus automáticamente sin esperar toque
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
      Future.delayed(const Duration(milliseconds: 300), () => _endGame(color));
      return;
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
    _nextTurn();
  }

  void _nextTurn() {
    if (_gameEnded || !mounted) return;
    final idx = _activePlayers.indexOf(_currentPlayer);
    final next = _activePlayers[(idx + 1) % _activePlayers.length];
    setState(() => _currentPlayer = next);

    if (next == _myColor) {
      _showTurnBannerAnim('¡TU TURNO!', _getPlayerColor(_myColor));
      _startTurnTimer();
    } else {
      _showTurnBannerAnim('Turno de $_opponentName', _getPlayerColor(_botColor));
      Future.delayed(const Duration(milliseconds: 800), _scheduleBotMove);
    }
  }

  void _applyTripleDoublesPenalty(String color) {
    final pieces = _gameState.getPiecesByColor(color);
    final active = pieces.where((p) => !p.isHome && !p.isFinished).toList();
    if (active.isEmpty) return;

    // Enviar a casa la última ficha movida; si ya no está activa, la más avanzada
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
      _showEventToast('¡Triple doble! Ficha enviada a casa 😱', color: Colors.red.shade700);
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
    
    if (_dice1Value > 0 && _dice1Value == _dice2Value && !_hasUsedDice1 && !_hasUsedDice2) {
      final barrIndices = _getBarreraIndices(_currentPlayer);
      if (barrIndices.isNotEmpty) {
        final barrMoves = _movablePieces.where((m) => barrIndices.contains(m['pieceId'])).toList();
        if (barrMoves.isNotEmpty) _movablePieces = barrMoves;
      }
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
    if (_gameEnded || !_isPlayingAgainstBot || _currentPlayer != _botColor) return;
    if (_botExecuting) return;
    _botExecuting = true;
    setState(() => _isBotThinking = true);
    _botSafetyTimer?.cancel();
    _botSafetyTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _gameEnded) return;
      _botExecuting = false;
      _dice1Value = 0;
      _dice2Value = 0;
      _hasUsedDice1 = false;
      _hasUsedDice2 = false;
      _movablePieces.clear();
      setState(() => _isBotThinking = false);
      if (_currentPlayer == _botColor) _nextTurn();
    });
    final thinkTime = 600 + _random.nextInt(800);
    Future.delayed(Duration(milliseconds: thinkTime), () {
      if (mounted) setState(() => _isBotThinking = false);
      _executeBotTurn();
    });
  }

  Future<void> _executeBotTurn() async {
    if (_gameEnded || !mounted || _currentPlayer != _botColor) { _clearBotExecution(); return; }

    final d1 = _random.nextInt(6) + 1;
    final d2 = _random.nextInt(6) + 1;

    if (d1 == d2) {
      _consecutiveDoubles++;
    } else {
      _consecutiveDoubles = 0;
    }

    if (_consecutiveDoubles >= 3) {
      _consecutiveDoubles = 0;
      _applyTripleDoublesPenalty(_botColor);
      setState(() {});
      _showEventToast('$_opponentName perdió el turno (3 dobles)');
      await Future.delayed(const Duration(milliseconds: 1500));
      _clearBotExecution();
      _nextTurn();
      return;
    }

    setState(() {
      _dice1Value = d1; _dice2Value = d2;
      _hasUsedDice1 = false; _hasUsedDice2 = false;
    });

    await Future.delayed(Duration(milliseconds: 400 + _random.nextInt(400)));

    _calculateMovablePieces();

    if (_movablePieces.isEmpty) {
      _showEventToast('$_opponentName no tiene movimientos');
      await Future.delayed(const Duration(milliseconds: 1200));
      setState(() { _dice1Value = 0; _dice2Value = 0; });
      _clearBotExecution();
      _nextTurn();
      return;
    }

    await _executeBotBestMove();
  }

  Future<void> _executeBotBestMove() async {
    if (_gameEnded || _currentPlayer != _botColor) { _clearBotExecution(); return; }
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

    int bestScore = -1;
    Map<String, dynamic>? bestMove;

    for (final move in _movablePieces) {
      final piece = move['piece'] as LudoPiece;
      final dv = move['diceValue'] as int;
      final np = _calculateNewPosition(piece, dv, _botColor);
      if (np == null) continue;

      int score = 0;

      if (np < 52 && !_isSafeForColor(np, _botColor)) {
        for (final ec in _activePlayers) {
          if (ec == _botColor) continue;
          final count = _gameState.getPiecesByColor(ec)
              .where((p) => !p.isHome && !p.isFinished && p.position == np).length;
          if (count > 0 && count < 2) score += 1000;
        }
      }
      if (np == 57) score += 800;
      if (np >= 52 && piece.position < 52) score += 300;
      if (piece.isHome) score += 200;
      if (!piece.isHome && piece.position < 52) {
        score += _stepsFromStart(piece.position, _getStartPosition(_botColor)) * 5;
      }
      if (np < 52 && _isSafeForColor(np, _botColor)) score += 50;

      if (score > bestScore) { bestScore = score; bestMove = move; }
    }
    bestMove ??= _movablePieces.first;
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(300)));

    if (mounted && !_gameEnded) {
      _executePieceMove(
        _botColor,
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
      if (_isEnemyBarrierAt((sp + ns) % 52, color)) return true;
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
    if (_isEnemyBarrierAt(newPos, color)) return false;
    for (final oc in _activePlayers) {
      if (oc == color) continue;
      final ownerStart = _getStartPosition(oc);
      if (newPos == ownerStart) {
        final ownerCount = _gameState.getPiecesByColor(oc)
            .where((p) => !p.isHome && !p.isFinished && p.position == ownerStart).length;
        if (ownerCount > 0) return false;
      }
    }
    return true;
  }

  int? _calculateCaptureBonusPosition(LudoPiece piece, String color) {
    if (piece.isFinished || piece.isHome) return null;
    if (piece.position >= 52) {
      final np = piece.position + 20;
      return np > 57 ? 57 : np;
    }
    final sp = _getStartPosition(color);
    final steps = _stepsFromStart(piece.position, sp) + 20;
    if (steps >= 51) {
      final into = steps - 51;
      return into > 5 ? 57 : 52 + into;
    }
    return (sp + steps) % 52;
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
    return const {4, 8, 17, 21, 30, 34, 43, 47}.contains(pos);
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
    final isWin = winnerColor == _myColor;

    if (isWin && _currentUser != null) {
      final isBet = widget.matchType == 'Apuesta';
      final betAmount = isBet ? 25 : 100;
      final prize = betAmount + (betAmount * 0.7).ceil();
      if (isBet) {
        _firestoreService.incrementUserDiamonds(_currentUser!.uid, prize);
        if (mounted) setState(() => _userDiamonds = (_userDiamonds ?? 0) + prize);
      } else {
        _firestoreService.incrementUserCoins(_currentUser!.uid, prize);
        if (mounted) setState(() => _userCoins = (_userCoins ?? 0) + prize);
      }
    }

    _recordResult(isWin ? GameResultModel.win : GameResultModel.loss);
    _showGameEndDialog(isWin ? '¡GANASTE! 🏆' : '$_opponentEmoji $_opponentName ganó');
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

  void _showGameEndDialog(String message) {
    if (!mounted) return;
    final isWin = message.contains('GANASTE');
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
                isWin ? '¡VICTORIA!' : 'FIN DEL JUEGO',
                style: TextStyle(
                  color: isWin ? Colors.amber.shade700 : const Color(0xFFEC7A34),
                  fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(message,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                  textAlign: TextAlign.center),
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
                      child: const Text('Salir'),
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
                      child: const Text('Jugar de nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final isBet = widget.matchType == 'Apuesta';
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
    });
    _showTurnBannerAnim('¡TU TURNO!', _getPlayerColor(_myColor));
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
        title: const Text('Parchís Online', style: TextStyle(color: Colors.white)),
        elevation: 2,
        actions: [
          if (_screenState == _LudoOnlineState.gameActive && !_gameEnded)
            IconButton(
              icon: const Icon(Icons.flag, color: Colors.white),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Abandonar?'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 48),
                        SizedBox(height: 16),
                        Text(
                          '¿Seguro que quieres abandonar la partida?\n\nSi abandonas, se contará como una derrota y perderás lo apostado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Continuar jugando', style: TextStyle(color: Colors.green)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Abandonar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) _endGame(_botColor);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          const BannerAdWidget(),
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
      _myColor: 'Tú',
      _botColor: _opponentName.isEmpty ? 'Bot' : _opponentName.split(' ').first,
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
                    onTap: null, // TODO: enviar emoji al chat
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
            onTap: null,
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
                        strokeWidth: 2, color: _getPlayerColor(_botColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pensando $_opponentName...',
                        style: TextStyle(
                          fontSize: 12, color: _getPlayerColor(_botColor),
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
        const Text('¿Cuánto quieres apostar?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parchís Online',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Busca oponentes en línea',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text('¿Cuántos jugadores?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

          if (widget.matchType == 'Apuesta') _buildBetSelection(),

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
                  Icon(widget.matchType == 'Apuesta' ? Icons.diamond : Icons.monetization_on,
                      color: widget.matchType == 'Apuesta' ? Colors.blue : Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tu balance: ${widget.matchType == 'Apuesta' ? '${_userDiamonds ?? 0} diamantes' : '${_userCoins ?? 0} monedas'}',
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
              onPressed: (widget.matchType == 'Apuesta' && _selectedBetAmount == null)
                  ? null
                  : _startMatchmaking,
              icon: const Icon(Icons.search, size: 22),
              label: const Text('Buscar partida',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              label: const Text('Invitar amigo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            const Text('Buscando partida...',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_matchmakingSeconds s · $_selectedPlayerCount jugadores',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(
              _matchmakingSeconds < 6
                  ? 'Conectando con otros jugadores...'
                  : '¡Ya casi! Ampliando búsqueda...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            OutlinedButton.icon(
              onPressed: _cancelMatchmaking,
              icon: const Icon(Icons.close),
              label: const Text('Cancelar búsqueda'),
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
                  ] else ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const Text('¡Todos listos! Iniciando...',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
                label: const Text('Invitar amigo'),
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
              label: const Text('Abandonar sala'),
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
                name != null ? (isMe ? 'Tú' : name.split(' ').first) : (colorNames[color] ?? '?'),
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

    final isBet = widget.matchType == 'Apuesta';
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
                        const Text('Invitar amigo',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        labelText: 'Email del amigo',
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
                        label: Text(isLoading ? 'Enviando...' : 'Enviar invitación',
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

    final currencyType = widget.matchType == 'Apuesta' ? 'diamonds' : 'coins';

    // Si ya hay una sala activa (p.ej. invitando al 2do/3er jugador), la reusamos
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
      // Solo cancelar el juego si lo acabamos de crear
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
      const SnackBar(
          content: Text('¡Invitación enviada! Esperando que tu amigo acepte...'),
          backgroundColor: Colors.green),
    );
  }

  void _showInsufficientFundsDialog() {
    final isBet = widget.matchType == 'Apuesta';
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
