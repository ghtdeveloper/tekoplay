import 'package:flutter/material.dart';
import '../../widgets/avatar.dart';
import '../games/game_selection.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFEC7A34),
      appBar: AppBar(
        title: Text('TekoPlay',style: TextStyle(color: Colors.white),),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Color(0xFFEC7A34),
        actions: [
          IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          UserAvatarWidget(userName: 'Usuario123'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Text('Monedas: 100', style: TextStyle(color: Colors.white)),
              Text('Diamantes: 50', style: TextStyle(color: Colors.white)),
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
