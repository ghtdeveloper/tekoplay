import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/models/multiplayer_game_match_chess.dart';
import '../../../core/service/auth_service.dart';
import '../../../core/service/firestore_service.dart';
import '../../../core/service/multiplayer_game_service.dart';
import '../../../core/utils/game_type.dart';
import '../../../generated/l10n.dart';
import '../../../core/utils/game_result.dart';
import '../../adds/banner_ad_widget.dart';
import '../../adds/Interstitial_ad_helper.dart';

class MultiplayerChessScreen extends StatefulWidget {
  final String gameId;
  final bool isHost;
  final String matchType;

  const MultiplayerChessScreen({
    super.key,
    required this.gameId,
    this.isHost = false,
    required this.matchType,
  });

  @override
  State<MultiplayerChessScreen> createState() => _MultiplayerChessScreenState();
}

class _MultiplayerChessScreenState extends State<MultiplayerChessScreen>
    with WidgetsBindingObserver {
  ChessBoardController controller = ChessBoardController();

  MultiplayerGameMatch? _currentGame;
  StreamSubscription<MultiplayerGameMatch?>? _gameSubscription;

  bool _gameEnded = false;
  bool _showGameEndOverlay = false;
  String _gameEndMessage = '';
  bool _isMyTurn = false;
  Timer? _reconnectTimer;
  bool _isConnected = true;
  bool _waitingForMoveResponse = false;
  DateTime? _gameStartTime;

  Timer? _playerTimer;
  Timer? _initialMoveTimer;
  int _playerTimeSeconds = 60;
  bool _hasPlayerMovedOnce = false;
  bool _gameStarted = false;

  int? _userCoins;
  int? _userDiamonds;
  int? _selectedBetAmount;

  bool _hasUserExitedGame = false;
  int? _myRanking;
  int? _opponentRanking;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  late InterstitialAdHelper _interstitialHelper;

  MultiplayerGameService get _gameService => MultiplayerGameService();
  final FirestoreService _firestoreService = FirestoreService();

  PlayerColor? _myColor;
  String? _opponentName;
  String? _opponentPhotoUrl;

  bool _localizationsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameStartTime = DateTime.now();
    _loadUserCurrency();
    _loadPlayerRankings();
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
    _enableWakeLock();
  }

  Future<void> _enableWakeLock() async {
    try {
      if (!await WakelockPlus.enabled) {
        await WakelockPlus.enable();
      }
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_localizationsReady) {
      _loadUserCurrency();
      _loadPlayerRankings();
      _initializeGame();
      _localizationsReady = true;
    }
  }



  void _startInitialMoveTimer() {
    if (_hasPlayerMovedOnce || _gameEnded || !_isMyTurn) return;

    _initialMoveTimer?.cancel();
    _initialMoveTimer = Timer(const Duration(seconds: 14), () {
      if (!_hasPlayerMovedOnce && !_gameEnded && mounted && _isMyTurn) {
        _timeOut(isInitialTimeout: true);
      }
    });
  }

  void _startPlayerTimer() {
    if (_gameEnded || !_isMyTurn) return;

    _playerTimer?.cancel();
    _playerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_gameEnded) {
        timer.cancel();
        return;
      }

      if (_isMyTurn) {
        setState(() {
          _playerTimeSeconds--;
        });

        if (_playerTimeSeconds <= 0) {
          timer.cancel();
          _timeOut(isInitialTimeout: false);
        }
      }
    });
  }

  void _timeOut({required bool isInitialTimeout}) {
    if (_gameEnded) return;

    _gameEnded = true;
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();

    String message = isInitialTimeout
        ? 'Tiempo agotado: No realizaste tu primer movimiento en 14 segundos'
        : 'Tiempo agotado: No completaste tu movimiento en 1 minuto';

    _abandonGameDueToTimeout();

    _showTimeoutDialog(message);
  }

  Future<void> _abandonGameDueToTimeout() async {
    try {
      _hasUserExitedGame = true;

      await _gameService.abandonGame(
        gameId: widget.gameId,
        playerId: currentUser!.uid,
      );

      _recordGameResult(GameResultModel.loss);
    } catch (e) {
      if (kDebugMode) {
        print('Error al abandonar por timeout: $e');
      }
    }
  }

  void _showTimeoutDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Tiempo Agotado',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.timer_off, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Has perdido la partida por tiempo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(S.of(context).exit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final shouldShow = !_gameEnded && _isMyTurn && _gameStarted;

    final minutes = _playerTimeSeconds ~/ 60;
    final seconds = _playerTimeSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isRunningOut = _playerTimeSeconds <= 10;

    return Visibility(
      visible: shouldShow,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isRunningOut ? Colors.red[700] : Colors.green[700],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isRunningOut ? Colors.red : Colors.green).withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              timeString,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPlayerRankings() async {
    if (currentUser == null) return;
    try {
      final myGameStats = await AuthService().getCurrentUserGameStats(
        GameTypeModel.chess,
      );
      _myRanking = myGameStats?.points ?? 1000;

      if (_currentGame != null) {
        final opponentId =
        _currentGame!.hostId == currentUser!.uid
            ? _currentGame!.guestId
            : _currentGame!.hostId;

        if (opponentId != null) {
          final opponentDoc = await _firestoreService.getUser(opponentId);
          if (opponentDoc != null) {
            final opponentGameStats = await AuthService()
                .getOpponentUserGameStats(opponentDoc.id, GameTypeModel.chess);
            _opponentRanking = opponentGameStats?.points ?? 1000;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando rankings: $e');
      }
    }
  }
  Future<void> _loadUserCurrency({bool forceRefresh = false}) async {
    if (currentUser == null) return;
    try {
      final userDoc = await _firestoreService.getUser(currentUser!.uid);
      if (!mounted) return;
      if (userDoc != null) {
        setState(() {
          _userDiamonds = userDoc.diamonds;
          _userCoins = userDoc.coins;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error loading user currency: $e');
      }
      if (!mounted) return;
      setState(() {
        _userDiamonds = 0;
        _userCoins = 0;
      });
    }
  }

  String _getCurrencyName() {
    return widget.matchType == S.of(context).bet ? 'diamonds' : 'coins';
  }

  IconData _getCurrencyIcon() {
    return widget.matchType == S.of(context).bet
        ? Icons.diamond
        : Icons.monetization_on;
  }

  int? _getCurrentBalance() {
    return widget.matchType == S.of(context).bet ? _userDiamonds : _userCoins;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);



    if (state == AppLifecycleState.paused) {
      _disableWakeLock();
      _handleAppPause();
    } else if (state == AppLifecycleState.resumed) {
      _enableWakeLock();
      _handleAppResume();
    }
  }

  void _handleAppPause() {
    _reconnectTimer?.cancel();
  }

  void _handleAppResume() {
    _checkConnectionAndSync();
  }

  void _checkConnectionAndSync() {
    if (!_isConnected) {
      setState(() => _isConnected = true);
      if (_currentGame != null) {
        _syncGameState();
      }
    }
  }

  void _initializeGame() {
    final gameNotFoundString = S.of(context).gameNotFound;
    if (currentUser == null) {
      _showErrorAndExit(S.of(context).userNotFound);
      return;
    }
    _gameSubscription = _gameService
        .getGameStream(widget.gameId)
        .listen(
          (game) {
        if (game == null) {
          _showErrorAndExit(gameNotFoundString);
          return;
        }
        _handleGameUpdate(game);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          print('Error in game stream: $error');
        }
        setState(() => _isConnected = false);
        _startReconnectTimer();
        return false;
      },
    );
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkConnectionAndSync();
    });
  }

  void _handleGameUpdate(MultiplayerGameMatch game) {
    final previousGame = _currentGame;
    _currentGame = game;

    if (previousGame == null) {
      _setupGameInfo(game);
      _loadPlayerRankings();
    }

    if (previousGame != null &&
        !previousGame.quotasCollected &&
        game.quotasCollected) {
      if (kDebugMode) {
        print('✅ Cuotas cobradas exitosamente');
        print('   Total Pot: ${game.totalPot}');
        print('   Currency Type: ${game.currencyType}');
      }

      _loadUserCurrency(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cuotas cobradas. ¡El juego está listo!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (!_gameStarted && game.status == 'active' && game.guestId != null) {
      _gameStarted = true;

      if (kDebugMode) {
        print('🎮 Juego iniciado - Guest: ${game.guestName}');
      }

      if (game.isPlayerTurn(currentUser!.uid)) {
        setState(() {
          _isMyTurn = true;
          _playerTimeSeconds = 60;
        });
        _startInitialMoveTimer();

        if (kDebugMode) {
          print('⏰ Timer iniciado - Es tu turno');
        }
      }
    }

    final wasMyTurn = _isMyTurn;
    _isMyTurn = game.isPlayerTurn(currentUser!.uid);

    bool shouldSync = false;

    if (previousGame == null) {
      shouldSync = true;
    } else {
      if (previousGame.moves.length != game.moves.length) {
        shouldSync = true;
        _waitingForMoveResponse = false;

        if (kDebugMode) {
          print('🔄 Sincronizando - Nuevo movimiento detectado');
          print('   Movimientos: ${previousGame.moves.length} -> ${game.moves.length}');
        }
      }
      else if (previousGame.currentFen != game.currentFen) {
        shouldSync = true;

        if (kDebugMode) {
          print('🔄 Sincronizando - FEN actualizado');
        }
      }
    }

    if (shouldSync) {
      _syncGameState();
    }

    if (_gameStarted && wasMyTurn != _isMyTurn) {
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();

      if (_isMyTurn) {
        setState(() {
          _playerTimeSeconds = 60;
        });

        if (!_hasPlayerMovedOnce) {
          _startInitialMoveTimer();
          if (kDebugMode) {
            print('⏰ Timer inicial de 14 segundos iniciado');
          }
        } else {
          _startPlayerTimer();
          if (kDebugMode) {
            print('⏰ Timer de 60 segundos iniciado');
          }
        }
      } else {
        // Ya no es mi turno
        if (kDebugMode) {
          print('⏸️ No es tu turno - Esperando movimiento del oponente');
        }
      }
    }

    if (game.isAbandoned && !_gameEnded) {
      if (kDebugMode) {
        print('🚪 Juego abandonado detectado');
        print('   Abandonado por: ${game.abandonedBy}');
        print('   Ganador: ${game.winnerId}');
      }

      if (game.didOpponentAbandon(currentUser!.uid)) {
        _handleOpponentAbandoned(game);
      } else if (game.didIAbandon(currentUser!.uid) && !_hasUserExitedGame) {
        // Yo abandoné
        _gameEnded = true;

        if (kDebugMode) {
          print('🚪 Tú abandonaste el juego');
        }
      }
    }

    else if (!_gameEnded && game.isFinished) {
      _gameEnded = true;

      if (kDebugMode) {
        print('🏁 Juego finalizado');
        print('   Resultado: ${game.result}');
        print('   Ganador: ${game.winnerId}');
      }

      _handleGameEnd(game);
    }

    else if (game.status == 'waiting' && previousGame?.status == 'active') {
      if (kDebugMode) {
        print('📡 Oponente desconectado temporalmente');
      }
      _showOpponentDisconnected();
    }

    if (previousGame != null &&
        !previousGame.rewardsDistributed &&
        game.rewardsDistributed) {
      if (kDebugMode) {
        print('💰 Recompensas distribuidas por Cloud Function');
        if (game.toFirestore()['distribution'] != null) {
          final distribution = game.toFirestore()['distribution'];
          print('   Host reward: ${distribution['hostReward']}');
          print('   Guest reward: ${distribution['guestReward']}');
          print('   House commission: ${distribution['houseCommission']}');
        }
      }

      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          _loadUserCurrency(forceRefresh: true);
        }
      });
    }

    setState(() {});
  }

  void _handleOpponentAbandoned(MultiplayerGameMatch game) {
    if (_gameEnded) {
      return;
    }
    _gameEnded = true;
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();

    final opponentName =
        game.getOpponentName(currentUser!.uid) ?? S.of(context).rivals;

    _recordGameResult(GameResultModel.win).then((_) {
      _loadUserCurrency(forceRefresh: true);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_off, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                S.of(context).gameOver,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.orange),
                    SizedBox(height: 12),
                    Text(
                      '$opponentName ${S.of(context).hasLeftTheGame}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.green, size: 24),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            S.of(context).opponentAbandonedMessage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.check_circle),
              label: Text(S.of(context).exit),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showAbandonDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
        title: Text(
          '¿${S.of(context).abandonGame}?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              S.of(context).abandonGameWarning,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              S.of(context).areYouSure,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).continueGame),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(S.of(context).abandonGame),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _abandonGame() async {
    if (_gameEnded) {
      return;
    }
    try {
      _hasUserExitedGame = true;
      _gameEnded = true;
      _playerTimer?.cancel();
      _initialMoveTimer?.cancel();

      final success = await _gameService.abandonGame(
        gameId: widget.gameId,
        playerId: currentUser!.uid,
      );

      if (success) {
        _recordGameResult(GameResultModel.loss);
      } else {
        _gameEnded = false;
        _hasUserExitedGame = false;
      }
    } catch (e) {
      _hasUserExitedGame = false;
    }
  }

  void _setupGameInfo(MultiplayerGameMatch game) {
    final isHost = game.hostId == currentUser!.uid;
    _myColor = isHost ? PlayerColor.white : PlayerColor.black;

    _opponentName = game.getOpponentName(currentUser!.uid);
    _opponentPhotoUrl = isHost ? game.guestPhotoUrl : game.hostPhotoUrl;

    _selectedBetAmount = game.betAmount;

  }

  void _syncGameState() {
    if (_currentGame == null) return;
    try {
      if (controller.getFen() != _currentGame!.currentFen) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            controller.loadFen(_currentGame!.currentFen);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing game state: $e');
        print('Could not sync with FEN, keeping current board state');
      }
    }
  }

  void _playerMoved() async {
    if (!_isMyTurn ||
        _gameEnded ||
        _waitingForMoveResponse ||
        _currentGame == null) {
      return;
    }
    _waitingForMoveResponse = true;

    if (!_hasPlayerMovedOnce) {
      _hasPlayerMovedOnce = true;
      _initialMoveTimer?.cancel();
    }

    _playerTimer?.cancel();

    try {
      final newFen = controller.getFen();

      final success = await _gameService.makeMove(
        gameId: widget.gameId,
        playerId: currentUser!.uid,
        from: "player",
        to: "move",
        promotion: null,
        newFen: newFen,
        moveNotation: "move",
      );

      if (!mounted) return;
      if (!success) {
        _syncGameState();
        _showError('Error al enviar movimiento. Inténtalo de nuevo.');
        _waitingForMoveResponse = false;
      } else {
        _checkForGameEnd(newFen);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _playerMoved: $e');
      }
      _syncGameState();
      _showError('Error al realizar movimiento');
      _waitingForMoveResponse = false;
    }
  }

  void _checkForGameEnd(String fen) {
    if (_gameEnded) return;

    bool isCheckMate = controller.isCheckMate();
    bool isDraw = controller.isDraw();
    bool isStaleMate = controller.isStaleMate();
    bool isThreefoldRepetition = controller.isThreefoldRepetition();
    bool isInsufficientMaterial = controller.isInsufficientMaterial();

    GameResultModel? result;
    String? winnerId;

    if (isCheckMate) {
      result = GameResultModel.win;
      winnerId = currentUser!.uid;
    } else if (isDraw ||
        isStaleMate ||
        isThreefoldRepetition ||
        isInsufficientMaterial) {
      result = GameResultModel.draw;
    }

    if (result != null) {
      _finishGame(result, winnerId);
    }
  }

  Future<void> _finishGame(GameResultModel result, String? winnerId) async {
    if (_gameEnded) return;
    _gameEnded = true;
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();
    try {
      await _gameService.finishGame(
        gameId: widget.gameId,
        result: result,
        winnerId: winnerId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error finishing game: $e');
      }
    }
  }

  void _handleGameEnd(MultiplayerGameMatch game) {
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();

    String message;
    GameResultModel gameResult;

    if (game.result == GameResultModel.draw) {
      message = S.of(context).drawMsg;
      gameResult = GameResultModel.draw;
    } else if (game.winnerId == currentUser!.uid) {
      message = '${S.of(context).youWonCheckMate}\n  ${S.of(context).congrats}';
      gameResult = GameResultModel.win;
    } else {
      message = S
          .of(context)
          .cpuWonCheckMate
          .replaceAll('CPU', _opponentName ?? S.of(context).rivals);
      gameResult = GameResultModel.loss;
    }
    _recordGameResult(gameResult).then((_) {
      _loadUserCurrency(forceRefresh: true);
    });
    _showGameEndDialog(message);
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (currentUser == null || _gameStartTime == null || _currentGame == null) return;
    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      int pointsEarned = 0;

      switch (result) {
        case GameResultModel.win:
          pointsEarned = 15;
          break;
        case GameResultModel.loss:
          pointsEarned = -5;
          break;
        case GameResultModel.draw:
          pointsEarned = 5;
          break;
      }

      if (_currentGame?.isRanked == true) {
        pointsEarned = (pointsEarned * 1.5).round();
      }

      await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: _opponentName ?? 'Jugador desconocido',
        additionalData: {
          'gameMode': 'multiplayer',
          'isRanked': _currentGame?.isRanked ?? false,
          'betAmount': _selectedBetAmount,
          'gameId': widget.gameId,
          'matchType': widget.matchType,
          'quotasPaid': _currentGame?.quotasCollected ?? false,
        },
      );

    } catch (e) {
      if (kDebugMode) {
        print('💥 Error registrando resultado: $e');
      }
    }
  }

  void _showGameEndDialog(String message) {
    if (!mounted) return;
    setState(() {
      _showGameEndOverlay = true;
      _gameEndMessage = message;
    });
  }

  Widget _buildGameEndOverlay() {
    final isWin = _gameEndMessage.toLowerCase().contains('ganaste') ||
        _gameEndMessage.toLowerCase().contains('won');
    final color = isWin ? Colors.green[700]! : Colors.red[700]!;
    final icon = isWin ? Icons.emoji_events_rounded : Icons.sports_esports_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gameEndMessage,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameEndButtons() {
    final isWin = _gameEndMessage.toLowerCase().contains('ganaste') ||
        _gameEndMessage.toLowerCase().contains('won');
    final color = isWin ? Colors.green[700]! : Colors.red[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(S.of(context).exit),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpponentDisconnected() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).offlineOpponent),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(bool isMe) {
    if (_currentGame == null) return SizedBox();

    final name =
    isMe
        ? (currentUser?.displayName ?? S.of(context).you)
        : (_opponentName ?? S.of(context).rivals);

    final photoUrl = isMe ? currentUser?.photoURL : _opponentPhotoUrl;
    final isPlayerTurn = isMe ? _isMyTurn : !_isMyTurn;
    final isWaitingForResponse = isMe && _waitingForMoveResponse;
    final ranking = isMe ? _myRanking : _opponentRanking;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
        isPlayerTurn
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
        isPlayerTurn
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? Icon(Icons.person, size: 25) : null,
              ),
              if (isPlayerTurn && !isWaitingForResponse)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 12),


          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ranking != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRankingColor(ranking),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '$ranking',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 4),

                Row(
                  children: [
                    if (isPlayerTurn && !isWaitingForResponse) ...[
                      Icon(Icons.play_arrow, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        S.of(context).yourTurn,
                        style: TextStyle(
                          color: Colors.green[300],
                          fontSize: 12,
                        ),
                      ),
                    ] else if (isWaitingForResponse) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        S.of(context).sending,
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ] else ...[
                      Icon(
                        Icons.hourglass_empty,
                        color: Colors.white60,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        S.of(context).waiting,
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],

                    Spacer(),

                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color:
                        isMe
                            ? (_myColor == PlayerColor.white
                            ? Colors.white
                            : Colors.black)
                            : (_myColor == PlayerColor.white
                            ? Colors.black
                            : Colors.white),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getRankingColor(int points) {
    if (points >= 1000) return Colors.purple;
    if (points >= 500) return Colors.amber;
    if (points >= 200) return Colors.blue;
    if (points >= 50) return Colors.green;
    return Colors.grey;
  }

  Widget _buildConnectionStatus() {
    if (_isConnected) return SizedBox();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      color: Colors.red[700],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            S.of(context).reconnecting,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo() {
    if (_currentGame == null) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentGame!.isRanked)
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text(
                  S.of(context).qualifier,
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
            ),
          if (_selectedBetAmount != null)
            Row(
              children: [
                Icon(
                  _getCurrencyIcon(),
                  color:
                  widget.matchType == S.of(context).bet
                      ? Colors.amber
                      : Colors.blue,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '$_selectedBetAmount ${_getCurrencyName()}',
                  style: TextStyle(
                    color:
                    widget.matchType == S.of(context).bet
                        ? Colors.amber
                        : Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDisplay() {
    final currentBalance = _getCurrentBalance() ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCurrencyIcon(),
            color:
            widget.matchType == S.of(context).bet
                ? Colors.amber
                : Colors.blue,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            '$currentBalance',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _playerTimer?.cancel();
    _initialMoveTimer?.cancel();

    if (!_gameEnded &&
        !_hasUserExitedGame &&
        _currentGame != null &&
        _currentGame!.isActive) {
      _gameService
          .abandonGame(gameId: widget.gameId, playerId: currentUser!.uid)
          .catchError((e){
        if (kDebugMode) {
          print('Error en abandono desde dispose: $e');
        }
      });
    }
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _reconnectTimer?.cancel();
    _interstitialHelper.dispose();
    _disableWakeLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGame == null) {
      return Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                S.of(context).loadingGame,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final isWaitingForOpponent =
        _currentGame!.status == 'waiting' && _currentGame!.guestId == null;

    if (isWaitingForOpponent) {
      return Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        appBar: AppBar(
          backgroundColor: const ui.Color(0xFFEC7A34),
          elevation: 0,
          title: Text(
            S.of(context).waitingOpponent,
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Center(child: _buildCurrencyDisplay()),
            SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                S.of(context).waitingForOpponentJoin,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                '${S.of(context).gameCode}: ${widget.gameId.substring(0, 8)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (_selectedBetAmount != null) ...[
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getCurrencyIcon(), color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Apuesta: $_selectedBetAmount ${_getCurrencyName()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final cancelled = await _gameService.cancelGame(
                    widget.gameId,
                    currentUser!.uid,
                  );
                  if (cancelled) {
                    navigator.pop();
                  }
                },
                icon: Icon(Icons.close),
                label: Text(S.of(context).cancel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: _gameEnded || _hasUserExitedGame,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldAbandon = await _showAbandonDialog();
        if (shouldAbandon) {
          _interstitialHelper.forceShowAd(
            onComplete: () async {
              final navigator = Navigator.of(context);
              await _abandonGame();
              navigator.pop();
            },
          );
        }
      },
      child: Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        appBar: AppBar(
          backgroundColor: const ui.Color(0xFFEC7A34),
          elevation: 0,
          title: Text(
            S.of(context).multiplayer,
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Center(child: _buildCurrencyDisplay()),
            SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            _buildConnectionStatus(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildPlayerInfo(false),
            ),

            _buildGameInfo(),

            _buildTimer(),

            if (_showGameEndOverlay) _buildGameEndOverlay(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChessBoard(
                  controller: controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: _myColor ?? PlayerColor.white,
                  enableUserMoves: _isMyTurn && !_gameEnded && _gameStarted,
                  onMove: _playerMoved,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildPlayerInfo(true),
            ),

            if (_showGameEndOverlay)
              _buildGameEndButtons()
            else if (!_gameEnded && _gameStarted)
              Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _isMyTurn
                      ? S.of(context).yourTurn
                      : S.of(context).opponentTurn,
                  style: TextStyle(
                    color: _isMyTurn ? Colors.green[300] : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const BannerAdWidget(),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}