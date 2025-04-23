import 'package:flutter/material.dart';
import '../../widgets/avatar.dart';
import '../games/game_selection.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TekoPlay'),
        actions: [
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          IconButton(icon: Icon(Icons.settings), onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SettingsScreen()),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          UserAvatarWidget(userName: 'Usuario123',),
          Row(
            children: [
              Text('Monedas: 100'),
              Text('Diamantes: 50'),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return GameSelectionPopup();
                },
              );
            },
            child: Text('Seleccionar Juego'),
          ),
        ],
      ),
    );
  }
}
