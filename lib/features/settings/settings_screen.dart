import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuración')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
             // await AuthService.signInWithGoogle();
            },
            child: Text('Iniciar sesión con Google'),
          ),
          ElevatedButton(
            onPressed: () async {
            //  await AuthService.signInWithApple();
            },
            child: Text('Iniciar sesión con Apple ID'),
          ),
        ],
      ),
    );
  }
}
