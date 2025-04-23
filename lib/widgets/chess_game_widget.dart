import 'package:flutter/material.dart';

class ChessGameWidget extends StatelessWidget {
  const ChessGameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Aquí va el tablero de Ajedrez',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}
