

import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/models/DominoTile.dart';
import 'DominoBoard.dart';


class DominoGameScreen extends StatefulWidget {
  const DominoGameScreen({Key? key}) : super(key: key);

  @override
  State<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends State<DominoGameScreen> {
  final DominoBoard board = DominoBoard();
  final List<DominoTile> playerHand = [];
  final List<DominoTile> cpuHand = [];

  bool playerTurn = true;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    final allTiles = <DominoTile>[];

    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        allTiles.add(DominoTile(i, j));
      }
    }

    allTiles.shuffle();
    playerHand.clear();
    cpuHand.clear();
    board.tiles.clear();

    playerHand.addAll(allTiles.sublist(0, 7));
    cpuHand.addAll(allTiles.sublist(7, 14));

    playerTurn = true;
    setState(() {});
  }

  void _playerPlayTile(DominoTile tile) {
    if (!board.canPlay(tile)) return;

    setState(() {
      playerHand.remove(tile);
      board.playTile(tile);
      playerTurn = false;
    });

    Future.delayed(const Duration(milliseconds: 800), _cpuTurn);
  }

  void _cpuTurn() {
    if (playerTurn) return;
    final possibleMoves = cpuHand.where((tile) => board.canPlay(tile)).toList();

    if (possibleMoves.isNotEmpty) {
      final move = possibleMoves[Random().nextInt(possibleMoves.length)];
      setState(() {
        cpuHand.remove(move);
        board.playTile(move);
        playerTurn = true;
      });
    } else {
      setState(() {
        playerTurn = true;
      });
    }
  }

  Widget _buildTile(DominoTile tile, {bool clickable = false}) {
    return GestureDetector(
      onTap: clickable && playerTurn && board.canPlay(tile)
          ? () => _playerPlayTile(tile)
          : null,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: clickable ? Colors.orange : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          tile.toString(),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: board.tiles
          .map((tile) => _buildTile(tile))
          .toList(growable: false),
    );
  }

  Widget _buildPlayerHand() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: playerHand
          .map((tile) => _buildTile(tile, clickable: true))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameOver = playerHand.isEmpty || cpuHand.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dominó vs CPU"),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startGame,
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text("Tablero", style: TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          Expanded(child: SingleChildScrollView(child: _buildBoard())),
          const Divider(),
          const Text("Tu mano", style: TextStyle(fontSize: 18)),
          _buildPlayerHand(),
          const SizedBox(height: 20),
          if (gameOver)
            Text(
              playerHand.isEmpty ? "¡Ganaste!" : "La CPU ganó",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
