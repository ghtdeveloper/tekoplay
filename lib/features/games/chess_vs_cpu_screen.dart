import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_chess_board/flutter_chess_board.dart';

import '../../core/services/stockfish_service.dart';

class ChessVsComputerScreen extends StatefulWidget {
  const ChessVsComputerScreen({Key? key}) : super(key: key);

  @override
  State<ChessVsComputerScreen> createState() => _ChessVsComputerScreenState();
}

class _ChessVsComputerScreenState extends State<ChessVsComputerScreen> {
  late StockfishService stockfish;
  ChessBoardController controller = ChessBoardController();

  int playerScore = 0;
  int cpuScore = 0;

  @override
  void initState() {
    super.initState();
    stockfish = StockfishService();
    stockfish.startEngine().then((_) {
      stockfish.sendCommand("uci");
      stockfish.sendCommand("isready");
    });

    stockfish.output.listen((output) {
      if (output.contains("bestmove")) {
        final move = output.split("bestmove ")[1].split(" ")[0];
        controller.makeMoveWithNormalNotation(move);
        // Aquí podrías actualizar marcador en el futuro
      }
    });
  }

  void playerMoved() {
    final fen = controller.getFen();
    stockfish.sendCommand("position fen $fen");
    stockfish.sendCommand("go depth 15");
  }

  @override
  void dispose() {
    stockfish.dispose();
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
            // 🧑 VS 🤖 Avatares y marcador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: AssetImage('assets/images/img_perfil_unknown.png'),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tú',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '$playerScore - $cpuScore',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Marcador',
                        style: TextStyle(color: Colors.white70),
                      ),
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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ♟️ Tablero de ajedrez
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ChessBoard(
                  controller: controller,
                  boardColor: BoardColor.brown,
                  boardOrientation: PlayerColor.white,
                  enableUserMoves: true,
                  onMove: playerMoved,
                ),
              ),
            ),

            // 🔁 Botón de reiniciar
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  controller.resetBoard();
                },
                icon: Icon(Icons.replay),
                label: Text('Reiniciar partida'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  //foregroundColor: const Color(0xFFEC7A34),
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
