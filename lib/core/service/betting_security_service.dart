import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:tekoplay/core/config/flavor_config.dart';

class BettingSecurityService {
  static final BettingSecurityService _instance = BettingSecurityService._internal();
  factory BettingSecurityService() => _instance;
  BettingSecurityService._internal();

  final FirebaseFirestore _firestore = FlavorConfig.firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? _lastCaptchaPass;
  static const _captchaValidDuration = Duration(hours: 1);

  bool get isCaptchaValid =>
      _lastCaptchaPass != null &&
      DateTime.now().difference(_lastCaptchaPass!) < _captchaValidDuration;

  void recordCaptchaPass() {
    _lastCaptchaPass = DateTime.now();
  }

  Future<BettingCheckResult> canPlayBettingGame() async {
    final user = _auth.currentUser;
    if (user == null) return BettingCheckResult.notAuthenticated;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return BettingCheckResult.notAuthenticated;

      final userData = userDoc.data()!;
      if (userData['suspended'] == true) return BettingCheckResult.suspended;

      if (!isCaptchaValid) return BettingCheckResult.captchaRequired;

      return BettingCheckResult.allowed;
    } catch (e) {
      if (kDebugMode) print('BettingSecurityService error: $e');
      return BettingCheckResult.allowed;
    }
  }
}

enum BettingCheckResult {
  allowed,
  notAuthenticated,
  suspended,
  captchaRequired,
}
