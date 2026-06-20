import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tekoplay/core/utils/game_result.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import '../models/game_stats.dart';
import '../models/game_match.dart';
import 'firestore_service.dart';
import 'anonymous_wallet_service.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();
  final AnonymousWalletService _walletService = AnonymousWalletService();

  String? _anonymousPlayerName;
  bool _isAnonymousMode = false;

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _firestoreService.createOrGetUser(userCredential.user!);
        // Transfer anonymous wallet if exists
        await _transferAnonymousWalletOnLogin(userCredential.user!.uid);
      }
      return userCredential.user;
    } catch (e) {
      if (kDebugMode) {
        print("Error en Google Sign-In: $e");
      }
      return null;
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final OAuthCredential credential =
        FacebookAuthProvider.credential(accessToken.token);
        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _firestoreService.createOrGetUser(userCredential.user!);
          // Transfer anonymous wallet if exists
          await _transferAnonymousWalletOnLogin(userCredential.user!.uid);
        }
        return userCredential.user;
      } else {
        if (kDebugMode) {
          print("Facebook login cancelled o fallido: ${result.status}");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error en Facebook Sign-In: $e");
      }
      return null;
    }
  }

  Future<String?> enableAnonymousMode() async {
    try {
      // Initialize anonymous wallet
      await _walletService.initializeAnonymousWallet();

      _anonymousPlayerName ??= await _firestoreService.generateUniquePlayerName();
      _isAnonymousMode = true;
      return _anonymousPlayerName;
    } catch (e) {
      if (kDebugMode) {
        print('Error enabling anonymous mode: $e');
      }
      return null;
    }
  }

  Future<void> disableAnonymousMode() async {
    if (_anonymousPlayerName != null) {
      await _firestoreService.releaseAnonymousPlayerName(_anonymousPlayerName!);
      _anonymousPlayerName = null;
    }
    _isAnonymousMode = false;
  }

  String? getCurrentDisplayName() {
    if (_isAnonymousMode && _anonymousPlayerName != null) {
      return _anonymousPlayerName;
    }
    return getCurrentUser()?.displayName;
  }

  Future<User?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.sendEmailVerification();

      if (userCredential.user != null) {
        await _firestoreService.createOrGetUser(userCredential.user!);
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print("Error en registro: ${e.code} - ${e.message}");
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Error inesperado en registro: $e");
      }
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Reload to get the latest emailVerified status from the server,
      // since Firebase caches this value locally and it may be stale.
      await userCredential.user?.reload();
      final freshUser = _auth.currentUser;
      if (freshUser != null && freshUser.emailVerified) {
        await _firestoreService.createOrGetUser(freshUser);
        // Transfer anonymous wallet if exists
        await _transferAnonymousWalletOnLogin(freshUser.uid);
        return freshUser;
      } else {
        if (kDebugMode) {
          print("El correo no ha sido verificado");
        }
        return null;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print("Error en Email Sign-In: ${e.code} - ${e.message}");
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Error inesperado en Email Sign-In: $e");
      }
      return null;
    }
  }

  Future<bool> checkEmailVerificationAndCreateUser() async {
    try {
      final user = getCurrentUser();
      if (user == null) return false;

      await user.reload();
      final updatedUser = _auth.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        await _firestoreService.createOrGetUser(updatedUser);
        // Transfer anonymous wallet if exists
        await _transferAnonymousWalletOnLogin(updatedUser.uid);
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Error verificando email: $e");
      }
      return false;
    }
  }

  Future<bool> resendEmailVerification() async {
    try {
      final user = getCurrentUser();
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print("Error al reenviar email de verificación: $e");
      }
      return false;
    }
  }

  bool isEmailVerified() {
    final user = getCurrentUser();
    return user?.emailVerified ?? false;
  }

  Future<bool> canAccessApp() async {
    final user = getCurrentUser();
    if (user == null) return true;
    if (user.providerData.any((provider) => provider.providerId == 'password')) {
      return user.emailVerified;
    }
    return true;
  }

  Future<void> sendEmailVerification(User user) async {
    try {
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error al enviar correo de verificación: $e");
      }
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
    } catch (e) {
      if (kDebugMode) {
        print("Error al cerrar sesión: $e");
      }
    }
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  Future<UserModel?> getUserData(String userId) async {
    return await _firestoreService.getUser(userId);
  }

  Future<UserModel?> getCurrentUserData() async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.getUser(user.uid);
    }
    return null;
  }

  Stream<UserModel?> getCurrentUserDataStream() {
    final user = getCurrentUser();
    if (user != null) {
      return _firestoreService.getUserStream(user.uid);
    }
    return Stream.value(null);
  }

  // WALLET MANAGEMENT METHODS - Updated to handle both anonymous and authenticated users

  /// Get current user's coins (works for both anonymous and authenticated)
  Future<int> getCurrentUserCoins() async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.getAnonymousCoins();
    } else {
      final userData = await getCurrentUserData();
      return userData?.coins ?? 0;
    }
  }

  /// Get current user's diamonds (works for both anonymous and authenticated)
  Future<int> getCurrentUserDiamonds() async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.getAnonymousDiamonds();
    } else {
      final userData = await getCurrentUserData();
      return userData?.diamonds ?? 0;
    }
  }

  /// Update coins for current user (works for both anonymous and authenticated)
  Future<bool> updateCurrentUserCoins(int newCoins) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.updateAnonymousCoins(newCoins);
    } else {
      return await _firestoreService.updateUserCoins(user.uid, newCoins);
    }
  }

  /// Update diamonds for current user (works for both anonymous and authenticated)
  Future<bool> updateCurrentUserDiamonds(int newDiamonds) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.updateAnonymousDiamonds(newDiamonds);
    } else {
      return await _firestoreService.updateUserDiamonds(user.uid, newDiamonds);
    }
  }

  /// Add coins to current user (for purchases)
  Future<bool> addCoins(int coinsToAdd) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.addAnonymousCoins(coinsToAdd);
    } else {
      return await _firestoreService.incrementUserCoins(user.uid, coinsToAdd);
    }
  }

  /// Add diamonds to current user (for purchases)
  Future<bool> addDiamonds(int diamondsToAdd) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.addAnonymousDiamonds(diamondsToAdd);
    } else {
      return await _firestoreService.incrementUserDiamonds(user.uid, diamondsToAdd);
    }
  }

  /// Subtract coins from current user (for bets/costs)
  Future<bool> subtractCoins(int coinsToSubtract) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.subtractAnonymousCoins(coinsToSubtract);
    } else {
      final currentCoins = await getCurrentUserCoins();
      final newCoins = (currentCoins - coinsToSubtract).clamp(0, double.infinity).toInt();
      return await _firestoreService.updateUserCoins(user.uid, newCoins);
    }
  }

  /// Subtract diamonds from current user (for bets/costs)
  Future<bool> subtractDiamonds(int diamondsToSubtract) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.subtractAnonymousDiamonds(diamondsToSubtract);
    } else {
      final currentDiamonds = await getCurrentUserDiamonds();
      final newDiamonds = (currentDiamonds - diamondsToSubtract).clamp(0, double.infinity).toInt();
      return await _firestoreService.updateUserDiamonds(user.uid, newDiamonds);
    }
  }

  /// Check if user has enough coins
  Future<bool> hasEnoughCoins(int requiredCoins) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.hasEnoughCoins(requiredCoins);
    } else {
      final currentCoins = await getCurrentUserCoins();
      return currentCoins >= requiredCoins;
    }
  }

  /// Check if user has enough diamonds
  Future<bool> hasEnoughDiamonds(int requiredDiamonds) async {
    final user = getCurrentUser();
    if (user == null || !await canAccessApp()) {
      return await _walletService.hasEnoughDiamonds(requiredDiamonds);
    } else {
      final currentDiamonds = await getCurrentUserDiamonds();
      return currentDiamonds >= requiredDiamonds;
    }
  }

  // EXISTING METHODS - Updated to work with new wallet system

  Future<bool> updateUserCoins(int newCoins) async {
    return await updateCurrentUserCoins(newCoins);
  }

  Future<bool> updateUserData({
    int? coins,
    int? diamonds,
    Map<GameTypeModel, GameStats>? gameStats
  }) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.updateUserData(
        user.uid,
        coins: coins,
        diamonds: diamonds,
        gameStats: gameStats,
      );
    }
    return false;
  }

  Future<bool> updateGamePoints(GameTypeModel gameType, int newPoints) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.updateGamePoints(user.uid, gameType, newPoints);
    }
    return false;
  }

  Future<bool> updateGameStats(GameTypeModel gameType, GameStats stats) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.updateGameStats(user.uid, gameType, stats);
    }
    return false;
  }

  Future<bool> recordGameMatch({
    required GameTypeModel gameType,
    required GameResultModel result,
    required int pointsEarned,
    required int durationMinutes,
    String? opponentId,
    String? opponentName,
    Map<String, dynamic>? additionalData,
  }) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.recordGameMatch(
        userId: user.uid,
        gameType: gameType,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: durationMinutes,
        opponentId: opponentId,
        opponentName: opponentName,
        additionalData: additionalData,
      );
    }
    return false;
  }

  Future<List<GameMatch>> getCurrentUserGameHistory({
    GameTypeModel? gameType,
    int limit = 50,
  }) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.getUserGameHistory(
        userId: user.uid,
        gameType: gameType,
        limit: limit,
      );
    }
    return [];
  }

  Future<Stream<List<GameMatch>>> getCurrentUserGameHistoryStream({
    GameTypeModel? gameType,
    int limit = 20,
  }) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return _firestoreService.getUserGameHistoryStream(
        userId: user.uid,
        gameType: gameType,
        limit: limit,
      );
    }
    return Stream.value([]);
  }

  Future<Map<String, dynamic>?> getCurrentUserSummaryStats() async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.getUserSummaryStats(user.uid);
    }
    return null;
  }

  Future<GameStats?> getCurrentUserGameStats(GameTypeModel gameType) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.getUserGameStats(user.uid, gameType);
    }
    return null;
  }

  Future<GameStats?> getOpponentUserGameStats(String userId,GameTypeModel gameType) async {
    final user = getCurrentUser();
    if (user != null && await canAccessApp()) {
      return await _firestoreService.getUserGameStats(userId, gameType);
    }
    return null;
  }

  Future<int> getCurrentUserTotalPoints() async {
    final userData = await getCurrentUserData();
    return userData?.totalPoints ?? 0;
  }

  Future<int> getCurrentUserGamePoints(GameTypeModel gameType) async {
    final gameStats = await getCurrentUserGameStats(gameType);
    return gameStats?.points ?? GameStats.getInitialPoints(gameType);
  }

  Future<bool> canAffordBet(GameTypeModel gameType, int betAmount) async {
    final points = await getCurrentUserGamePoints(gameType);
    return points >= betAmount;
  }

  Future<int?> getUserRankInGame(GameTypeModel gameType) async {
    try {
      final user = getCurrentUser();
      if (user == null || !await canAccessApp()) return null;

      final leaderboard = await _firestoreService.getGameLeaderboard(
        gameType: gameType,
        limit: 100,
      );

      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i]['userId'] == user.uid) {
          return i + 1;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user rank: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserGameProfile() async {
    final user = getCurrentUser();
    final userData = await getCurrentUserData();

    if (user == null || userData == null || !await canAccessApp()) return null;

    return {
      'uid': user.uid,
      'name': userData.name,
      'totalPoints': userData.totalPoints,
      'coins': userData.coins,
      'gameStats': userData.gameStats.map((gameType, stats) => MapEntry(
        gameType.displayName,
        {
          'points': stats.points,
          'gamesPlayed': stats.gamesPlayed,
          'winRate': stats.winRate,
        },
      )),
    };
  }

  // PRIVATE HELPER METHODS

  /// Transfer anonymous wallet to authenticated user on login
  Future<void> _transferAnonymousWalletOnLogin(String userId) async {
    try {
      final walletStatus = await _walletService.getAnonymousWalletStatus();

      // Only transfer if there are resources and not previously transferred
      if (!walletStatus['hasTransferred'] &&
          (walletStatus['coins'] > 500 || walletStatus['diamonds'] > 0)) {

        final success = await _walletService.transferAnonymousWalletToUser(userId);

        if (success) {
          if (kDebugMode) {
            print('Wallet anónima transferida exitosamente');
          }
        } else {
          if (kDebugMode) {
            print('Error transfiriendo wallet anónima');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en transferencia automática de wallet: $e');
      }
    }
  }

  /// Get anonymous wallet status (for debugging)
  Future<Map<String, dynamic>> getAnonymousWalletStatus() async {
    return await _walletService.getAnonymousWalletStatus();
  }

  /// Reset transfer flag (for testing purposes)
  Future<void> resetAnonymousWalletTransfer() async {
    await _walletService.resetTransferFlag();
  }
}