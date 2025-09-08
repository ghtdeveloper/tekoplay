import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/multiplayer_game_match_chess.dart';
import '../../core/service/firestore_service.dart';
import '../../core/utils/game_type.dart';
import '../../generated/l10n.dart';
import '../../core/utils/game_result.dart';

class MultiplayerChessScreen extends StatefulWidget {
  final String gameId;
  final bool isHost;

  const MultiplayerChessScreen({
    super.key,
    required this.gameId,
    this.isHost = false,
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
  bool _isMyTurn = false;
  Timer? _reconnectTimer;
  bool _isConnected = true;
  bool _isProcessingMove = false;
  DateTime? _gameStartTime;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  MultiplayerGameService get _gameService => MultiplayerGameService();
  final FirestoreService _firestoreService = FirestoreService();

  PlayerColor? _myColor;
  String? _opponentName;
  String? _opponentPhotoUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameStartTime = DateTime.now();
    _initializeGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _handleAppPause();
    } else if (state == AppLifecycleState.resumed) {
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
    if (currentUser == null) {
      _showErrorAndExit(S.of(context).userNotFound);
      return;
    }

    _gameSubscription = _gameService
        .getGameStream(widget.gameId)
        .listen(
          (game) {
            if (game == null) {
              _showErrorAndExit(S.of(context).gameNotFound);
              return;
            }

            _handleGameUpdate(game);
          },
          onError: (error) {
            print('Error in game stream: $error');
            setState(() => _isConnected = false);
            _startReconnectTimer();
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
    }

    _isMyTurn = game.isPlayerTurn(currentUser!.uid);

    bool shouldSync = false;

    if (previousGame == null) {
      shouldSync = true;
    } else {
      if (previousGame.moves.length != game.moves.length) {
        shouldSync = true;
      } else if (previousGame.currentFen != game.currentFen) {
        shouldSync = true;
      }
    }

    if (shouldSync) {
      _syncGameState();
    }

    if (!_gameEnded && game.isFinished) {
      _gameEnded = true;
      _handleGameEnd(game);
    }

    if (game.status == 'waiting' && previousGame?.status == 'active') {
      _showOpponentDisconnected();
    }

    setState(() {});
  }

  void _setupGameInfo(MultiplayerGameMatch game) {
    final isHost = game.hostId == currentUser!.uid;
    _myColor = isHost ? PlayerColor.white : PlayerColor.black;

    _opponentName = game.getOpponentName(currentUser!.uid);
    _opponentPhotoUrl = isHost ? game.guestPhotoUrl : game.hostPhotoUrl;
  }

  void _syncGameState() {
    if (_currentGame == null) return;
    try {
      if (controller.getFen() != _currentGame!.currentFen) {
        controller.loadFen(_currentGame!.currentFen);
      }
    } catch (e) {
      print('Error syncing game state: $e');
      print('Could not sync with FEN, keeping current board state');
    }
  }

  void _playerMoved() async {
    if (!_isMyTurn || _gameEnded || _isProcessingMove || _currentGame == null) {
      return;
    }
    _isProcessingMove = true;

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
      if (!success) {
        print('Failed to send move to server, reverting...');
        _syncGameState();
        _showError('Error al enviar movimiento. Inténtalo de nuevo.');
      } else {
        print('Move sent successfully to server');
        _checkForGameEnd(newFen);
      }
    } catch (e) {
      print('Error in _playerMoved: $e');
      _syncGameState();
      _showError('Error al realizar movimiento');
    } finally {
      _isProcessingMove = false;
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
    try {
      await _gameService.finishGame(
        gameId: widget.gameId,
        result: result,
        winnerId: winnerId,
      );
    } catch (e) {
      print('Error finishing game: $e');
    }
  }

  void _handleGameEnd(MultiplayerGameMatch game) {
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
    _recordGameResult(gameResult);
    _showGameEndDialog(message);
  }

  Future<void> _recordGameResult(GameResultModel result) async {
    if (currentUser == null) {
      print('Usuario no autenticado, no se registrará la partida');
      return;
    }

    if (_gameStartTime == null) {
      print('Tiempo de juego no válido, no se registrará la partida');
      return;
    }

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

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: _opponentName ?? 'Jugador desconocido',
        additionalData: {
          'gameMode': 'multiplayer',
          'isRanked': _currentGame?.isRanked ?? false,
          'betAmount': _currentGame?.betAmount,
          'playerColor': _myColor == PlayerColor.white ? 'white' : 'black',
          'opponentId': _currentGame?.hostId == currentUser!.uid
              ? _currentGame?.guestId
              : _currentGame?.hostId,
          'gameId': widget.gameId,
          'finalFEN': controller.getFen(),
          'totalMoves': _currentGame?.moves.length ?? 0,
        },
      );

      if (success) {
        print('Partida multijugador registrada exitosamente');
      } else {
        print('Error al registrar la partida en Firestore');
      }
    } catch (e) {
      print('Error al registrar la partida: $e');
      if (mounted && currentUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el resultado de la partida'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showGameEndDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            S.of(context).gameOver,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange[600],
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
                child: Text(S.of(context).exit),
              ),
            ),
          ],
        );
      },
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
        duration: Duration(seconds: 3),
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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
            isPlayerTurn ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isPlayerTurn ? Border.all(color: Colors.green, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Icon(Icons.person, size: 20) : null,
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isPlayerTurn)
                Text(
                  S.of(context).yourTurn,
                  style: TextStyle(color: Colors.green[300], fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
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
          Text(
            '${S.of(context).movement}: ${_currentGame!.moves.length}',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
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
          if (_currentGame!.betAmount != null)
            Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  '${_currentGame!.betAmount}',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameSubscription?.cancel();
    _reconnectTimer?.cancel();
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
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final cancelled = await _gameService.cancelGame(
                    widget.gameId,
                    currentUser!.uid,
                  );
                  if (cancelled) {
                    Navigator.of(context).pop();
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

    return Scaffold(
      backgroundColor: const ui.Color(0xFFEC7A34),
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFEC7A34),
        elevation: 0,
        title: Text(
          S.of(context).multiplayer,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _buildPlayerInfo(false),
          ),

          _buildGameInfo(),

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _buildPlayerInfo(true),
          ),

          if (!_gameEnded)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
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
}
