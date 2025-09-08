import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/multiplayer_game_match_chess.dart';
import '../../core/service/auth_service.dart';
import '../../core/service/online_match_chess_game_service.dart';
import '../../generated/l10n.dart';
import '../../core/utils/game_result.dart';
import '../../core/utils/game_type.dart';

class OnlineChessScreen extends StatefulWidget {
  const OnlineChessScreen({super.key});

  @override
  State<OnlineChessScreen> createState() => _OnlineChessScreenState();
}

class _OnlineChessScreenState extends State<OnlineChessScreen>
    with WidgetsBindingObserver {
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _lastMovePromotion;
  // Estados principales
  OnlineGameState _gameState = OnlineGameState.timeSelection;

  // Configuración de tiempo
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
  bool _isMyTurn = false;
  PlayerColor? _myColor;
  String? _opponentName;
  String? _opponentPhotoUrl;
  bool _gameEnded = false;
  bool _isProcessingMove = false;

  int _myTimeSeconds = 0;
  int _opponentTimeSeconds = 0;
  Timer? _playerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupTimers();
    _gameSubscription?.cancel();
    super.dispose();
  }

  void _cleanupTimers() {
    _matchmakingTimer?.cancel();
    _gameTimer?.cancel();
    _playerTimer?.cancel();
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

    final gameId = await _findOrCreateGame(userRanking);

    if (gameId != null) {
      _startGameSubscription(gameId);
    } else {
      _showErrorAndReturn(S.of(context).errorSearchGame);
    }

    _matchmakingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _matchmakingSeconds++);
      if (_matchmakingSeconds >= 60) {
        _cancelMatchmaking(S.of(context).opponentNotFound);
      }
    });
  }

  Future<int> _getUserRanking() async {
    final gameStats = await AuthService().getCurrentUserGameStats(
      GameTypeModel.chess,
    );
    return gameStats?.points ?? 1000;
  }

  Future<String?> _findOrCreateGame(int userRanking) async {
    try {
      final waitingGames = await OnlineMatchmakingChessService().findWaitingGames(
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
        // Crear nuevo juego
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

    final wasMyTurn = _isMyTurn;
    _isMyTurn = game.isPlayerTurn(currentUser!.uid);

    if (_isMyTurn && !_isProcessingMove) {
    }

    bool shouldSync = false;

    if (previousGame == null) {
      shouldSync = true;
    } else if (!_isProcessingMove &&
        previousGame.currentFen != game.currentFen) {
      shouldSync = true;
      print(
        'FEN changed from opponent: ${previousGame.currentFen} -> ${game.currentFen}',
      );
    }

    if (shouldSync && !_isProcessingMove) {
      _syncGameState();
    }

    if (!_gameEnded && game.isFinished) {
      _gameEnded = true;
      _handleGameEnd(game);
    }


    if (wasMyTurn != _isMyTurn) {
      print(
        'Turn changed: ${wasMyTurn ? "My turn" : "Opponent turn"} -> ${_isMyTurn ? "My turn" : "Opponent turn"}',
      );
      if (_isMyTurn) {
      }
    }

    setState(() {});
  }

  void _setupGame(MultiplayerGameMatch game) {
    final isHost = game.hostId == currentUser!.uid;
    _myColor = isHost ? PlayerColor.white : PlayerColor.black;
    _opponentName = game.getOpponentName(currentUser!.uid);
    _opponentPhotoUrl = isHost ? game.guestPhotoUrl : game.hostPhotoUrl;
    controller.loadFen(game.currentFen);
    if (_selectedTimeMinutes != null) {
      _myTimeSeconds = _selectedTimeMinutes! * 60;
      _opponentTimeSeconds = _selectedTimeMinutes! * 60;
      _startPlayerTimer();
    }
    print(
      'Game setup complete. My color: $_myColor, Initial FEN: ${game.currentFen}',
    );
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

    final result = isMyTimeout ? GameResultModel.loss : GameResultModel.win;
    final winnerId =
        isMyTimeout
            ? _currentGame!.getOpponentId(currentUser!.uid)
            : currentUser!.uid;

    MultiplayerGameService().finishGame(
      gameId: _currentGame!.id,
      result: result,
      winnerId: winnerId,
    );
  }

  void _syncGameState() {
    if (_currentGame == null || _isProcessingMove) return;

    try {
      final currentFen = controller.getFen();
      final targetFen = _currentGame!.currentFen;

      if (currentFen != targetFen) {
        print('Syncing board: $currentFen -> $targetFen');
        controller.loadFen(targetFen);

        if (_isMyTurn) {
        }
      }
    } catch (e) {
      print('Error syncing game state: $e');
    }
  }

  void _playerMoved({String? from, String? to, String? promotion}) async {
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

      print('Making move: $moveFrom -> $moveTo (promotion: $movePromotion)');
      print('New FEN: $newFen');

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
    if (game.result == GameResultModel.draw) {
      message = S.of(context).drawMsg;
    } else if (game.winnerId == currentUser!.uid) {
      message = S.of(context).youWon;
    } else {
      message = S.of(context).youLost;
    }

    _showGameEndDialog(message);
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
            content: Text(message, textAlign: TextAlign.center),
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
                    _cleanupTimers();
                  });
                },
                child: Text(S.of(context).playAgain),
              ),
            ],
          ),
    );
  }

  Widget _buildSearchingScreen() {
    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(S.of(context).searchingOpponent, style: TextStyle(color: Colors.white)),
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
            SizedBox(height: 20),
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
    if (_currentGame == null) {
      return Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(S.of(context).onlineGame, style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildPlayerInfo(isMe: false),

          if (_selectedTimeMinutes != null)
            _buildTimer(_opponentTimeSeconds, isMyTimer: false),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ChessBoard(
                controller: controller,
                boardColor: BoardColor.brown,
                boardOrientation: _myColor ?? PlayerColor.white,
                enableUserMoves: _isMyTurn && !_gameEnded && !_isProcessingMove,
                onMove: _playerMoved,
              ),
            ),
          ),

          if (_selectedTimeMinutes != null)
            _buildTimer(_myTimeSeconds, isMyTimer: true),

          _buildPlayerInfo(isMe: true),

          // Estado del turno
          if (!_gameEnded)
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _isMyTurn ? S.of(context).yourTurn : S.of(context).opponentTurn,
                style: TextStyle(
                  color: _isMyTurn ? Colors.green[300] : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo({required bool isMe}) {
    if (_currentGame == null) return SizedBox();

    final name =
        isMe
            ? (currentUser?.displayName ?? S.of(context).you)
            : (_opponentName ?? S.of(context).rivals);

    final photoUrl = isMe ? currentUser?.photoURL : _opponentPhotoUrl;
    final isPlayerTurn = isMe ? _isMyTurn : !_isMyTurn;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isPlayerTurn
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isPlayerTurn ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Icon(Icons.person, size: 24) : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isPlayerTurn)
                  Text(
                    '${S.of(context).playing}...',
                    style: TextStyle(color: Colors.green[300], fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
                : Colors.black.withValues(alpha: 0.3),
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


