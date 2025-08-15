import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';
import 'package:flutter_stockfish_plugin/stockfish_state.dart';

class ChessVsComputerScreen extends StatefulWidget {
  final String selectedDifficulty;

  const ChessVsComputerScreen(this.selectedDifficulty, {super.key});

  @override
  State<ChessVsComputerScreen> createState() => _ChessVsComputerScreenState();
}

class _ChessVsComputerScreenState extends State<ChessVsComputerScreen> {
  late Stockfish _stockfish;
  ChessBoardController controller = ChessBoardController();

  int playerScore = 0;
  int cpuScore = 0;

  bool _isStockfishReady = false;
  bool _engineThinking = false;

  late int _cpuMoveTime;

  PlayerColor? _playerColor;

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
  }

  Future<void> _initializeStockfish() async {
    _stockfish.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    _stockfish.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));

    _stockfish.stdin = "setoption name Threads value 1";
    _stockfish.stdin = "setoption name Hash value 32";
  }

  void _makeCpuMove() {
    if (!_isStockfishReady) return;

    final fen = controller.getFen();
    _stockfish.stdin = "position fen $fen";
    _stockfish.stdin = "go movetime $_cpuMoveTime";
  }

  void playerMoved() {
    if (!_isStockfishReady) return;

    final fen = controller.getFen();
    _stockfish.stdin = "position fen $fen";
    _stockfish.stdin = "go movetime $_cpuMoveTime";
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
      if (_playerColor == PlayerColor.black && _isStockfishReady) {
        _makeCpuMove();
      }
    });
  }

  @override
  void dispose() {
    if (_isStockfishReady) _stockfish.stdin = "quit";
    _stockfish.dispose();
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
              const Text(
                'Selecciona tu color',
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
                        const Text(
                          'Blancas',
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
                        const Text(
                          'Negras',
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
        title: const Text(
          'Jugador vs CPU',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Avatares y marcador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            _playerColor == PlayerColor.white
                                ? Colors.white
                                : Colors.black,
                        child:
                            _playerColor == PlayerColor.white
                                ? null
                                : const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tú',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                      const Text(
                        'Marcador',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            _playerColor == PlayerColor.white
                                ? Colors.black
                                : Colors.white,
                        child:
                            _playerColor == PlayerColor.white
                                ? const Icon(
                                  Icons.smart_toy,
                                  color: Colors.white,
                                )
                                : const Icon(
                                  Icons.smart_toy,
                                  color: Colors.black,
                                ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'CPU',
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
                      enableUserMoves: true,
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
                onPressed: () {
                  controller.resetBoard();
                  if (_isStockfishReady) {
                    final fen = controller.getFen();
                    _stockfish.stdin = "position fen $fen";

                    if (_playerColor == PlayerColor.black) _makeCpuMove();
                  }
                  _engineThinking = false;
                  setState(() {});
                },
                icon: const Icon(Icons.replay),
                label: const Text('Reiniciar partida'),
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
          ],
        ),
      ),
    );
  }
}
