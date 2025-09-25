import 'package:flutter/material.dart';
import 'package:tekoplay/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tekoplay/features/adds/ad_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdManager.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TekoplayApp());
}
