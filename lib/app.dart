import 'package:flutter/material.dart';

import 'features/splash/splash_screen.dart';

class TekoplayApp extends StatelessWidget {
  const TekoplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tekoplay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: SplashScreen(),
    );
  }
}
