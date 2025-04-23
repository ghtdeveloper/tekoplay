import 'package:flutter/material.dart';

import '../../widgets/chess_game_widget.dart';
import '../../widgets/domino_game_widget.dart';

class GameScreen extends StatelessWidget {
  final String gameType;

  const GameScreen({super.key, required this.gameType});

  @override
  Widget build(BuildContext context) {
    Widget gameWidget;

    switch (gameType.toLowerCase()) {
      case 'ajedrez':
        gameWidget = ChessGameWidget();
        break;
      case 'dominó':
        gameWidget = DominoGameWidget();
        break;
      default:
        gameWidget = Center(child: Text('Juego no disponible'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Jugando: $gameType'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SafeArea(
        child: gameWidget,
      ),
    );
  }
}
