import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';
import 'package:flutter_stockfish_plugin/stockfish_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/service/firestore_service.dart';
import '../../generated/l10n.dart';
import '../../core/utils/game_type.dart';
import '../../core/utils/game_result.dart';
import '../adds/BannerAdWidget.dart';
import '../adds/InterstitialAdHelper.dart';

class ChessVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;

  const ChessVsComputerScreen(this.selectedDifficulty, {super.key});

  @override
  State<ChessVsComputerScreen> createState() => _ChessVsComputerScreenState();
}

class _ChessVsComputerScreenState extends State<ChessVsComputerScreen> {
  late Stockfish _stockfish;
  ChessBoardController controller = ChessBoardController();
  late InterstitialAdHelper _interstitialHelper;

  int playerScore = 0;
  int cpuScore = 0;

  bool _isStockfishReady = false;
  bool _engineThinking = false;
  bool _gameEnded = false;

  late int _cpuMoveTime;
  DateTime? _gameStartTime;
  int? _userCoins;
  PlayerColor? _playerColor;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

    switch (widget.selectedDifficulty.toLowerCase()) {
      case 'muy fácil':
        _cpuMoveTime = 100;
        break;
      case 'fácil':
        _cpuMoveTime = 150;
        break;
      case 'normal':
        _cpuMoveTime = 250;
        break;
      case 'difícil':
        _cpuMoveTime = 350;
        break;
      default:
        _cpuMoveTime = 200;
    }

    _stockfish = Stockfish();

    _stockfish.stdout.listen((output) {
      if (output.contains('bestmove ')) {
        final parts = output.split(' ');
        if (parts.length >= 2) {
          final best = parts[1];
          _engineThinking = false;

          if (best == '0000' || best == '(none)') return;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyUciMoveToBoard(best);
            _checkGameEnd();
          });

          setState(() {});
        }
      }
    });

    _stockfish.state.addListener(() async {
      if (_stockfish.state.value == StockfishState.ready &&
          !_isStockfishReady) {
        _isStockfishReady = true;
        await _initializeStockfish();

        if (_playerColor == PlayerColor.black) _makeCpuMove();
      }
    });
    _interstitialHelper = InterstitialAdHelper(showFrequency: 3);
  }



  Future<void> _initializeStockfish() async {
    _stockfish.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    _stockfish.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));

    _stockfish.stdin = "setoption name Threads value 1";
    _stockfish.stdin = "setoption name Hash value 32";
  }

  Future<void> _updateUserDiamonds(int change) async {
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'coins': FieldValue.increment(change)});
      setState(() {
        _userCoins = (_userCoins ?? 0) + change;
      });
    } catch (e) {
      print('Error actualizando diamantes: $e');
    }
  }

  void _makeCpuMove() {
    if (!_isStockfishReady || _gameEnded) return;

    _engineThinking = true;
    setState(() {});

    final fen = controller.getFen();
    _stockfish.stdin = "position fen $fen";
    _stockfish.stdin = "go movetime $_cpuMoveTime";
  }

  void playerMoved() {
    if (!_isStockfishReady || _gameEnded) return;

    _gameStartTime ??= DateTime.now();

    _checkGameEnd();

    if (!_gameEnded) {
      _makeCpuMove();
    }
  }

  void _checkGameEnd() {
    bool isCheckMate = controller.isCheckMate();
    bool isCheck = controller.isInCheck();

    if (isCheckMate) {
      _gameEnded = true;

      final isWhiteTurn = controller.getFen().split(' ')[1] == 'w';
      final playerWon = (_playerColor == PlayerColor.white && !isWhiteTurn) ||
          (_playerColor == PlayerColor.black && isWhiteTurn);

      if (playerWon) {
        playerScore++;
        _showGameEndDialog(
            '${S.of(context).youWonCheckMate}\n¡Jaque Mate!'
        );
        _recordGameResult(GameResultModel.win);
      } else {
        cpuScore++;
        _showGameEndDialog(
            '${S.of(context).cpuWonCheckMate}\n¡Jaque Mate!'
        );
        _recordGameResult(GameResultModel.loss);
      }

      setState(() {});
    } else if (controller.isDraw()) {
      _gameEnded = true;
      _showGameEndDialog(S.of(context).drawMsg);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isStaleMate()) {
      _gameEnded = true;
      _showGameEndDialog(S.of(context).drawByStalemate);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isThreefoldRepetition()) {
      _gameEnded = true;
      _showGameEndDialog(S.of(context).tieByReply);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (controller.isInsufficientMaterial()) {
      _gameEnded = true;
      _showGameEndDialog(S.of(context).tieByInsufficient);
      _recordGameResult(GameResultModel.draw);
      setState(() {});
    } else if (isCheck) {
      // Mostrar mensaje temporal de jaque
      _showCheckMessage();
    }
  }

  void _showCheckMessage() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Jaque!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
          pointsEarned = 10;
          break;
        case GameResultModel.loss:
          pointsEarned = -10;
          break;
        case GameResultModel.draw:
          pointsEarned = 5;
          break;
      }

      final success = await _firestoreService.recordGameMatch(
        userId: currentUser!.uid,
        gameType: GameTypeModel.chess,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: gameDuration > 0 ? gameDuration : 1,
        opponentName: 'CPU (${widget.selectedDifficulty})',
        additionalData: {
          'difficulty': widget.selectedDifficulty,
          'playerColor': _playerColor == PlayerColor.white ? 'white' : 'black',
          'finalFEN': controller.getFen(),
        },
      );

      if (success) {
        print('Partida registrada exitosamente');
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
                _restartGame();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(S.of(context).newGame),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[600],
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
        );
      },
    );
  }

  void _applyUciMoveToBoard(String uci) {
    if (uci.length == 4) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      controller.makeMove(from: from, to: to);
      return;
    }

    if (uci.length == 5) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.substring(4).toUpperCase();
      controller.makeMoveWithPromotion(
        from: from,
        to: to,
        pieceToPromoteTo: promo,
      );
    }
  }

  void _selectPlayerColor(PlayerColor color) {
    setState(() {
      _playerColor = color;
      _gameStartTime = DateTime.now();
      if (_playerColor == PlayerColor.black && _isStockfishReady) {
        _makeCpuMove();
      }
    });
  }

  void _restartGame() {
    _interstitialHelper.showAdIfReady(onComplete: () {
      _gameEnded = false;
      _engineThinking = false;
      _gameStartTime = DateTime.now();
      controller.resetBoard();

      if (_isStockfishReady) {
        final fen = controller.getFen();
        _stockfish.stdin = "position fen $fen";

        if (_playerColor == PlayerColor.black) {
          _makeCpuMove();
        }
      }
      setState(() {});
    });
  }

  Widget _buildPlayerAvatar() {
    if (currentUser?.photoURL != null) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(currentUser!.photoURL!),
        onBackgroundImageError: (exception, stackTrace) {
        },
      );
    } else {
      return CircleAvatar(
        radius: 30,
        backgroundColor: _playerColor == PlayerColor.white ? Colors.white : Colors.black,
        child: Icon(
          Icons.person,
          color: _playerColor == PlayerColor.white ? Colors.black : Colors.white,
          size: 30,
        ),
      );
    }
  }

  Widget _buildCpuAvatar() {
    return CircleAvatar(
      radius: 30,
      backgroundColor: _playerColor == PlayerColor.white ? Colors.black : Colors.white,
      child: Icon(
        Icons.smart_toy,
        color: _playerColor == PlayerColor.white ? Colors.white : Colors.black,
        size: 30,
      ),
    );
  }

  @override
  void dispose() {
    if (_isStockfishReady) _stockfish.stdin = "quit";
    _stockfish.dispose();
    _interstitialHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playerColor == null) {
      return Scaffold(
        backgroundColor: const ui.Color(0xFFEC7A34),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                S.of(context).changeColor,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _selectPlayerColor(PlayerColor.white),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 40, backgroundColor: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).whites,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),
                  GestureDetector(
                    onTap: () => _selectPlayerColor(PlayerColor.black),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 40, backgroundColor: Colors.black),
                        const SizedBox(height: 8),
                        Text(
                          S.of(context).blacks,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
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
          S.of(context).playerVsCpu,
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      _buildPlayerAvatar(),
                      const SizedBox(height: 6),
                      Text(
                        currentUser?.displayName ?? 'Tú',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$playerScore - $cpuScore',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        S.of(context).marker,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _buildCpuAvatar(),
                      const SizedBox(height: 6),
                      Text(
                        S.of(context).cpu,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ChessBoard(
                      controller: controller,
                      boardColor: BoardColor.brown,
                      boardOrientation: _playerColor!,
                      enableUserMoves: !_gameEnded,
                      onMove: playerMoved,
                    ),
                  ),
                  if (_engineThinking)
                    Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: _restartGame,
                icon: const Icon(Icons.replay),
                label: Text(S.of(context).restartGame),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}