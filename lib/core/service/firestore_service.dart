import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tekoplay/core/models/technical_issue.dart';
import 'package:tekoplay/core/utils/game_result.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import '../models/game_stats.dart';
import '../models/game_match.dart';
import '../models/user.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _gameMatchesCollection = 'game_matches';
  final String _technicalIssueCollection = 'supports';

  Future<UserModel?> createOrGetUser(User firebaseUser) async {
    try {
      final userDoc =
          await _firestore
              .collection(_usersCollection)
              .doc(firebaseUser.uid)
              .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data?['urlPhoto'] == null ||
            (data?['urlPhoto'] as String).isEmpty) {
          await userDoc.reference.update({
            'urlPhoto': firebaseUser.photoURL ?? '',
          });
        }
        return UserModel.fromFirestore(userDoc);
      } else {
        final newUser = UserModel(
          id: firebaseUser.uid,
          name:
              firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'Usuario',
          urlPhoto: firebaseUser.photoURL ?? '',
          createdAt: DateTime.now(),
          currency: 500,
        );

        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set(newUser.toFirestore());

        return newUser;
      }
    } catch (e) {
      print('Error creating/getting user: $e');
      return null;
    }
  }

  Future<TechnicalIssue?> createTechnicalIssue(
    User? firebaseUser,
    String message,
  ) async {
    try {
      final userDoc =
          await _firestore.collection(_technicalIssueCollection).doc().get();

      if (firebaseUser != null) {
        final newIssue = TechnicalIssue(
          id: userDoc.id,
          issueUserId: firebaseUser.uid,
          message: message,
          createdAt: DateTime.now(),
          status: '',
        );
        await _firestore
            .collection(_technicalIssueCollection)
            .doc(userDoc.id)
            .set(newIssue.toFirestore());
        return newIssue;
      } else {
        final newIssue = TechnicalIssue(
          id: userDoc.id,
          issueUserId: null,
          message: message,
          createdAt: DateTime.now(),
          status: '',
        );
        await _firestore
            .collection(_technicalIssueCollection)
            .doc(userDoc.id)
            .set(newIssue.toFirestore());
        return newIssue;
      }
    } catch (e) {
      print('Error creating/technical issue: $e');
      return null;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();

      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> addMissingUrlPhoto(String userId, String? photoUrl) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'urlPhoto': photoUrl ?? '',
    });
  }

  Future<bool> updateUserCurrency(String userId, int newCurrency) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'currency': newCurrency,
      });
      return true;
    } catch (e) {
      print('Error updating currency: $e');
      return false;
    }
  }

  Future<bool> updateGamePoints(
    String userId,
    GameTypeModel gameType,
    int newPoints,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'gameStats.${gameType.id}.points': newPoints,
      });
      return true;
    } catch (e) {
      print('Error updating game points: $e');
      return false;
    }
  }

  Future<bool> updateGameStats(
    String userId,
    GameTypeModel gameType,
    GameStats stats,
  ) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'gameStats.${gameType.id}': stats.toFirestore(),
      });
      return true;
    } catch (e) {
      print('Error updating game stats: $e');
      return false;
    }
  }

  Future<bool> updateUserData(
    String userId, {
    int? currency,
    Map<GameTypeModel, GameStats>? gameStats,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (currency != null) {
        updates['currency'] = currency;
      }

      if (gameStats != null) {
        Map<String, dynamic> gameStatsData = {};
        gameStats.forEach((gameType, stats) {
          gameStatsData[gameType.id] = stats.toFirestore();
        });
        updates['gameStats'] = gameStatsData;
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection(_usersCollection)
            .doc(userId)
            .update(updates);
      }
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection(_usersCollection).doc(userId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return UserModel.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<bool> recordGameMatch({
    required String userId,
    required GameTypeModel gameType,
    required GameResultModel result,
    required int pointsEarned,
    required int durationMinutes,
    String? opponentId,
    String? opponentName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final batch = _firestore.batch();

      final matchRef = _firestore.collection(_gameMatchesCollection).doc();
      final match = GameMatch(
        id: matchRef.id,
        userId: userId,
        gameType: gameType,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: durationMinutes,
        playedAt: DateTime.now(),
        opponentId: opponentId,
        opponentName: opponentName,
        additionalData: additionalData,
      );

      batch.set(matchRef, match.toFirestore());

      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) {
        print('User not found: $userId');
        return false;
      }

      final user = UserModel.fromFirestore(userDoc);
      final updatedUser = user.updateAfterMatch(match);

      batch.update(userDoc.reference, updatedUser.toFirestore());

      await batch.commit();
      return true;
    } catch (e) {
      print('Error recording game match: $e');
      return false;
    }
  }

  Future<List<GameMatch>> getUserGameHistory({
    required String userId,
    GameTypeModel? gameType,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection(_gameMatchesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('playedAt', descending: true);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType.id);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user game history: $e');
      return [];
    }
  }

  Stream<List<GameMatch>> getUserGameHistoryStream({
    required String userId,
    GameTypeModel? gameType,
    int limit = 20,
  }) {
    Query query = _firestore
        .collection(_gameMatchesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('playedAt', descending: true);

    if (gameType != null) {
      query = query.where('gameType', isEqualTo: gameType.id);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList();
    });
  }

  Future<Map<String, dynamic>?> getUserSummaryStats(String userId) async {
    try {
      final userDoc =
          await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) return null;

      final user = UserModel.fromFirestore(userDoc);

      Map<String, dynamic> summary = {
        'totalPoints': user.totalPoints,
        'currency': user.currency,
        'gameStats': {},
      };

      for (GameTypeModel gameType in GameTypeModel.values) {
        final stats = user.getGameStats(gameType);
        summary['gameStats'][gameType.displayName] = {
          'points': stats.points,
          'gamesPlayed': stats.gamesPlayed,
          'wins': stats.wins,
          'losses': stats.losses,
          'draws': stats.draws,
          'winRate': stats.winRate,
          'averageGameTime': stats.averageGameTimeMinutes,
          'lastPlayed': stats.lastPlayed,
        };
      }

      return summary;
    } catch (e) {
      print('Error getting user summary stats: $e');
      return null;
    }
  }

  Future<GameStats?> getUserGameStats(
    String userId,
    GameTypeModel gameType,
  ) async {
    try {
      final user = await getUser(userId);
      return user?.getGameStats(gameType);
    } catch (e) {
      print('Error getting user game stats: $e');
      return null;
    }
  }

  Future<List<GameMatch>> getRecentMatches({
    GameTypeModel? gameType,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection(_gameMatchesCollection)
          .orderBy('playedAt', descending: true);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType.id);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting recent matches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getGameLeaderboard({
    required GameTypeModel gameType,
    int limit = 10,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(_usersCollection)
              .orderBy('gameStats.${gameType.id}.points', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final user = UserModel.fromFirestore(doc);
        final gameStats = user.getGameStats(gameType);
        return {
          'userId': user.id,
          'userName': user.name,
          'points': gameStats.points,
          'gamesPlayed': gameStats.gamesPlayed,
          'winRate': gameStats.winRate,
        };
      }).toList();
    } catch (e) {
      print('Error getting game leaderboard: $e');
      return [];
    }
  }

  Future<bool> deleteGameMatch(String matchId) async {
    try {
      await _firestore.collection(_gameMatchesCollection).doc(matchId).delete();
      return true;
    } catch (e) {
      print('Error deleting game match: $e');
      return false;
    }
  }
}
