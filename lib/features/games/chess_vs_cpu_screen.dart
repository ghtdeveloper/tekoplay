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

  // Variables para dificultad
  late int _cpuMoveTime; // ms
  late int _cpuDepth; // profundidad

  @override
  void initState() {
    super.initState();

    switch (widget.selectedDifficulty.toLowerCase()) {
      case 'muy fácil':
        _cpuMoveTime = 200;
        _cpuDepth = 5;
        break;
      case 'fácil':
        _cpuMoveTime = 400;
        _cpuDepth = 8;
        break;
      case 'normal':
        _cpuMoveTime = 800;
        _cpuDepth = 12;
        break;
      case 'difícil':
        _cpuMoveTime = 1500;
        _cpuDepth = 15;
        break;
      default:
        _cpuMoveTime = 500;
        _cpuDepth = 10;
    }

    _stockfish = Stockfish();

    _stockfish.stdout.listen((output) {
      debugPrint('[SF] $output');

      if (output.contains('bestmove ')) {
        final parts = output.split(' ');
        if (parts.length >= 2) {
          final best = parts[1];
          _engineThinking = false;

          if (best == '0000' || best == '(none)') {
            debugPrint('Sin jugada disponible (mate o tablas)');
            return;
          }

          // Aplicar movimiento del CPU
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyUciMoveToBoard(best);
          });

          setState(() {}); // Actualizar UI para quitar indicador
        }
      }
    });

    // Espera a que Stockfish esté listo
    _stockfish.state.addListener(() async {
      if (_stockfish.state.value == StockfishState.ready &&
          !_isStockfishReady) {
        _isStockfishReady = true;
        await _initializeStockfish();
      }
    });
  }

  Future<void> _initializeStockfish() async {
    _stockfish.stdin = "uci";
    await Future.delayed(const Duration(milliseconds: 300));
    _stockfish.stdin = "isready";
    await Future.delayed(const Duration(milliseconds: 300));

    // Opciones para optimizar velocidad
    _stockfish.stdin = "setoption name Threads value 1";
    _stockfish.stdin = "setoption name Hash value 32"; // 32MB
  }

  void playerMoved() async {
    if (!_isStockfishReady || _engineThinking) return;

    _engineThinking = true;
    setState(() {});

    final fen = controller.getFen();
    debugPrint("Jugador movió, FEN: $fen");

    _stockfish.stdin = "position fen $fen";

    // CPU hace su jugada según dificultad
    _stockfish.stdin = "go depth $_cpuDepth movetime $_cpuMoveTime";
  }

  void _applyUciMoveToBoard(String uci) {
    debugPrint("CPU mueve: $uci");

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
      return;
    }

    debugPrint('Movimiento UCI no reconocido: $uci');
  }

  @override
  void dispose() {
    if (_isStockfishReady) {
      _stockfish.stdin = "quit";
    }
    _stockfish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        backgroundImage: AssetImage(
                          'assets/images/img_perfil_unknown.png',
                        ),
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
                    children: const [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.smart_toy, color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
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
            // Tablero con indicador de CPU pensando
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ChessBoard(
                      controller: controller,
                      boardColor: BoardColor.brown,
                      boardOrientation: PlayerColor.white,
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
            // Botón reiniciar
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.resetBoard();
                  if (_isStockfishReady) {
                    final fen = controller.getFen();
                    _stockfish.stdin = "position fen $fen";
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
