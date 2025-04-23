import 'package:flutter/material.dart';

import 'game_screen.dart';

class GameSelectionPopup extends StatelessWidget {
  const GameSelectionPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Selecciona un Juego'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GameScreen(gameType: 'Ajedrez')),
            );
          },
          child: Text('Ajedrez'),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GameScreen(gameType: 'Dominó')),
            );
          },
          child: Text('Dominó'),
        ),
      ],
    );
  }
}
