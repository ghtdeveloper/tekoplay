import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/domino_game_match.dart';
import 'bot_name_service.dart';
import 'game_quota_service.dart';

class DominoGameService {
  static final DominoGameService _instance = DominoGameService._internal();
  factory DominoGameService() => _instance;
  DominoGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'domino_games';
  final Random _random = Random();

  Future<Map<String, dynamic>?> createGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required String currencyType,
    int? betAmount,
    bool isOnlineMatchmaking = false,
    int numberOfPlayers = 2,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc();
      final quota = betAmount ?? (currencyType == 'diamonds' ? 25 : 100);

      final deal = DominoGameState.initialDeal(_random, numberOfPlayers: numberOfPlayers);
      final firstTurn = deal['firstTurn'] as String;

      final state = DominoGameState.fromDeal(deal: deal);

      final match = DominoGameMatch(
        id: gameRef.id,
        gameType: 'Domino',
        hostId: hostId,
        hostName: hostName,
        hostPhotoUrl: hostPhotoUrl,
        status: 'waiting',
        currentTurn: firstTurn,
        gameState: state,
        createdAt: DateTime.now(),
        currencyType: currencyType,
        betAmount: quota,
        hostQuota: quota,
        numberOfPlayers: numberOfPlayers,
        gameSettings: {
          'isOnlineMatchmaking': isOnlineMatchmaking,
        },
      );

      await gameRef.set(match.toFirestore());
      return {'gameId': gameRef.id, 'firstTurn': firstTurn};
    } catch (e) {
      if (kDebugMode) print('Error creating domino game: $e');
      return null;
    }
  }

  Future<bool> joinGame({
    required String gameId,
    required String guestId,
    required String guestName,
    String? guestPhotoUrl,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);
      final doc = await gameRef.get();
      if (!doc.exists) return false;

      final game = DominoGameMatch.fromFirestore(doc);
      if (game.status != 'waiting') return false;
      if (game.hostId == guestId) return false;
      if (game.guestId == guestId || game.guest2Id == guestId || game.guest3Id == guestId) return false;

      // Find next available slot
      final Map<String, dynamic> updates = {};
      if (game.guestId == null) {
        updates['guestId'] = guestId;
        updates['guestName'] = guestName;
        updates['guestPhotoUrl'] = guestPhotoUrl;
        updates['guestQuota'] = game.betAmount;
      } else if (game.numberOfPlayers >= 3 && game.guest2Id == null) {
        updates['guest2Id'] = guestId;
        updates['guest2Name'] = guestName;
      } else if (game.numberOfPlayers >= 4 && game.guest3Id == null) {
        updates['guest3Id'] = guestId;
        updates['guest3Name'] = guestName;
      } else {
        return false; // no slot available
      }

      final newPlayerCount = game.currentPlayerCount + 1;
      final willBeActive = newPlayerCount >= game.numberOfPlayers;
      if (willBeActive) {
        updates['status'] = 'active';
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      await gameRef.update(updates);

      // Collect quotas only when the last player joins (game becomes active)
      if (willBeActive && (game.betAmount ?? 0) > 0 && game.guestId != null) {
        final quotaService = GameQuotaService();
        final result = await quotaService.collectQuotas(
          gameId: gameId,
          hostId: game.hostId,
          guestId: guestId,
          quotaAmount: game.betAmount!,
          currencyType: game.currencyType,
          collectionName: _collection,
        );
        if (result['success'] != true) {
          // Rollback
          final rollback = <String, dynamic>{'status': 'waiting', 'startedAt': null};
          if (updates.containsKey('guestId')) { rollback['guestId'] = null; rollback['guestName'] = null; rollback['guestPhotoUrl'] = null; rollback['guestQuota'] = null; }
          if (updates.containsKey('guest2Id')) { rollback['guest2Id'] = null; rollback['guest2Name'] = null; }
          if (updates.containsKey('guest3Id')) { rollback['guest3Id'] = null; rollback['guest3Name'] = null; }
          await gameRef.update(rollback);
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error joining domino game: $e');
      return false;
    }
  }

  Future<bool> addBotAndStart(String gameId) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);
      final doc = await gameRef.get();
      if (!doc.exists) return false;

      final game = DominoGameMatch.fromFirestore(doc);
      if (game.status != 'waiting') return false;

      final profile = await BotNameService.pickUnseenProfile(_random);
      await gameRef.update({
        'guestId': 'bot_1',
        'guestName': profile['name'],
        'guestPhotoUrl': null,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding bot: $e');
      return false;
    }
  }

  Future<bool> playTile({
    required String gameId,
    required String playerId,
    required String tileId,
    required String side,
    required Map<String, dynamic> newRoundDeal,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (!game.isActive) return false;
        if (!game.isPlayerTurn(playerId)) return false;

        final playerNum = game.getPlayerNumber(playerId);
        final hand = List<String>.from(game.getHand(playerNum));
        if (!hand.contains(tileId)) return false;

        final tileData = game.gameState.tiles[tileId];
        if (tileData == null) return false;

        final tl = tileData['left']!;
        final tr = tileData['right']!;
        final isDouble = tl == tr;

        final chain = List<DominoChainTile>.from(game.gameState.chain);
        int? leftOpen = game.gameState.leftOpen;
        int? rightOpen = game.gameState.rightOpen;

        int displayLeft, displayRight;
        int? newLeftOpen = leftOpen;
        int? newRightOpen = rightOpen;

        if (chain.isEmpty) {
          // Primera ficha: debe ser el doble más alto en la mano del jugador actual.
          // Si nadie tiene dobles, cualquier ficha es válida.
          final currentHand = game.getHand(playerNum);
          int maxDouble = -1;
          for (final id in currentHand) {
            final t = game.gameState.tiles[id];
            if (t != null && t['left'] == t['right'] && t['left']! > maxDouble) {
              maxDouble = t['left']!;
            }
          }
          if (maxDouble != -1 && !(tl == tr && tl == maxDouble)) {
            return false; // Debe jugar su doble más alto
          }
          displayLeft = tl;
          displayRight = tr;
          newLeftOpen = tl;
          newRightOpen = tr;
        } else if (side == 'left') {
          if (leftOpen == null) return false;
          if (tr == leftOpen) {
            displayLeft = tl;
            displayRight = tr;
            newLeftOpen = tl;
          } else if (tl == leftOpen) {
            displayLeft = tr;
            displayRight = tl;
            newLeftOpen = tr;
          } else {
            return false;
          }
          if (isDouble) newLeftOpen = tl;
        } else {
          if (rightOpen == null) return false;
          if (tl == rightOpen) {
            displayLeft = tl;
            displayRight = tr;
            newRightOpen = tr;
          } else if (tr == rightOpen) {
            displayLeft = tr;
            displayRight = tl;
            newRightOpen = tl;
          } else {
            return false;
          }
          if (isDouble) newRightOpen = tr;
        }

        hand.remove(tileId);

        final placement = DominoChainTile(
          id: tileId,
          displayLeft: displayLeft,
          displayRight: displayRight,
        );

        if (side == 'left') {
          chain.insert(0, placement);
        } else {
          chain.add(placement);
        }

        final nPlayers = game.numberOfPlayers;
        final roundNum = game.gameState.roundNumber;
        final targetScore = game.targetScore;

        // Build updated hands for all players
        final hands = <int, List<String>>{};
        for (int p = 1; p <= nPlayers; p++) {
          hands[p] = p == playerNum ? hand : List<String>.from(game.gameState.handOf(p));
        }

        final Map<String, dynamic> updates = {};

        if (hand.isEmpty) {
          // This player emptied their hand — they win the round
          // Collect pips from all OTHER players
          int totalOtherPips = 0;
          for (int p = 1; p <= nPlayers; p++) {
            if (p != playerNum) totalOtherPips += game.gameState.handPipCount(hands[p]!);
          }

          final newScores = <int, int>{};
          for (int p = 1; p <= nPlayers; p++) {
            newScores[p] = game.gameState.scoreOf(p) + (p == playerNum ? totalOtherPips : 0);
          }

          final winnerId = newScores.values.any((s) => s >= targetScore)
              ? game.playerIdOf(playerNum)
              : null;

          if (winnerId != null) {
            updates['status'] = 'finished';
            updates['winnerId'] = winnerId;
            updates['finishedAt'] = FieldValue.serverTimestamp();
            for (int p = 1; p <= nPlayers; p++) {
              updates['gameState.player${p}Score'] = newScores[p];
              updates['gameState.player${p}Hand'] = hands[p];
            }
            updates['gameState.chain'] = chain.map((t) => t.toMap()).toList();
            updates['gameState.leftOpen'] = newLeftOpen;
            updates['gameState.rightOpen'] = newRightOpen;
          } else {
            final nextRoundState = DominoGameState.fromDeal(
              deal: newRoundDeal,
              player1Score: newScores[1]!,
              player2Score: newScores[2]!,
              player3Score: newScores[3] ?? 0,
              player4Score: newScores[4] ?? 0,
              roundNumber: roundNum + 1,
            );
            final newFirstTurn = newRoundDeal['firstTurn'] as String? ?? game.nextTurnAfter(game.currentTurn);
            updates['currentTurn'] = newFirstTurn;
            updates['gameState'] = nextRoundState.toMap();
          }
        } else {
          updates['currentTurn'] = game.nextTurnAfter(game.currentTurn);
          updates['gameState.chain'] = chain.map((t) => t.toMap()).toList();
          updates['gameState.leftOpen'] = newLeftOpen;
          updates['gameState.rightOpen'] = newRightOpen;
          for (int p = 1; p <= nPlayers; p++) {
            updates['gameState.player${p}Hand'] = hands[p];
          }
          updates['gameState.consecutivePasses'] = 0;
        }

        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error playing domino tile: $e');
      return false;
    }
  }

  Future<bool> drawFromBoneyard({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (!game.isActive) return false;
        if (!game.isPlayerTurn(playerId)) return false;

        final boneyard = List<String>.from(game.gameState.boneyard);
        if (boneyard.isEmpty) return false;

        final drawn = boneyard.removeAt(0);
        final playerNum = game.getPlayerNumber(playerId);
        final hand = List<String>.from(game.gameState.handOf(playerNum))..add(drawn);

        transaction.update(gameRef, {
          'gameState.boneyard': boneyard,
          'gameState.player${playerNum}Hand': hand,
        });
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error drawing from boneyard: $e');
      return false;
    }
  }

  Future<bool> passTurn({
    required String gameId,
    required String playerId,
    required Map<String, dynamic> newRoundDeal,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (!game.isActive) return false;
        if (!game.isPlayerTurn(playerId)) return false;

        final nPlayers = game.numberOfPlayers;
        final newPasses = game.gameState.consecutivePasses + 1;
        final Map<String, dynamic> updates = {};

        if (newPasses >= nPlayers) {
          // All players have passed — blocked round
          // Player with lowest pip count wins the round
          final pipCounts = <int, int>{};
          for (int p = 1; p <= nPlayers; p++) {
            pipCounts[p] = game.gameState.handPipCount(game.gameState.handOf(p));
          }
          final minPips = pipCounts.values.reduce((a, b) => a < b ? a : b);
          final roundWinnerNum = pipCounts.entries.firstWhere((e) => e.value == minPips).key;

          // Winner gets sum of all other pips
          int totalOtherPips = 0;
          for (int p = 1; p <= nPlayers; p++) {
            if (p != roundWinnerNum) totalOtherPips += pipCounts[p]!;
          }

          final newScores = <int, int>{};
          for (int p = 1; p <= nPlayers; p++) {
            newScores[p] = game.gameState.scoreOf(p) + (p == roundWinnerNum ? totalOtherPips : 0);
          }

          final isGameOver = newScores.values.any((s) => s >= game.targetScore);

          if (isGameOver) {
            final bestScore = newScores.values.reduce((a, b) => a > b ? a : b);
            final winnerNum = newScores.entries.firstWhere((e) => e.value == bestScore).key;
            updates['status'] = 'finished';
            updates['winnerId'] = game.playerIdOf(winnerNum);
            updates['finishedAt'] = FieldValue.serverTimestamp();
            for (int p = 1; p <= nPlayers; p++) {
              updates['gameState.player${p}Score'] = newScores[p];
            }
          } else {
            final nextRoundState = DominoGameState.fromDeal(
              deal: newRoundDeal,
              player1Score: newScores[1]!,
              player2Score: newScores[2]!,
              player3Score: newScores[3] ?? 0,
              player4Score: newScores[4] ?? 0,
              roundNumber: game.gameState.roundNumber + 1,
            );
            final newFirstTurn = newRoundDeal['firstTurn'] as String? ?? 'player$roundWinnerNum';
            updates['currentTurn'] = newFirstTurn;
            updates['gameState'] = nextRoundState.toMap();
          }
        } else {
          updates['currentTurn'] = game.nextTurnAfter(game.currentTurn);
          updates['gameState.consecutivePasses'] = newPasses;
        }

        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error passing turn: $e');
      return false;
    }
  }

  Future<bool> finishGame({
    required String gameId,
    required String winnerId,
  }) async {
    try {
      await _firestore.collection(_collection).doc(gameId).update({
        'status': 'finished',
        'winnerId': winnerId,
        'finishedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Error finishing domino game: $e');
      return false;
    }
  }

  Future<bool> abandonGame({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(gameId).get();
      if (!doc.exists) return false;

      final game = DominoGameMatch.fromFirestore(doc);
      if (game.status != 'active') return false;

      final winnerId = game.hostId == playerId ? game.guestId : game.hostId;

      await _firestore.collection(_collection).doc(gameId).update({
        'status': 'abandoned',
        'abandonedBy': playerId,
        'winnerId': winnerId,
        'finishedAt': FieldValue.serverTimestamp(),
        'reason': 'abandoned',
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Error abandoning domino game: $e');
      return false;
    }
  }

  Stream<DominoGameMatch?> getGameStream(String gameId) {
    return _firestore
        .collection(_collection)
        .doc(gameId)
        .snapshots()
        .map((s) => s.exists ? DominoGameMatch.fromFirestore(s) : null);
  }

  Stream<List<DominoGameMatch>> getActiveGames(String userId) {
    return _firestore
        .collection(_collection)
        .where('hostId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((hostSnap) async {
      final guestSnap = await _firestore
          .collection(_collection)
          .where('guestId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      final seen = <String>{};
      return [...hostSnap.docs, ...guestSnap.docs]
          .where((d) => seen.add(d.id))
          .map((d) => DominoGameMatch.fromFirestore(d))
          .toList();
    });
  }

  Future<List<DominoGameMatch>> findWaitingGames({
    String? currencyType,
    int numberOfPlayers = 2,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'waiting')
          .where('numberOfPlayers', isEqualTo: numberOfPlayers)
          .limit(20)
          .get();

      final games = snap.docs
          .map((d) => DominoGameMatch.fromFirestore(d))
          .where((g) {
        if (currencyType != null && g.currencyType != currencyType) return false;
        if (g.isFullyJoined) return false;
        return true;
      }).toList();

      games.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return games.take(10).toList();
    } catch (e) {
      if (kDebugMode) print('Error finding domino games: $e');
      return [];
    }
  }
}
