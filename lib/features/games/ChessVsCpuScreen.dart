import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';

class ChessVsCpuScreen extends StatefulWidget {
  const ChessVsCpuScreen({super.key});

  @override
  _ChessVsCpuScreenState createState() => _ChessVsCpuScreenState();
}

class _ChessVsCpuScreenState extends State<ChessVsCpuScreen> {
  late ChessBoardController _controller;
  late Stockfish _engine;
  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _controller = ChessBoardController();
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    _engine = Stockfish();

    _engine.onResponse.listen((event) {
      if (event == 'readyok') {
        setState(() {
          _isEngineReady = true;
        });
      }

      if (event.startsWith('bestmove')) {
        final move = event.split(' ')[1];
        if (move == '(none)') {
          _showEndDialog("¡Fin del juego! Sin movimientos posibles.");
          return;
        }

        setState(() {
          _controller.makeMove(move);
        });
      }
    });

    _engine.sendCommand('uci');
    await Future.delayed(const Duration(milliseconds: 300));
    _engine.sendCommand('isready');
  }

  void _onPlayerMove(String move) {
    final fen = _controller.getFen();
    if (_isEngineReady) {
      _engine.sendCommand('position fen $fen');
      _engine.sendCommand('go movetime 1000');
    }
  }

  void _showEndDialog(String result) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Juego terminado"),
        content: Text(result),
        actions: [
          TextButton(
            child: const Text("Reiniciar"),
            onPressed: () {
              Navigator.pop(context);
              _controller.resetBoard();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _engine.sendCommand('quit');
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajedrez vs CPU'),
        backgroundColor: const Color(0xFFEC7A34),
      ),
      body: Column(
        children: [
          Expanded(
            child: ChessBoard(
              controller: _controller,
              boardColor: BoardColor.brown,
              boardOrientation: PlayerColor.white,
              enableUserMoves: true,
              onMove: (move) => _onPlayerMove(move),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _controller.resetBoard();
                });
                _engine.sendCommand('ucinewgame');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reiniciar Juego'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC7A34),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
