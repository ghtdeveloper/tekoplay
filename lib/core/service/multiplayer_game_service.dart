

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/multiplayer_game_match_chess.dart';
import '../utils/game_result.dart';
import '../utils/game_type.dart';
import 'firestore_service.dart';
import 'game_quota_service.dart';

class MultiplayerGameService {
  static final MultiplayerGameService _instance =
  MultiplayerGameService._internal();

  factory MultiplayerGameService() => _instance;

  MultiplayerGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _gamesCollection = 'multiplayer_games';

  Future<String?> createGame({
    required String hostId,
    required String hostName,
    String? guestId,
    String? guestName,
    required String gameType,
    bool isRanked = false,
    int? betAmount,
    String? hostPhotoUrl,
    String? guestPhotoUrl,
    required String currencyType,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc();

      int quotaAmount;
      if (betAmount != null) {
        quotaAmount = betAmount;
        currencyType = 'diamonds';
      } else {
        quotaAmount = currencyType == 'diamonds' ? 25 : 100;
      }

      final game = MultiplayerGameMatch(
        id: gameRef.id,
        gameType: gameType,
        hostId: hostId,
        hostName: hostName,
        guestId: guestId,
        guestName: guestName,
        hostPhotoUrl: hostPhotoUrl,
        guestPhotoUrl: guestPhotoUrl,
        status: guestId != null ? 'active' : 'waiting',
        currentTurn: 'host',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        createdAt: DateTime.now(),
        startedAt: guestId != null ? DateTime.now() : null,
        isRanked: isRanked,
        betAmount: betAmount,
        currencyType: currencyType,
        hostQuota: quotaAmount,
        guestQuota: guestId != null ? quotaAmount : null,
        quotasCollected: false,
        rewardsDistributed: false,
      );

      await gameRef.set(game.toFirestore());

      if (guestId != null) {
        final quotaService = GameQuotaService();
        await quotaService.collectQuotas(
          gameId: gameRef.id,
          hostId: hostId,
          guestId: guestId,
          quotaAmount: quotaAmount,
          currencyType: currencyType,
        );
      }

      return gameRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error creando juego: $e');
      }
      return null;
    }
  }

  Future<bool> joinGame(
      String gameId,
      String playerId,
      String playerName,
      String? playerPhotoUrl,
      ) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = MultiplayerGameMatch.fromFirestore(gameDoc);

      if (game.guestId != null || game.hostId == playerId) return false;

      await gameRef.update({
        'guestId': playerId,
        'guestName': playerName,
        'guestPhotoUrl': playerPhotoUrl,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'guestQuota': game.hostQuota,
      });

      if (game.hostQuota != null) {
        final quotaService = GameQuotaService();
        final result = await quotaService.collectQuotas(
          gameId: gameId,
          hostId: game.hostId,
          guestId: playerId,
          quotaAmount: game.hostQuota!,
          currencyType: game.currencyType,
        );

        if (result['success'] != true) {
          await gameRef.update({
            'guestId': null,
            'guestName': null,
            'guestPhotoUrl': null,
            'status': 'waiting',
            'startedAt': null,
          });
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error uniéndose al juego: $e');
      }
      return false;
    }
  }

  Stream<MultiplayerGameMatch?> getGameStream(String gameId) {
    return _firestore.collection(_gamesCollection).doc(gameId).snapshots().map((
        snapshot,
        ) {
      if (snapshot.exists) {
        return MultiplayerGameMatch.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<bool> makeMove({
    required String gameId,
    required String playerId,
    required String from,
    required String to,
    String? promotion,
    required String newFen,
    required String moveNotation,
    String? lastMoveFrom,
    String? lastMoveTo,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);

        if (!gameDoc.exists) throw Exception('Game not found');

        final game = MultiplayerGameMatch.fromFirestore(gameDoc);

        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        final newMoves = List<String>.from(game.moves);

        if (from != "xx" && to != "xx" && from != "player" && to != "move") {
          final moveUci = promotion != null ? '$from$to$promotion' : '$from$to';
          newMoves.add(moveUci);
        } else {
          newMoves.add("move${newMoves.length + 1}");
        }

        final newTurn = game.currentTurn == 'host' ? 'guest' : 'host';

        transaction.update(gameRef, {
          'currentFen': newFen,
          'currentTurn': newTurn,
          'moves': newMoves,
          'lastMoveNotation': moveNotation,
          'lastMoveFrom': lastMoveFrom ?? from,
          'lastMoveTo': lastMoveTo ?? to,
        });
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> abandonGame({
    required String gameId,
    required String playerId,
  }) async {
    try {

      final gameRef = FirebaseFirestore.instance
          .collection('multiplayer_games')
          .doc(gameId);

      final gameDoc = await gameRef.get();
      if (!gameDoc.exists) {
        return false;
      }

      final gameData = gameDoc.data() as Map<String, dynamic>;
      final currentStatus = gameData['status'] ?? '';

      if (currentStatus != 'active') {
        return false;
      }

      String? winnerId;
      final hostId = gameData['hostId'];
      final guestId = gameData['guestId'];

      if (playerId == hostId) {
        winnerId = guestId;
      } else if (playerId == guestId) {
        winnerId = hostId;
      }
      await gameRef.update({
        'status': 'abandoned',
        'abandonedBy': playerId,
        'winnerId': winnerId,
        'endTime': FieldValue.serverTimestamp(),
        'result': 'win',
        'finishedAt': FieldValue.serverTimestamp(),
        'reason': 'abandoned',
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error abandonando juego: $e');
      }
      return false;
    }
  }

  Future<bool> finishGame({
    required String gameId,
    required GameResultModel result,
    String? winnerId,
    String? reason,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      // ✅ PRIMERO: Verificar si quotasCollected está en true
      final gameDoc = await gameRef.get();
      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data() as Map<String, dynamic>;
      final quotasCollected = gameData['quotasCollected'] ?? false;


      if (!quotasCollected) {
        if (kDebugMode) {
          print('⚠️ ADVERTENCIA: Finalizando juego sin cuotas cobradas');
          print('   gameId: $gameId');
          print('   quotasCollected: $quotasCollected');
        }
      }

      await gameRef.update({
        'status': 'finished',
        'result': result.toString().split('.').last,
        'winnerId': winnerId,
        'finishedAt': FieldValue.serverTimestamp(),
        'reason': reason,
        'quotasCollected': true,
      });

      if (gameDoc.exists) {
        final game = MultiplayerGameMatch.fromFirestore(gameDoc);
        await _updatePlayerStats(game, result);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error finishing game: $e');
      }
      return false;
    }
  }

  Future<void> _updatePlayerStats(
      MultiplayerGameMatch game,
      GameResultModel result,
      ) async {
    try {
      final firestoreService = FirestoreService();

      GameResultModel hostResult = result;
      GameResultModel guestResult = result;

      if (result == GameResultModel.win) {
        if (game.winnerId == game.hostId) {
          hostResult = GameResultModel.win;
          guestResult = GameResultModel.loss;
        } else if (game.winnerId == game.guestId) {
          hostResult = GameResultModel.loss;
          guestResult = GameResultModel.win;
        }
      }

      int hostPoints = _calculatePoints(hostResult);
      int guestPoints = _calculatePoints(guestResult);

      final gameDuration =
      game.finishedAt != null && game.startedAt != null
          ? game.finishedAt!.difference(game.startedAt!).inMinutes
          : 1;

      await firestoreService.recordGameMatch(
        userId: game.hostId,
        gameType: GameTypeModel.chess,
        result: hostResult,
        pointsEarned: hostPoints,
        durationMinutes: gameDuration,
        opponentId: game.guestId,
        opponentName: game.guestName,
        additionalData: {
          'isMultiplayer': true,
          'gameId': game.id,
          'finalFEN': game.currentFen,
          'isRanked': game.isRanked,
          'betAmount': game.betAmount,
        },
      );

      // Guest
      if (game.guestId != null) {
        await firestoreService.recordGameMatch(
          userId: game.guestId!,
          gameType: GameTypeModel.chess,
          result: guestResult,
          pointsEarned: guestPoints,
          durationMinutes: gameDuration,
          opponentId: game.hostId,
          opponentName: game.hostName,
          additionalData: {
            'isMultiplayer': true,
            'gameId': game.id,
            'finalFEN': game.currentFen,
            'isRanked': game.isRanked,
            'betAmount': game.betAmount,
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating player stats: $e');
      }
    }
  }

  int _calculatePoints(GameResultModel result) {
    switch (result) {
      case GameResultModel.win:
        return 15;
      case GameResultModel.loss:
        return -5;
      case GameResultModel.draw:
        return 5;
    }
  }

  Stream<List<MultiplayerGameMatch>> getActiveGames(String userId) {
    return _firestore
        .collection(_gamesCollection)
        .where('status', isEqualTo: 'active')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .asyncMap((hostSnapshot) async {
      final guestSnapshot =
      await _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'active')
          .where('guestId', isEqualTo: userId)
          .get();

      final allDocs = [...hostSnapshot.docs, ...guestSnapshot.docs];

      return allDocs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<MultiplayerGameMatch>> getWaitingGames({
    String? gameType,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt', descending: true);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting waiting games: $e');
      }
      return [];
    }
  }

  Future<bool> cancelGame(String gameId, String userId) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = MultiplayerGameMatch.fromFirestore(gameDoc);

      if (game.status == 'waiting' && game.hostId == userId) {
        await gameRef.update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling game: $e');
      }
      return false;
    }
  }
}