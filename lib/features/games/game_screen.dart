import 'package:flutter/material.dart';

import '../../widgets/game_mode_widget.dart';

class GameScreen extends StatelessWidget {
  final String gameType;

  const GameScreen({super.key, required this.gameType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEC7A34),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.settings, size: 30.0, color: Colors.white),
                  Row(
                    children: [
                      Text(
                        '500',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 5),
                      Image.asset('assets/images/coin.png', height: 30.0),
                    ],
                  ),
                  Icon(Icons.message, size: 30.0, color: Colors.white),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: AssetImage(
                        'assets/images/img_perfil_unknown.png',
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      gameType,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Player00000',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_vs_friend.png',
                    label: 'Vs Amigo',
                    onPressed: () {},
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_lessons.png',
                    label: 'Tutorial',
                    onPressed: () {},
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_vs_computer.png',
                    label: 'Vs CPU',
                    onPressed: () {},
                  ),
                  GameModeButton(
                    imagePath: 'assets/images/icon_play_online.png',
                    label: 'En Línea',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
