import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    stockfish = StockfishService();
    stockfish.startEngine().then((_) {
      stockfish.sendCommand("uci");
      stockfish.sendCommand("isready");
    });

    stockfish.output.listen((output) {
      print("Stockfish Output: $output");
      if (output.contains("bestmove")) {
        final move = output.split("bestmove ")[1].split(" ")[0];
        controller.makeMoveWithNormalNotation(move);
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
      appBar: AppBar(title: Text("Juega contra la IA")),
      body: Column(
        children: [
          ChessBoard(
            controller: controller,
            boardColor: BoardColor.orange,
            boardOrientation: PlayerColor.white,
            enableUserMoves: true,
            onMove: () {
              playerMoved();
            },
          ),
          ElevatedButton(
            onPressed: () => controller.resetBoard(),
            child: Text("Reiniciar"),
          ),
        ],
      ),
    );
  }
}
