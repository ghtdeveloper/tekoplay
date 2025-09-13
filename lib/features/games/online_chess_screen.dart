import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';
import 'package:flutter_stockfish_plugin/stockfish_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/multiplayer_game_match_chess.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/firestore_service.dart';
import '../../core/service/online_match_chess_game_service.dart';
import '../../generated/l10n.dart';
import '../../core/utils/game_result.dart';
import '../../core/utils/game_type.dart';
import '../adds/BannerAdWidget.dart';
import '../adds/InterstitialAdHelper.dart';

class OnlineChessScreen extends StatefulWidget {
  final String matchType;

  const OnlineChessScreen({super.key, required this.matchType});

  @override
  State<OnlineChessScreen> createState() => _OnlineChessScreenState();
}

class _OnlineChessScreenState extends State<OnlineChessScreen>
    with WidgetsBindingObserver {
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _lastMovePromotion;
  late InterstitialAdHelper _interstitialHelper;
  OnlineGameState _gameState = OnlineGameState.timeSelection;
  int? _myRanking;
  int? _opponentRanking;

  int? _selectedTimeMinutes;
  final List<TimeOption> _timeOptions = [
    TimeOption(minutes: null, display: 'Sin tiempo'),
    TimeOption(minutes: 1, display: '1 minuto'),
    TimeOption(minutes: 3, display: '3 minutos'),
    TimeOption(minutes: 5, display: '5 minutos'),
    TimeOption(minutes: 10, display: '10 minutos'),
  ];

  Timer? _matchmakingTimer;
  Timer? _gameTimer;
  int _matchmakingSeconds = 0;

  ChessBoardController controller = ChessBoardController();
  MultiplayerGameMatch? _currentGame;
  StreamSubscription<MultiplayerGameMatch?>? _gameSubscription;

  User? get currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isMyTurn = false;
  PlayerColor? _myColor;
  String? _opponentName;
  String? _opponentPhotoUrl;
  bool _gameEnded = false;
  bool _isProcessingMove = false;
  DateTime? _gameStartTime;

  int _myTimeSeconds = 0;
  int _opponentTimeSeconds = 0;
  Timer? _playerTimer;

  bool _isPlayingAgainstBot = false;
  Stockfish? _stockfish;
  bool _isStockfishReady = false;
  bool _engineThinking = false;
  int _cpuMoveTime = 200;
  Timer? _botMoveTimer;
  Random _random = Random();

  final List<Map<String, String>> _botProfiles = [
    {'name': 'Player1923', 'avatar': '🤖'},
    {'name': 'Player2323', 'avatar': '👾'},
    {'name': 'Player6303', 'avatar': '🎮'},
    {'name': 'Player8093', 'avatar': '🎯'},
    {'name': 'Player7993', 'avatar': '♟️'},
    {'name': 'Player0967', 'avatar': '🧠'},
    {'name': 'Player1569', 'avatar': '📊'},
    {'name': 'Player5529', 'avatar': '👑'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStockfish();
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
  }

  void _initializeStockfish() {
    _stockfish = Stockfish();

    _stockfish!.stdout.listen((output) {
      if (!_isPlayingAgainstBot) return;

      if (output.contains('bestmove ')) {
        final parts = output.split(' ');
        if (parts.length >= 2) {
          final best = parts[1];
          _engineThinking = false;

          if (best == '0000' || best == '(none)') return;

          if (_shouldBotMakeMove()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _applyBotMove(best);
            });
          } else {
            _makeBadMove();
          }

          setState(() {});
        }
      }
    });

    _stockfish!.state.addListener(() async {
      if (_stockfish!.state.value == StockfishState.ready &&
          !_isStockfishReady) {
        _isStockfishReady = true;
        await _setupStockfish();
      }
    });
  }

  Future<void> _setupStockfish() async {
    _stockfish!.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    _stockfish!.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));

    if (widget.matchType == S.of(context).bet) {
      _cpuMoveTime = 500;
      _stockfish!.stdin = "setoption name Threads value 2";
      _stockfish!.stdin = "setoption name Hash value 64";
      _stockfish!.stdin = "setoption name Skill Level value 20";
    } else if (widget.matchType == S.of(context).fun) {
      _cpuMoveTime = 200;
      _stockfish!.stdin = "setoption name Threads value 1";
      _stockfish!.stdin = "setoption name Hash value 32";
      _stockfish!.stdin = "setoption name Skill Level value 10";
    } else {
      // Normal
      _cpuMoveTime = 250;
      _stockfish!.stdin = "setoption name Threads value 1";
      _stockfish!.stdin = "setoption name Hash value 32";
      _stockfish!.stdin = "setoption name Skill Level value 12";
    }
  }

  bool _shouldBotMakeMove() {
    if (widget.matchType == S.of(context).bet) {
      return _random.nextInt(100) < 99;
    } else if (widget.matchType == S.of(context).fun) {
      return _random.nextInt(100) < 55;
    }
    return _random.nextInt(100) < 75;
  }

  void _makeBadMove() {
    _botMoveTimer = Timer(Duration(milliseconds: 500), () {
      if (!_gameEnded && !_isMyTurn && _isPlayingAgainstBot) {
        final fen = controller.getFen();
        _stockfish!.stdin = "position fen $fen";
        _stockfish!.stdin = "go movetime 10";
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupTimers();
    _gameSubscription?.cancel();
    _botMoveTimer?.cancel();
    if (_isStockfishReady && _stockfish != null) {
      _stockfish!.stdin = "quit";
    }
    _stockfish?.dispose();
    _interstitialHelper.dispose();
    super.dispose();
  }

  void _cleanupTimers() {
    _matchmakingTimer?.cancel();
    _gameTimer?.cancel();
    _playerTimer?.cancel();
    _botMoveTimer?.cancel();
  }

  Widget _buildTimeSelectionScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).playOnline,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              S.of(context).selectGameTime,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Expanded(
              child: ListView.builder(
                itemCount: _timeOptions.length,
                itemBuilder: (context, index) {
                  final option = _timeOptions[index];
                  final isSelected = _selectedTimeMinutes == option.minutes;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap:
                            () => setState(
                              () => _selectedTimeMinutes = option.minutes,
                            ),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color:
                                isSelected ? Colors.green[100] : Colors.white,
                            border: Border.all(
                              color:
                                  isSelected ? Colors.green : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected ? Colors.green : Colors.grey,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option.display,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    color:
                                        isSelected
                                            ? Colors.green[800]
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                              if (option.minutes != null)
                                Icon(
                                  Icons.timer,
                                  color:
                                      isSelected ? Colors.green : Colors.grey,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedTimeMinutes != null ||
                            _timeOptions.any(
                              (o) => o.minutes == _selectedTimeMinutes,
                            )
                        ? _startMatchmaking
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  S.of(context).searchGame,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startMatchmaking() async {
    if (currentUser == null) return;

    setState(() {
      _gameState = OnlineGameState.searching;
      _matchmakingSeconds = 0;
    });

    final userRanking = await _getUserRanking();
    String? gameId;

    _matchmakingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() => _matchmakingSeconds++);

      if (_matchmakingSeconds % 5 == 0 && !_isPlayingAgainstBot) {
        try {
          final waitingGames = await OnlineMatchmakingChessService()
              .findWaitingGamesProgressive(
                gameType: 'Ajedrez',
                userRanking: userRanking,
                timeMinutes: _selectedTimeMinutes,
                searchTimeSeconds: _matchmakingSeconds,
              );

          if (waitingGames.isNotEmpty) {
            final game = waitingGames.first;
            final success = await MultiplayerGameService().joinGame(
              game.id,
              currentUser!.uid,
              currentUser!.displayName ?? 'Usuario',
              currentUser!.photoURL,
            );

            if (success) {
              gameId = game.id;
              timer.cancel();
              _startGameSubscription(gameId!);
              return;
            }
          }
        } catch (e) {
          print('Error durante la búsqueda progresiva: $e');
        }
      }

      if (_matchmakingSeconds == 1) {
        try {
          gameId = await _findOrCreateGame(userRanking);
          if (gameId != null && !_isPlayingAgainstBot) {
            timer.cancel();
            _startGameSubscription(gameId!);
            return;
          }
        } catch (e) {
          print('Error creando partida inicial: $e');
        }
      }

      if (_matchmakingSeconds >= 60 && !_isPlayingAgainstBot) {
        timer.cancel();
        _startBotGame();
      }
    });
  }

  void _startBotGame() {
    setState(() {
      _isPlayingAgainstBot = true;
      _gameState = OnlineGameState.playing;
      final botProfile = _botProfiles[_random.nextInt(_botProfiles.length)];
      _opponentName = botProfile['name'];
      _opponentPhotoUrl = null;
      _myColor = _random.nextBool() ? PlayerColor.white : PlayerColor.black;
      controller.resetBoard();
      _gameStartTime = DateTime.now();

      _loadMyRankingAndGenerateBotRanking();

      if (_selectedTimeMinutes != null) {
        _myTimeSeconds = _selectedTimeMinutes! * 60;
        _opponentTimeSeconds = _selectedTimeMinutes! * 60;
        _startPlayerTimer();
      }

      _isMyTurn = _myColor == PlayerColor.white;

      if (_myColor == PlayerColor.black) {
        _makeBotMove();
      }
    });
  }

  Future<void> _loadMyRankingAndGenerateBotRanking() async {
    try {
      final myGameStats = await AuthService().getCurrentUserGameStats(GameTypeModel.chess);
      _myRanking = myGameStats?.points ?? 1000;

      if (widget.matchType == S.of(context).bet) {
        _opponentRanking = (_myRanking! + _random.nextInt(200) - 50).clamp(800, 2400);
      } else if (widget.matchType == S.of(context).fun) {
        _opponentRanking = (_myRanking! + _random.nextInt(400) - 300).clamp(600, 1800);
      } else {
        _opponentRanking = (_myRanking! + _random.nextInt(300) - 150).clamp(700, 2200);
      }

      setState(() {});
    } catch (e) {
      print('Error cargando mi ranking: $e');
      _myRanking = 1000;
      _opponentRanking = 1000 + _random.nextInt(400) - 200;
      setState(() {});
    }
  }

  void _makeBotMove() {
    if (!_isStockfishReady || _gameEnded || !_isPlayingAgainstBot) return;

    _engineThinking = true;
    setState(() {});

    _botMoveTimer = Timer(
      Duration(milliseconds: 500 + _random.nextInt(1500)),
      () {
        if (!_gameEnded && !_isMyTurn) {
          final fen = controller.getFen();
          _stockfish!.stdin = "position fen $fen";
          _stockfish!.stdin = "go movetime $_cpuMoveTime";
        }
      },
    );
  }

  void _applyBotMove(String uci) {
    if (_gameEnded || _isMyTurn || !_isPlayingAgainstBot) return;

    if (uci.length == 4) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      controller.makeMove(from: from, to: to);
    } else if (uci.length == 5) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.substring(4).toUpperCase();
      controller.makeMoveWithPromotion(
        from: from,
        to: to,
        pieceToPromoteTo: promo,
      );
    }

    setState(() {
      _isMyTurn = true;
      _engineThinking = false;
    });

    _checkGameEnd();
  }

  Future<int> _getUserRanking() async {
    final gameStats = await AuthService().getCurrentUserGameStats(
      GameTypeModel.chess,
    );
    return gameStats?.points ?? 1000;
  }

  Future<String?> _findOrCreateGame(int userRanking) async {
    try {
      final waitingGames = await OnlineMatchmakingChessService()
          .findWaitingGames(
            gameType: 'Ajedrez',
            userRanking: userRanking,
            timeMinutes: _selectedTimeMinutes,
          );
      if (waitingGames.isNotEmpty) {
        final game = waitingGames.first;
        final success = await MultiplayerGameService().joinGame(
          game.id,
          currentUser!.uid,
          currentUser!.displayName ?? 'Usuario',
          currentUser!.photoURL,
        );

        return success ? game.id : null;
      } else {
        return await OnlineMatchmakingChessService().createOnlineGame(
          hostId: currentUser!.uid,
          hostName: currentUser!.displayName ?? 'Usuario',
          hostPhotoUrl: currentUser!.photoURL,
          gameType: 'Ajedrez',
          timeMinutes: _selectedTimeMinutes,
          hostRanking: userRanking,
        );
      }
    } catch (e) {
      print('Error in matchmaking: $e');
      return null;
    }
  }

  void _startGameSubscription(String gameId) {
    _gameSubscription = MultiplayerGameService()
        .getGameStream(gameId)
        .listen(
          (game) {
            if (game == null) {
              _showErrorAndReturn(S.of(context).gameNotFound);
              return;
            }
            _handleGameUpdate(game);
          },
          onError: (error) {
            print('Error in game stream: $error');
            _showErrorAndReturn(S.of(context).connectionError);
          },
        );
  }

  void _handleGameUpdate(MultiplayerGameMatch game) {
    final previousGame = _currentGame;
    _currentGame = game;

    if (previousGame?.status != 'active' && game.status == 'active') {
      _setupGame(game);
      setState(() => _gameState = OnlineGameState.playing);
    }

    final _ = _isMyTurn;
    _isMyTurn = game.isPlayerTurn(currentUser!.uid);

    bool shouldSync = false;

    if (previousGame == null) {
      shouldSync = true;
    } else if (!_isProcessingMove &&
        previousGame.currentFen != game.currentFen) {
      shouldSync = true;
    }

    if (shouldSync && !_isProcessingMove) {
      _syncGameState();
    }

    if (!_gameEnded && game.isFinished) {
      _gameEnded = true;
      _handleGameEnd(game);
    }

    setState(() {});
  }

  void _setupGame(MultiplayerGameMatch game) {
    final isHost = game.hostId == currentUser!.uid;
    _myColor = isHost ? PlayerColor.white : PlayerColor.black;
    _opponentName = game.getOpponentName(currentUser!.uid);
    _opponentPhotoUrl = isHost ? game.guestPhotoUrl : game.hostPhotoUrl;
    controller.loadFen(game.currentFen);
    _gameStartTime = DateTime.now();

    _loadPlayerRankings(game);

    if (_selectedTimeMinutes != null) {
      _myTimeSeconds = _selectedTimeMinutes! * 60;
      _opponentTimeSeconds = _selectedTimeMinutes! * 60;
      _startPlayerTimer();
    }
  }

  Future<void> _loadPlayerRankings(MultiplayerGameMatch game) async {
    try {
      final myGameStats = await AuthService().getCurrentUserGameStats(GameTypeModel.chess);
      _myRanking = myGameStats?.points ?? 1000;

      final opponentId = game.getOpponentId(currentUser!.uid);
      final opponentStats = await FirestoreService().getUserGameStats(opponentId!, GameTypeModel.chess);
      _opponentRanking = opponentStats?.points ?? 1000;

      setState(() {});
    } catch (e) {
      print('Error cargando rankings: $e');
      _myRanking = 1000;
      _opponentRanking = 1000;
      setState(() {});
    }
  }

  void _startPlayerTimer() {
    _playerTimer?.cancel();

    if (_selectedTimeMinutes == null) return;

    _playerTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_gameEnded) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_isMyTurn) {
          _myTimeSeconds--;
          if (_myTimeSeconds <= 0) {
            _timeOut(isMyTimeout: true);
          }
        } else {
          _opponentTimeSeconds--;
          if (_opponentTimeSeconds <= 0) {
            _timeOut(isMyTimeout: false);
          }
        }
      });
    });
  }

  void _timeOut({required bool isMyTimeout}) {
    if (_gameEnded) return;

    _gameEnded = true;
    _playerTimer?.cancel();

    _showTimeoutDialog(isMyTimeout: isMyTimeout);

    final result = isMyTimeout ? GameResultModel.loss : GameResultModel.win;
    _recordGameResult(result);

    if (!_isPlayingAgainstBot && _currentGame != null) {
      final winnerId = isMyTimeout
          ? _currentGame!.getOpponentId(currentUser!.uid)
          : currentUser!.uid;

      MultiplayerGameService().finishGame(
        gameId: _currentGame!.id,
        result: result,
        winnerId: winnerId,
        reason: 'timeout',
      );
    }

    _interstitialHelper.forceShowAd(onComplete: () {
      _showTimeoutDialog(isMyTimeout: isMyTimeout);
    });
  }


  void _showTimeoutDialog({required bool isMyTimeout}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.timer_off,
              color: isMyTimeout ? Colors.red : Colors.green,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              isMyTimeout ? S.of(context).timeOut : S.of(context).youWon,
              style: TextStyle(
                color: isMyTimeout ? Colors.red : Colors.green,
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
                color: isMyTimeout ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMyTimeout ? Colors.red[200]! : Colors.green[200]!,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isMyTimeout ? Icons.timer_off : Icons.emoji_events,
                    size: 48,
                    color: isMyTimeout ? Colors.red : Colors.green,
                  ),
                  SizedBox(height: 12),
                  Text(
                    isMyTimeout
                        ? S.of(context).youLostByTimeout
                        : S.of(context).opponentLostByTimeout,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isMyTimeout ? Colors.red[800] : Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    isMyTimeout
                        ? S.of(context).timeRunOutMessage
                        : S.of(context).opponentTimeRunOutMessage,
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
            child: Text(S.of(context).exit),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
              backgroundColor: Colors.green[50],
            ),
            child: Text(S.of(context).playAgain),
          ),
        ],
      ),
    );
  }

  void _syncGameState() {
    if (_currentGame == null || _isProcessingMove) return;

    try {
      final currentFen = controller.getFen();
      final targetFen = _currentGame!.currentFen;

      if (currentFen != targetFen) {
        controller.loadFen(targetFen);
      }
    } catch (e) {
      print('Error syncing game state: $e');
    }
  }

  void _playerMoved({String? from, String? to, String? promotion}) async {
    if (_isPlayingAgainstBot) {
      _handleBotGameMove();
    } else {
      await _handleOnlineGameMove(from: from, to: to, promotion: promotion);
    }
  }

  void _handleBotGameMove() {
    if (!_isMyTurn || _gameEnded || _isProcessingMove) return;

    setState(() {
      _isMyTurn = false;
    });

    _checkGameEnd();

    if (!_gameEnded) {
      _makeBotMove();
    }
  }

  Future<void> _handleOnlineGameMove({
    String? from,
    String? to,
    String? promotion,
  }) async {
    if (!_isMyTurn || _gameEnded || _isProcessingMove || _currentGame == null) {
      return;
    }

    _isProcessingMove = true;

    try {
      final newFen = controller.getFen();

      String moveFrom = from ?? _lastMoveFrom ?? "xx";
      String moveTo = to ?? _lastMoveTo ?? "xx";
      String? movePromotion = promotion ?? _lastMovePromotion;

      String moveNotation =
          movePromotion != null
              ? '$moveFrom$moveTo$movePromotion'
              : '$moveFrom$moveTo';

      final success = await MultiplayerGameService().makeMove(
        gameId: _currentGame!.id,
        playerId: currentUser!.uid,
        from: moveFrom,
        to: moveTo,
        promotion: movePromotion,
        newFen: newFen,
        moveNotation: moveNotation,
      );

      if (!success) {
        _syncGameState();
        _showError(S.of(context).errorSendMove);
      } else {
        _lastMoveFrom = moveFrom;
        _lastMoveTo = moveTo;
        _lastMovePromotion = movePromotion;

        _checkForGameEnd(newFen);
      }
    } catch (e) {
      print('Error in _playerMoved: $e');
      _syncGameState();
      _showError(S.of(context).errorMakeMove);
    } finally {
      _isProcessingMove = false;
    }
  }

  void _checkGameEnd() {
    if (_gameEnded) return;

    bool isCheckMate = controller.isCheckMate();
    bool isDraw = controller.isDraw();
    bool isStaleMate = controller.isStaleMate();
    bool isThreefoldRepetition = controller.isThreefoldRepetition();
    bool isInsufficientMaterial = controller.isInsufficientMaterial();

    if (isCheckMate) {
      _gameEnded = true;
      final isWhiteTurn = controller.getFen().split(' ')[1] == 'w';
      final playerWon =
          (_myColor == PlayerColor.white && !isWhiteTurn) ||
              (_myColor == PlayerColor.black && isWhiteTurn);

      if (_isPlayingAgainstBot) {
        _recordGameResult(
          playerWon ? GameResultModel.win : GameResultModel.loss,
        );

        _interstitialHelper.showAdIfReady(onComplete: () {
          _showGameEndDialog(
            playerWon
                ? '${S.of(context).youWonCheckMate}\n${S.of(context).youWonCheckMate}'
                : '${S.of(context).cpuWonCheckMate}\n${S.of(context).youWonCheckMate}',
          );
        });
      }
    } else if (isDraw ||
        isStaleMate ||
        isThreefoldRepetition ||
        isInsufficientMaterial) {
      _gameEnded = true;
      String message =
      isDraw
          ? S.of(context).drawMsg
          : isStaleMate
          ? S.of(context).drawByStalemate
          : isThreefoldRepetition
          ? S.of(context).tieByReply
          : S.of(context).tieByInsufficient;

      if (_isPlayingAgainstBot) {
        _recordGameResult(GameResultModel.draw);

        _interstitialHelper.forceShowAd(onComplete: () {
          _showGameEndDialog(message);
        });
      }
    }
  }

  void _checkForGameEnd(String fen) {
    if (_gameEnded) return;

    bool isCheckMate = controller.isCheckMate();
    bool isDraw = controller.isDraw();
    bool isStaleMate = controller.isStaleMate();

    GameResultModel? result;
    String? winnerId;

    if (isCheckMate) {
      result = GameResultModel.win;
      winnerId = currentUser!.uid;
    } else if (isDraw || isStaleMate) {
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

    try {
      await MultiplayerGameService().finishGame(
        gameId: _currentGame!.id,
        result: result,
        winnerId: winnerId,
      );
    } catch (e) {
      print('Error finishing game: $e');
    }
  }

  void _handleGameEnd(MultiplayerGameMatch game) {
    _playerTimer?.cancel();

    String message;
    GameResultModel gameResult;
    bool opponentAbandoned = false;
    bool isTimeout = false;

    if (game.reason == 'timeout') {
      isTimeout = true;
      return;
    } else if (game.reason == 'abandoned' && game.winnerId == currentUser!.uid) {
      opponentAbandoned = true;
      message = S.of(context).opponentAbandoned;
      gameResult = GameResultModel.win;
    } else if (game.result == GameResultModel.draw) {
      message = S.of(context).drawMsg;
      gameResult = GameResultModel.draw;
    } else if (game.winnerId == currentUser!.uid) {
      message = S.of(context).youWon;
      gameResult = GameResultModel.win;
    } else {
      message = S.of(context).youLost;
      gameResult = GameResultModel.loss;
    }

    _recordGameResult(gameResult);

    _interstitialHelper.forceShowAd(onComplete: () {
      if (opponentAbandoned) {
        _showOpponentAbandonedDialog();
      } else {
        _showGameEndDialog(message);
      }
    });
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (currentUser == null || _gameStartTime == null) return;

    try {
      final gameDuration = DateTime.now().difference(_gameStartTime!).inMinutes;
      int pointsEarned = 0;

      switch (result) {
        case GameResultModel.win:
          pointsEarned = 20;
          break;
        case GameResultModel.loss:
          pointsEarned = -5;
          break;
        case GameResultModel.draw:
          pointsEarned = 8;
          break;
      }

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName:
            _opponentName ??
            (_isPlayingAgainstBot ? 'Player' : 'Jugador en línea'),
        additionalData: {
          'gameMode':
              _isPlayingAgainstBot ? 'online_bot' : 'online_matchmaking',
          'matchType': widget.matchType,
          'timeControl':
              _selectedTimeMinutes != null
                  ? '${_selectedTimeMinutes!} minutos'
                  : 'Sin límite',
          'playerColor': _myColor == PlayerColor.white ? 'white' : 'black',
          'finalFEN': controller.getFen(),
        },
      );

      if (success) {
        print('Partida registrada exitosamente');
      }
    } catch (e) {
      print('Error al registrar la partida: $e');
    }
  }

  void _cancelMatchmaking(String reason) {
    _matchmakingTimer?.cancel();
    _showErrorAndReturn(reason);
  }

  void _showErrorAndReturn(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).error),
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showGameEndDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).gameOver),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text(message, textAlign: TextAlign.center)],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context).exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _gameState = OnlineGameState.timeSelection;
                    _selectedTimeMinutes = null;
                    _currentGame = null;
                    _gameEnded = false;
                    _gameStartTime = null;
                    _isPlayingAgainstBot = false;
                    _isMyTurn = false;
                    _myColor = null;
                    _opponentName = null;
                    _opponentPhotoUrl = null;
                    _engineThinking = false;
                    controller.resetBoard();
                    _cleanupTimers();
                  });
                },
                child: Text(S.of(context).playAgain),
              ),
            ],
          ),
    );
  }

  void _showAbandonGameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).abandonGame),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 48),
                SizedBox(height: 16),
                Text(
                  S.of(context).abandonGameWarning,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  S.of(context).continueGame,
                  style: TextStyle(color: Colors.green),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _abandonGame();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(S.of(context).abandonGame),
              ),
            ],
          ),
    );
  }

  Future<void> _abandonGame() async {
    if (_gameEnded) return;
    _gameEnded = true;
    _playerTimer?.cancel();
    _cleanupTimers();

    if (_isPlayingAgainstBot) {
      _recordGameResult(GameResultModel.loss);

      _interstitialHelper.forceShowAd(onComplete: () {
        Navigator.of(context).pop();
      });
      return;
    }

    if (_currentGame != null) {
      try {
        final opponentId = _currentGame!.getOpponentId(currentUser!.uid);

        await MultiplayerGameService().finishGame(
          gameId: _currentGame!.id,
          result: GameResultModel.win,
          winnerId: opponentId,
          reason: 'abandoned',
        );
        _recordGameResult(GameResultModel.loss);
      } catch (e) {
        print('Error al abandonar la partida: $e');
        _recordGameResult(GameResultModel.loss);
      }
    }

    _interstitialHelper.forceShowAd(onComplete: () {
      Navigator.of(context).pop();
    });
  }

  void _showOpponentAbandonedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(S.of(context).opponentLeft),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).opponentAbandonedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text(
                        S.of(context).youWon,
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                child: Text(S.of(context).exit),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  backgroundColor: Colors.green[50],
                ),
                child: Text(S.of(context).findNewOpponent),
              ),
            ],
          ),
    );
  }

  void _startNewGame() {
    setState(() {
      _gameState = OnlineGameState.timeSelection;
      _selectedTimeMinutes = null;
      _currentGame = null;
      _gameEnded = false;
      _gameStartTime = null;
      _isPlayingAgainstBot = false;
      _isMyTurn = false;
      _myColor = null;
      _opponentName = null;
      _opponentPhotoUrl = null;
      _engineThinking = false;
      _myRanking = null;
      _opponentRanking = null;
      controller.resetBoard();
      _cleanupTimers();
    });
  }

  bool _onWillPop() {
    if (_gameState == OnlineGameState.playing && !_gameEnded) {
      _showAbandonGameDialog();
      return false;
    }
    if (_gameState == OnlineGameState.searching) {
      _cancelMatchmaking(S.of(context).searchCanceled);
      return false;
    }
    return true;
  }

  Widget _buildSearchingScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).searchingOpponent,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _cancelMatchmaking(S.of(context).searchCanceled);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 30),
            Text(
              '${S.of(context).searchingOpponent}...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              '${S.of(context).time}: ${_formatTime(_matchmakingSeconds)}',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (_matchmakingSeconds >= 45) SizedBox(height: 20),
            Text(
              '${S.of(context).timeSettings}: ${_getTimeDisplay()}',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _cancelMatchmaking(S.of(context).searchCanceled),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(S.of(context).cancelSearch),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        appBar: AppBar(
          backgroundColor: const ui.Color(0xFFEC7A34),
          elevation: 0,
          title: Text(
            S.of(context).onlineGame,
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              if (!_onWillPop()) {
                return;
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            _buildPlayerInfo(isMe: false),

            if (_selectedTimeMinutes != null)
              _buildTimer(_opponentTimeSeconds, isMyTimer: false),

            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ChessBoard(
                      controller: controller,
                      boardColor: BoardColor.brown,
                      boardOrientation: _myColor ?? PlayerColor.white,
                      enableUserMoves:
                          _isMyTurn && !_gameEnded && !_isProcessingMove,
                      onMove: _playerMoved,
                    ),
                  ),
                  if (_engineThinking && _isPlayingAgainstBot)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            if (_selectedTimeMinutes != null)
              _buildTimer(_myTimeSeconds, isMyTimer: true),

            _buildPlayerInfo(isMe: true),

            if (!_gameEnded)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildPlayerInfo({required bool isMe}) {
    final name = isMe
        ? (currentUser?.displayName ?? S.of(context).you)
        : (_opponentName ?? S.of(context).rivals);

    final photoUrl = isMe ? currentUser?.photoURL : _opponentPhotoUrl;
    final isPlayerTurn = isMe ? _isMyTurn : !_isMyTurn;
    final ranking = isMe ? _myRanking : _opponentRanking;

    String? botAvatar;
    if (!isMe && _isPlayingAgainstBot && _opponentName != null) {
      final botProfile = _botProfiles.firstWhere(
            (p) => p['name'] == _opponentName,
        orElse: () => _botProfiles[0],
      );
      botAvatar = botProfile['avatar'];
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPlayerTurn ? Colors.black.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isPlayerTurn ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? (_isPlayingAgainstBot && !isMe && botAvatar != null
                ? Text(botAvatar, style: TextStyle(fontSize: 24))
                : Icon(Icons.person, size: 24))
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isPlayingAgainstBot && !isMe)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    // Mostrar ranking
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRankingColor(ranking),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 12,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            ranking?.toString() ?? '---',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Estado del turno
                    if (isPlayerTurn)
                      Expanded(
                        child: Text(
                          '${S.of(context).playing}...',
                          style: TextStyle(color: Colors.green[300], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
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

  ui.Color _getRankingColor(int? ranking) {
    if (ranking == null) return Colors.grey;

    if (ranking >= 2000) return Colors.purple;
    if (ranking >= 1800) return Colors.blue;
    if (ranking >= 1600) return Colors.green;
    if (ranking >= 1400) return Colors.orange;
    if (ranking >= 1200) return Colors.yellow[700]!;
    return Colors.red;
  }




  Widget _buildTimer(int seconds, {required bool isMyTimer}) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';

    final isRunningOut = seconds <= 30;
    final isActive = isMyTimer ? _isMyTurn : !_isMyTurn;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isActive
                ? (isRunningOut ? Colors.red[700] : Colors.green[700])
                : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        timeString,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getTimeDisplay() {
    if (_selectedTimeMinutes == null) return S.of(context).outOfTime;
    return '$_selectedTimeMinutes minuto${_selectedTimeMinutes! > 1 ? 's' : ''}';
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    switch (_gameState) {
      case OnlineGameState.timeSelection:
        return _buildTimeSelectionScreen();
      case OnlineGameState.searching:
        return _buildSearchingScreen();
      case OnlineGameState.playing:
        return _buildGameScreen();
    }
  }
}

enum OnlineGameState { timeSelection, searching, playing }

class TimeOption {
  final int? minutes;
  final String display;

  TimeOption({required this.minutes, required this.display});
}
