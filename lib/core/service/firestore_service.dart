import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:tekoplay/core/models/technical_issue.dart';
import 'package:tekoplay/core/utils/game_result.dart';
import 'package:tekoplay/core/utils/game_type.dart';
import '../models/game_stats.dart';
import '../models/game_match.dart';
import '../models/multiplayer_game_match_chess.dart';
import '../models/user.dart';

class LeaderboardPage {
  final List<Map<String, dynamic>> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const LeaderboardPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _gameMatchesCollection = 'game_matches';
  final String _technicalIssueCollection = 'supports';
  final String _countersCollection = 'counters';
  final String _anonymousUsersCollection = 'anonymous_usernames';

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
          email: firebaseUser.email?? '',
          createdAt: DateTime.now(),
          coins: 500,
        );

        await _firestore
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set(newUser.toFirestore());

        return newUser;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating/getting user: $e');
      }
      return null;
    }
  }


  Future<String> generateUniquePlayerName() async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final counterRef = _firestore.collection(_countersCollection).doc('anonymous_players');
        final counterDoc = await transaction.get(counterRef);

        int nextNumber;
        if (counterDoc.exists) {
          nextNumber = (counterDoc.data()?['count'] ?? 0) + 1;
        } else {
          nextNumber = 1;
        }
        final playerName = 'Player${nextNumber.toString().padLeft(5, '0')}';

        final existingNameDoc = await _firestore
            .collection(_anonymousUsersCollection)
            .doc(playerName)
            .get();
        if (existingNameDoc.exists) {
          return await _generateRandomPlayerName();
        }
        transaction.set(counterRef, {'count': nextNumber}, SetOptions(merge: true));
        transaction.set(
            _firestore.collection(_anonymousUsersCollection).doc(playerName),
            {
              'name': playerName,
              'createdAt': FieldValue.serverTimestamp(),
              'isActive': true,
            }
        );

        return playerName;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error generating incremental player name: $e');
      }
      return await _generateRandomPlayerName();
    }
  }



  Future<String> _generateRandomPlayerName() async {
    try {
      for (int attempt = 0; attempt < 10; attempt++) {

        final random = DateTime.now().millisecondsSinceEpoch % 99999 + 1;
        final playerName = 'Player${random.toString().padLeft(5, '0')}';

        final existingDoc = await _firestore
            .collection(_anonymousUsersCollection)
            .doc(playerName)
            .get();

        if (!existingDoc.exists) {
          await _firestore.collection(_anonymousUsersCollection).doc(playerName).set({
            'name': playerName,
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'generationType': 'random',
          });
          return playerName;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final playerName = 'Player${timestamp.toString().substring(timestamp.toString().length - 5)}';

      await _firestore.collection(_anonymousUsersCollection).doc(playerName).set({
        'name': playerName,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'generationType': 'timestamp',
      });

      return playerName;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating random player name: $e');
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'Player$timestamp';
    }
  }


  Future<bool> releaseAnonymousPlayerName(String playerName) async {
    try {
      await _firestore.collection(_anonymousUsersCollection).doc(playerName).update({
        'isActive': false,
        'releasedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error releasing player name: $e');
      }
      return false;
    }
  }

  Future<bool> isPlayerNameAvailable(String playerName) async {
    try {
      final doc = await _firestore.collection(_anonymousUsersCollection).doc(playerName).get();
      return !doc.exists || !(doc.data()?['isActive'] ?? false);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking player name availability: $e');
      }
      return false;
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
      if (kDebugMode) {
        print('Error creating/technical issue: $e');
      }
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
      if (kDebugMode) {
        print('Error getting user: $e');
      }
      return null;
    }
  }

  Future<void> addMissingUrlPhoto(String userId, String? photoUrl) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'urlPhoto': photoUrl ?? '',
    });
  }

  Future<bool> updateUserCoins(String userId, int newCoins) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'coins': newCoins,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> incrementUserCoins(String userId, int amount) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'coins': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUserDiamonds(String userId, int newDiamonds) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'diamonds': newDiamonds,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> incrementUserDiamonds(String userId, int amount) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'diamonds': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUserDiamondsEarned(String userId, int newDiamonds) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'diamondsEarned': newDiamonds,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> incrementUserDiamondsEarned(String userId, int amount) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'diamondsEarned': FieldValue.increment(amount),
      });
      return true;
    } catch (e) {
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
      if (kDebugMode) {
        print('Error updating game points: $e');
      }
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
      if (kDebugMode) {
        print('Error updating game stats: $e');
      }
      return false;
    }
  }

  Future<bool> updateUserData(
    String userId, {
    int? coins, int? diamonds,
    Map<GameTypeModel, GameStats>? gameStats,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (coins != null) {
        updates['coins'] = coins;
      }
      if (coins != null) {
        updates['diamonds'] = diamonds;
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
      if (kDebugMode) {
        print('Error updating user data: $e');
      }
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
        if (kDebugMode) {
          print('User not found: $userId');
        }
        return false;
      }

      final user = UserModel.fromFirestore(userDoc);
      final updatedUser = user.updateAfterMatch(match);

      final Map<String, dynamic> updates = {
        'gameStats': updatedUser.gameStats.map(
              (gameType, stats) => MapEntry(gameType.id, stats.toFirestore()),
        ),
        'totalPoints': updatedUser.totalPoints,
      };


      batch.update(userDoc.reference, updates);

      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error recording game match: $e');
      }
      return false;
    }
  }

  Future<List<GameMatch>> getUserGameHistory({
    required String userId,
    GameTypeModel? gameType,
    int limit = 50,
  }) async {
    try {
      // All where() clauses must come before orderBy()
      Query query = _firestore
          .collection(_gameMatchesCollection)
          .where('userId', isEqualTo: userId);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType.id);
      }

      query = query.orderBy('playedAt', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => GameMatch.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user game history (gameType: ${gameType?.id}): $e');
        if (e.toString().contains('index')) {
          print('⚠️ Missing Firestore composite index. '
              'Create index for collection "game_matches" with fields: '
              'userId (Ascending), ${gameType != null ? 'gameType (Ascending), ' : ''}playedAt (Descending)');
        }
      }
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
        'coins': user.coins,
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
      if (kDebugMode) {
        print('Error getting user summary stats: $e');
      }
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
      if (kDebugMode) {
        print('Error getting user game stats: $e');
      }
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
      if (kDebugMode) {
        print('Error getting recent matches: $e');
      }
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
      if (kDebugMode) {
        print('Error getting game leaderboard: $e');
      }
      return [];
    }
  }

  Future<LeaderboardPage> getGameLeaderboardPaginated({
    required GameTypeModel gameType,
    int pageSize = 20,
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      Query query = _firestore
          .collection(_usersCollection)
          .orderBy('gameStats.${gameType.id}.points', descending: true)
          .limit(pageSize);

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snapshot = await query.get();

      final items = snapshot.docs.map((doc) {
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

      return LeaderboardPage(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting paginated leaderboard: $e');
      }
      return LeaderboardPage(items: [], lastDocument: null, hasMore: false);
    }
  }

  Future<bool> deleteGameMatch(String matchId) async {
    try {
      await _firestore.collection(_gameMatchesCollection).doc(matchId).delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting game match: $e');
      }
      return false;
    }
  }

  Future<UserModel?> findUserByEmail(String email) async {
    try {
      final usersQuery = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        return UserModel.fromFirestore(usersQuery.docs.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error finding user by email: $e');
      }
      return null;
    }
  }

  Future<List<UserModel>> searchUsersByUsername(String username) async {
    try {
      final usersQuery = await _firestore
          .collection(_usersCollection)
          .where('name', isGreaterThanOrEqualTo: username)
          .where('name', isLessThanOrEqualTo: '$username\uf8ff')
          .limit(10)
          .get();

      return usersQuery.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching users: $e');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPlayerMultiplayerStats(String userId) async {
    try {
      final multiplayerMatchesQuery = await _firestore
          .collection(_gameMatchesCollection)
          .where('userId', isEqualTo: userId)
          .where('additionalData.isMultiplayer', isEqualTo: true)
          .get();

      int totalMultiplayerGames = multiplayerMatchesQuery.docs.length;
      int wins = 0;
      int losses = 0;
      int draws = 0;
      int totalTime = 0;

      for (final doc in multiplayerMatchesQuery.docs) {
        final match = GameMatch.fromFirestore(doc);

        switch (match.result) {
          case GameResultModel.win:
            wins++;
            break;
          case GameResultModel.loss:
            losses++;
            break;
          case GameResultModel.draw:
            draws++;
            break;
        }

        totalTime += match.durationMinutes;
      }

      double winRate = totalMultiplayerGames > 0 ? (wins / totalMultiplayerGames) * 100 : 0;
      int averageGameTime = totalMultiplayerGames > 0 ? (totalTime / totalMultiplayerGames).round() : 0;

      return {
        'totalGames': totalMultiplayerGames,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'winRate': winRate,
        'averageGameTime': averageGameTime,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting multiplayer stats: $e');
      }
      return null;
    }
  }

  Future<bool> updateUserProfilePhoto(String userId, String? photoUrl) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'urlPhoto': photoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile photo: $e');
      }
      return false;
    }
  }

  Future<bool> saveDeviceToken(String userId, String token, String platform) async {
    try {
      await _firestore.collection('user_tokens').doc(userId).set({
        'token': token,
        'platform': platform,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
        'active': true,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device token: $e');
      }
      return false;
    }
  }

  Future<bool> removeDeviceToken(String userId) async {
    try {
      await _firestore.collection('user_tokens').doc(userId).update({
        'active': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing device token: $e');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getInvitationHistory(String userId) async {
    try {
      final sentQuery = await _firestore
          .collection('game_invitations')
          .where('fromUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final receivedQuery = await _firestore
          .collection('game_invitations')
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final allInvitations = [
        ...sentQuery.docs.map((doc) {
          final data = doc.data();
          data['type'] = 'sent';
          return data;
        }),
        ...receivedQuery.docs.map((doc) {
          final data = doc.data();
          data['type'] = 'received';
          return data;
        }),
      ];

      allInvitations.sort((a, b) {
        final aDate = (a['createdAt'] as Timestamp).toDate();
        final bDate = (b['createdAt'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });

      return allInvitations;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting invitation history: $e');
      }
      return [];
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    String? bio,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (displayName != null) updates['name'] = displayName;
      if (photoUrl != null) updates['urlPhoto'] = photoUrl;
      if (bio != null) updates['bio'] = bio;
      if (preferences != null) updates['preferences'] = preferences;

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore
            .collection(_usersCollection)
            .doc(userId)
            .update(updates);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile: $e');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMultiplayerLeaderboard({
    required GameTypeModel gameType,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .orderBy('gameStats.${gameType.id}.points', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> leaderboard = [];

      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final user = UserModel.fromFirestore(doc);
        final gameStats = user.getGameStats(gameType);

        final multiplayerStats = await getPlayerMultiplayerStats(user.id);

        leaderboard.add({
          'rank': i + 1,
          'userId': user.id,
          'userName': user.name,
          'userPhoto': user.urlPhoto,
          'points': gameStats.points,
          'totalGames': gameStats.gamesPlayed,
          'winRate': gameStats.winRate,
          'multiplayerStats': multiplayerStats,
        });
      }

      return leaderboard;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting multiplayer leaderboard: $e');
      }
      return [];
    }
  }

  Future<bool> reportPlayer({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    required String gameId,
    String? description,
  }) async {
    try {
      await _firestore.collection('player_reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'gameId': gameId,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error reporting player: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getServerStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final todayGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      final weekAgo = now.subtract(Duration(days: 7));
      final activeUsersQuery = await _firestore
          .collection(_gameMatchesCollection)
          .where('playedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
          .get();

      final activeUserIds = activeUsersQuery.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();

      final activeGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'active')
          .get();

      return {
        'todayGames': todayGamesQuery.docs.length,
        'activeUsers': activeUserIds.length,
        'activeGames': activeGamesQuery.docs.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting server stats: $e');
      }
      return null;
    }
  }

  Future<List<MultiplayerGameMatch>> findWaitingOnlineGames({
    required String gameType,
    required int userRanking,
    int? timeMinutes,
    int rankingTolerance = 20,
  }) async {
    try {
      Query query = _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameType', isEqualTo: gameType)
          .where('gameSettings.isOnlineMatchmaking', isEqualTo: true);

      if (timeMinutes != null) {
        query = query.where('gameSettings.timeMinutes', isEqualTo: timeMinutes);
      }

      final snapshot = await query
          .orderBy('createdAt', descending: false)
          .limit(10)
          .get();

      final games = snapshot.docs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .where((game) {
        final hostRanking = game.gameSettings?['hostRanking'] as int? ?? 1000;
        return (hostRanking - userRanking).abs() <= rankingTolerance;
      })
          .toList();

      return games;
    } catch (e) {
      if (kDebugMode) {
        print('Error finding waiting online games: $e');
      }
      return [];
    }
  }

  Future<String?> createOnlineMatchmakingGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required String gameType,
    required int hostRanking,
    int? timeMinutes,
    bool isRanked = true,
  }) async {
    try {
      final gameRef = _firestore.collection('multiplayer_games').doc();

      final gameData = {
        'id': gameRef.id,
        'gameType': gameType,
        'hostId': hostId,
        'hostName': hostName,
        'hostPhotoUrl': hostPhotoUrl,
        'guestId': null,
        'guestName': null,
        'guestPhotoUrl': null,
        'status': 'waiting',
        'currentTurn': 'host',
        'currentFen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': [],
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'finishedAt': null,
        'winnerId': null,
        'result': null,
        'lastMoveNotation': null,
        'isRanked': isRanked,
        'betAmount': null,
        'gameSettings': {
          'isOnlineMatchmaking': true,
          'hostRanking': hostRanking,
          'timeMinutes': timeMinutes,
          'rankingTolerance': 20,
          'createdForMatchmaking': true,
        },
      };

      await gameRef.set(gameData);
      return gameRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating online matchmaking game: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> joinOnlineMatchmakingGame({
    required String gameId,
    required String guestId,
    required String guestName,
    String? guestPhotoUrl,
    required int guestRanking,
  }) async {
    try {
      final gameRef = _firestore.collection('multiplayer_games').doc(gameId);

      return await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);

        if (!gameDoc.exists) {
          throw Exception('Game not found');
        }

        final gameData = gameDoc.data()!;
        final hostRanking = gameData['gameSettings']['hostRanking'] as int? ?? 1000;

        final bool hostPlaysWhite = hostRanking >= guestRanking;

        String initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        String currentTurn = hostPlaysWhite ? 'host' : 'guest';

        transaction.update(gameRef, {
          'guestId': guestId,
          'guestName': guestName,
          'guestPhotoUrl': guestPhotoUrl,
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
          'currentTurn': currentTurn,
          'currentFen': initialFen,
          'gameSettings': {
            ...gameData['gameSettings'],
            'guestRanking': guestRanking,
            'hostPlaysWhite': hostPlaysWhite,
            'guestPlaysWhite': !hostPlaysWhite,
          },
        });

        return {
          'success': true,
          'hostPlaysWhite': hostPlaysWhite,
          'guestPlaysWhite': !hostPlaysWhite,
          'currentTurn': currentTurn,
        };
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error joining online matchmaking game: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> cancelOnlineMatchmakingGame(String gameId, String userId) async {
    try {
      final gameRef = _firestore.collection('multiplayer_games').doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data()!;

      if (gameData['hostId'] != userId || gameData['status'] != 'waiting') {
        return false;
      }

      await gameRef.update({
        'status': 'cancelled',
        'finishedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling online matchmaking game: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMatchmakingStats() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(Duration(hours: 24));

      final recentGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('gameSettings.isOnlineMatchmaking', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last24Hours))
          .get();

      final waitingGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameSettings.isOnlineMatchmaking', isEqualTo: true)
          .get();

      final activeGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'active')
          .where('gameSettings.isOnlineMatchmaking', isEqualTo: true)
          .get();

      return {
        'gamesLast24Hours': recentGamesQuery.docs.length,
        'currentlyWaiting': waitingGamesQuery.docs.length,
        'currentlyPlaying': activeGamesQuery.docs.length,
        'lastUpdated': now.toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting matchmaking stats: $e');
      }
      return null;
    }
  }

  Future<int> cleanupOldMatchmakingGames() async {
    try {
      final twoMinutesAgo = DateTime.now().subtract(Duration(minutes: 2));

      final oldGamesQuery = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameSettings.isOnlineMatchmaking', isEqualTo: true)
          .where('createdAt', isLessThan: Timestamp.fromDate(twoMinutesAgo))
          .get();

      int deletedCount = 0;
      final batch = _firestore.batch();

      for (final doc in oldGamesQuery.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'finishedAt': FieldValue.serverTimestamp(),
        });
        deletedCount++;
      }

      if (deletedCount > 0) {
        await batch.commit();
      }

      return deletedCount;
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old matchmaking games: $e');
      }
      return 0;
    }
  }

  Future<int> getUserGameRanking(String userId, GameTypeModel gameType) async {
    try {
      final user = await getUser(userId);
      if (user == null) return 1000;

      final gameStats = user.getGameStats(gameType);
      return gameStats.points;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user game ranking: $e');
      }
      return 1000;
    }
  }

  Future<bool> recordTimedGameMatch({
    required String userId,
    required GameTypeModel gameType,
    required GameResultModel result,
    required int pointsEarned,
    required int durationMinutes,
    String? opponentId,
    String? opponentName,
    int? gameTimeMinutes,
    int? timeUsedSeconds,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      Map<String, dynamic> extendedData = additionalData ?? {};

      if (gameTimeMinutes != null) {
        extendedData['gameTimeMinutes'] = gameTimeMinutes;
      }

      if (timeUsedSeconds != null) {
        extendedData['timeUsedSeconds'] = timeUsedSeconds;
        extendedData['timeRemaining'] = (gameTimeMinutes ?? 0) * 60 - timeUsedSeconds;
      }

      extendedData['isTimedGame'] = gameTimeMinutes != null;

      return await recordGameMatch(
        userId: userId,
        gameType: gameType,
        result: result,
        pointsEarned: pointsEarned,
        durationMinutes: durationMinutes,
        opponentId: opponentId,
        opponentName: opponentName,
        additionalData: extendedData,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error recording timed game match: $e');
      }
      return false;
    }
  }


}
