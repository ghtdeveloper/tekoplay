import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    });

    return Scaffold(
      backgroundColor: Color(0xFFEC7A34),
      body: Center(
        child: Image.asset(
          'assets/images/splash_tekoplay.png',
        ),
      ),
    );
  }
}
