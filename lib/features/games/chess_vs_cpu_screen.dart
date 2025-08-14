import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_stockfish_plugin/stockfish.dart';

class ChessVsComputerScreen extends StatefulWidget {
  const ChessVsComputerScreen({Key? key}) : super(key: key);

  @override
  State<ChessVsComputerScreen> createState() => _ChessVsComputerScreenState();
}

class _ChessVsComputerScreenState extends State<ChessVsComputerScreen> {
  late Stockfish _stockfish;
  ChessBoardController controller = ChessBoardController();

  int playerScore = 0;
  int cpuScore = 0;

  bool _isStockfishReady = false;

  @override
  void initState() {
    super.initState();
    _stockfish = Stockfish();

    // Escucha la salida de Stockfish
    _stockfish.stdout.listen((output) {
      if (output.startsWith("bestmove")) {
        final move = output.split(" ")[1];
        controller.makeMoveWithNormalNotation(move);
      }
    });

    // Inicializa Stockfish con retardo
    Future.delayed(Duration(milliseconds: 1500), () {
      _stockfish.stdin = "uci";
      Future.delayed(Duration(milliseconds: 500), () {
        _stockfish.stdin = "isready";
      });
    });
  }

  void playerMoved() {
    final fen = controller.getFen();
    _stockfish.stdin = "position fen $fen";
    _stockfish.stdin = "go depth 15";
  }

  @override
  void dispose() {
    _stockfish.stdin = "quit";
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
                      SizedBox(height: 6),
                      Text(
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
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text('Marcador', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Column(
                    children: [
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
            // Tablero
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChessBoard(
                  controller: controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: PlayerColor.white,
                  enableUserMoves: true,
                  onMove: playerMoved,
                ),
              ),
            ),
            // Botón reiniciar
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: () => controller.resetBoard(),
                icon: Icon(Icons.replay),
                label: Text('Reiniciar partida'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
