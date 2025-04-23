import 'package:flutter/material.dart';

class DominoGameWidget extends StatelessWidget {
  const DominoGameWidget({super.key});

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
