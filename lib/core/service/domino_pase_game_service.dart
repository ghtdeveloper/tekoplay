import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/domino_game_match.dart';

class DominoPaseGameService {
  static final DominoPaseGameService _instance =
      DominoPaseGameService._internal();
  factory DominoPaseGameService() => _instance;
  DominoPaseGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'domino_pase_games';
  final Random _random = Random();

  static int requiredBalance(int betAmount) => betAmount;
  static int commission(int betAmount, int nPlayers) =>
      (requiredBalance(betAmount) * nPlayers * 0.10).ceil();
  static int passValue(int betAmount) => (betAmount * 0.10).ceil();

  Future<Map<String, dynamic>?> createGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required int betAmount,
    required int numberOfPlayers,
    bool isOnlineMatchmaking = false,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc();
      final deal = DominoGameState.initialDeal(_random,
          numberOfPlayers: numberOfPlayers);
      final firstTurn = deal['firstTurn'] as String;
      final state = DominoGameState.fromDeal(deal: deal);

      final match = DominoGameMatch(
        id: gameRef.id,
        gameType: 'DominoPase',
        hostId: hostId,
        hostName: hostName,
        hostPhotoUrl: hostPhotoUrl,
        status: 'waiting',
        currentTurn: firstTurn,
        gameState: state,
        createdAt: DateTime.now(),
        currencyType: 'diamonds',
        betAmount: betAmount,
        hostQuota: betAmount,
        numberOfPlayers: numberOfPlayers,
        targetScore: 0,
        gameSettings: {
          'isOnlineMatchmaking': isOnlineMatchmaking,
          'gameMode': 'pase',
          'firstPlayer': firstTurn,
          'passValue': passValue(betAmount),
          'commissionAmount': commission(betAmount, numberOfPlayers),
          'requiredBalance': requiredBalance(betAmount),
          'passPayments': {
            for (int p = 1; p <= numberOfPlayers; p++)
              'player$p': {'received': 0, 'paid': 0},
          },
        },
      );

      await gameRef.set(match.toFirestore());
      return {'gameId': gameRef.id, 'firstTurn': firstTurn};
    } catch (e) {
      if (kDebugMode) print('Error creating pase game: $e');
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

      final joinResult = await _firestore
          .runTransaction<Map<String, dynamic>?>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return null;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'waiting') return null;
        if (game.hostId == guestId) return null;
        if (game.guestId == guestId ||
            game.guest2Id == guestId ||
            game.guest3Id == guestId) {
          return null;
        }

        final Map<String, dynamic> updates = {};
        String slotField;
        if (game.guestId == null) {
          updates['guestId'] = guestId;
          updates['guestName'] = guestName;
          updates['guestPhotoUrl'] = guestPhotoUrl;
          updates['guestQuota'] = game.betAmount;
          slotField = 'guestId';
        } else if (game.numberOfPlayers >= 3 && game.guest2Id == null) {
            updates['guest2Id'] = guestId;
            updates['guest2Name'] = guestName;
            slotField = 'guest2Id';
        } else if (game.numberOfPlayers >= 4 && game.guest3Id == null) {
          updates['guest3Id'] = guestId;
          updates['guest3Name'] = guestName;
          slotField = 'guest3Id';
        } else {
          return null;
        }

        final newCount = game.currentPlayerCount + 1;
        final willBeActive = newCount >= game.numberOfPlayers;
        if (willBeActive) {
          updates['status'] = 'active';
          updates['startedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(gameRef, updates);
        return {
          'willBeActive': willBeActive,
          'slotField': slotField,
          'betAmount': game.betAmount,
          'numberOfPlayers': game.numberOfPlayers,
        };
      });

      if (joinResult == null) return false;

      return true;
    } catch (e) {
      if (kDebugMode) print('Error joining pase game: $e');
      return false;
    }
  }

  String _nextActiveTurn(DominoGameMatch game, String current) {
    final abandoned = List<String>.from(
        game.gameSettings?['abandonedPlayers'] ?? []);
    final nPlayers = game.numberOfPlayers;
    var next = current;
    for (int i = 0; i < nPlayers; i++) {
      final num = int.parse(next.replaceAll('player', ''));
      final nextNum = (num % nPlayers) + 1;
      next = 'player$nextNum';
      final pid = game.playerIdOf(nextNum);
      if (pid != null && !abandoned.contains(pid)) return next;
    }
    return game.nextTurnAfter(current);
  }

  String _previousActiveTurn(DominoGameMatch game, String current) {
    final abandoned = List<String>.from(
        game.gameSettings?['abandonedPlayers'] ?? []);
    final nPlayers = game.numberOfPlayers;
    var prev = current;
    for (int i = 0; i < nPlayers; i++) {
      final num = int.parse(prev.replaceAll('player', ''));
      final prevNum = ((num - 2) % nPlayers) + 1;
      prev = 'player$prevNum';
      final pid = game.playerIdOf(prevNum);
      if (pid != null && !abandoned.contains(pid)) return prev;
    }
    return current;
  }

  int _activePlayerCount(DominoGameMatch game) {
    final abandoned = List<String>.from(
        game.gameSettings?['abandonedPlayers'] ?? []);
    int count = 0;
    for (int p = 1; p <= game.numberOfPlayers; p++) {
      final pid = game.playerIdOf(p);
      if (pid != null && !abandoned.contains(pid)) count++;
    }
    return count;
  }

  Future<bool> playTile({
    required String gameId,
    required String playerId,
    required String tileId,
    required String side,
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
          if (!game.quotasCollected) {
            final betAmount = game.betAmount ?? 0;
            if (betAmount > 0) {
              final nPlayers = game.numberOfPlayers;
              final required = requiredBalance(betAmount);
              final commissionAmt = commission(betAmount, nPlayers);

              final playerIds = <String>[
                game.hostId,
                if (game.guestId != null) game.guestId!,
                if (game.guest2Id != null) game.guest2Id!,
                if (game.guest3Id != null) game.guest3Id!,
              ];

              final playerDocs = <DocumentSnapshot>[];
              for (final pid in playerIds) {
                playerDocs.add(await transaction
                    .get(_firestore.collection('users').doc(pid)));
              }

              for (int i = 0; i < playerIds.length; i++) {
                final data =
                    playerDocs[i].data() as Map<String, dynamic>?;
                final balance =
                    (data?['diamonds'] as num?)?.toInt() ?? 0;
                if (balance < required) {
                  return false;
                }
              }

              for (int i = 0; i < playerIds.length; i++) {
                transaction.update(playerDocs[i].reference, {
                  'diamonds': FieldValue.increment(-required),
                });
              }

              transaction.update(gameRef, {
                'quotasCollected': true,
                'quotasCollectedAt': FieldValue.serverTimestamp(),
                'totalPot': required * playerIds.length,
                'gameSettings.commissionAmount': commissionAmt,
              });
            }
          }

          final currentHand = game.getHand(playerNum);
          int maxDouble = -1;
          for (final id in currentHand) {
            final t = game.gameState.tiles[id];
            if (t != null && t['left'] == t['right'] && t['left']! > maxDouble) {
              maxDouble = t['left']!;
            }
          }
          if (maxDouble != -1 && !(tl == tr && tl == maxDouble)) {
            return false;
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
        final hands = <int, List<String>>{};
        for (int p = 1; p <= nPlayers; p++) {
          hands[p] =
              p == playerNum ? hand : List<String>.from(game.gameState.handOf(p));
        }

        final Map<String, dynamic> updates = {};

        if (hand.isEmpty) {
          updates['status'] = 'finished';
          updates['winnerId'] = playerId;
          updates['finishedAt'] = FieldValue.serverTimestamp();
        }

        updates['gameState.chain'] = chain.map((t) => t.toMap()).toList();
        updates['gameState.leftOpen'] = newLeftOpen;
        updates['gameState.rightOpen'] = newRightOpen;
        for (int p = 1; p <= nPlayers; p++) {
          updates['gameState.player${p}Hand'] = hands[p];
        }
        updates['gameState.consecutivePasses'] = 0;
        if (game.gameState.chain.isEmpty) {
          updates['gameState.openingTileId'] = tileId;
        }
        if (hand.isNotEmpty) {
          updates['currentTurn'] = _nextActiveTurn(game, game.currentTurn);
        }

        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error playing pase tile: $e');
      return false;
    }
  }


  Future<bool> passTurn({
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

        final nPlayers = game.numberOfPlayers;
        final pNum = game.getPlayerNumber(playerId);
        final betAmount = game.betAmount ?? 0;
        final pValue =
            game.gameSettings?['passValue'] as int? ?? passValue(betAmount);

        final payments =
            Map<String, dynamic>.from(game.gameSettings?['passPayments'] ?? {});

        final abandoned = List<String>.from(
            game.gameSettings?['abandonedPlayers'] ?? []);
        final activePlayers = _activePlayerCount(game);

        final prevTurn = _previousActiveTurn(game, game.currentTurn);
        final prevNum = int.parse(prevTurn.replaceAll('player', ''));

        final prevKey = 'player$prevNum';
        final passerKey = 'player$pNum';

        final prevData =
            Map<String, dynamic>.from(payments[prevKey] ?? {'received': 0, 'paid': 0});
        prevData['received'] = (prevData['received'] as int? ?? 0) + pValue;
        payments[prevKey] = prevData;

        final passerData =
            Map<String, dynamic>.from(payments[passerKey] ?? {'received': 0, 'paid': 0});
        passerData['paid'] = (passerData['paid'] as int? ?? 0) + pValue;
        payments[passerKey] = passerData;

        final newPasses = game.gameState.consecutivePasses + 1;
        final Map<String, dynamic> updates = {
          'gameSettings.passPayments': payments,
        };

        if (newPasses >= activePlayers) {
          final pipCounts = <int, int>{};
          for (int p = 1; p <= nPlayers; p++) {
            final pid = game.playerIdOf(p);
            if (pid != null && abandoned.contains(pid)) continue;
            pipCounts[p] =
                game.gameState.handPipCount(game.gameState.handOf(p));
          }
          final minPips =
              pipCounts.values.reduce((a, b) => a < b ? a : b);
          final tiedPlayers = pipCounts.entries
              .where((e) => e.value == minPips)
              .map((e) => e.key)
              .toList();

          int winnerNum;
          if (tiedPlayers.length == 1) {
            winnerNum = tiedPlayers.first;
          } else {
            final firstPlayerStr =
                game.gameSettings?['firstPlayer'] as String? ?? 'player1';
            final firstNum =
                int.tryParse(firstPlayerStr.replaceAll('player', '')) ?? 1;
            tiedPlayers.sort((a, b) {
              final distA = ((a - firstNum) % nPlayers + nPlayers) % nPlayers;
              final distB = ((b - firstNum) % nPlayers + nPlayers) % nPlayers;
              return distA.compareTo(distB);
            });
            winnerNum = tiedPlayers.first;
          }
          final winnerId = game.playerIdOf(winnerNum);

          updates['status'] = 'finished';
          updates['winnerId'] = winnerId;
          updates['finishedAt'] = FieldValue.serverTimestamp();
          updates['gameState.consecutivePasses'] = newPasses;
        } else {
          updates['currentTurn'] = _nextActiveTurn(game, game.currentTurn);
          updates['gameState.consecutivePasses'] = newPasses;
        }

        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error passing pase turn: $e');
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
      if (kDebugMode) print('Error finishing pase game: $e');
      return false;
    }
  }

  Future<bool> distributeRewards({required String gameId}) async {
    return true;
  }

  Future<bool> abandonGame({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'active' && game.status != 'waiting') return false;

        final playerNum = game.getPlayerNumber(playerId);
        if (playerNum == 0) return false;

        if (game.numberOfPlayers == 2) {
          final winnerId =
              game.hostId == playerId ? game.guestId : game.hostId;
          transaction.update(gameRef, {
            'status': 'abandoned',
            'abandonedBy': playerId,
            'winnerId': winnerId,
            'finishedAt': FieldValue.serverTimestamp(),
            'reason': 'abandoned',
          });
          return true;
        }

        final updates = <String, dynamic>{
          'gameSettings.abandonedPlayers': FieldValue.arrayUnion([playerId]),
        };

        if (game.currentTurn == 'player$playerNum') {
          updates['currentTurn'] = _nextActiveTurn(game, game.currentTurn);
        }

        final abandoned = List<String>.from(
            game.gameSettings?['abandonedPlayers'] ?? []);
        abandoned.add(playerId);
        int activeCount = 0;
        String? lastActiveId;
        for (int p = 1; p <= game.numberOfPlayers; p++) {
          final pid = game.playerIdOf(p);
          if (pid != null && !abandoned.contains(pid)) {
            activeCount++;
            lastActiveId = pid;
          }
        }

        if (activeCount <= 1 && lastActiveId != null) {
          updates['status'] = 'abandoned';
          updates['abandonedBy'] = playerId;
          updates['winnerId'] = lastActiveId;
          updates['finishedAt'] = FieldValue.serverTimestamp();
          updates['reason'] = 'abandoned';
        }

        transaction.update(gameRef, updates);

        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error abandoning pase game: $e');
      return false;
    }
  }


  Future<String?> requestRematch({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<String?>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return null;
        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'finished' && game.status != 'abandoned') {
          return null;
        }

        final playerNum = game.getPlayerNumber(playerId);
        if (playerNum == 0) return null;

        final abandoned = List<String>.from(
            game.gameSettings?['abandonedPlayers'] ?? []);

        final rematch = Map<String, dynamic>.from(
            game.gameSettings?['rematchAccepted'] ?? {});
        rematch['player$playerNum'] = true;

        final nPlayers = game.numberOfPlayers;
        bool allAccepted = true;
        for (int p = 1; p <= nPlayers; p++) {
          final pid = game.playerIdOf(p);
          if (pid != null && abandoned.contains(pid)) continue;
          if (rematch['player$p'] != true) {
            allAccepted = false;
            break;
          }
        }

        final activePlayerIds = <String>[];
        final activeBalances = <String, int>{};
        if (allAccepted) {
          for (int p = 1; p <= nPlayers; p++) {
            final pid = game.playerIdOf(p);
            if (pid != null && !abandoned.contains(pid)) {
              activePlayerIds.add(pid);
            }
          }

          for (final pid in activePlayerIds) {
            final userDoc = await transaction
                .get(_firestore.collection('users').doc(pid));
            final data = userDoc.data();
            final balance = (data?['diamonds'] as num?)?.toInt() ?? 0;
            activeBalances[pid] = balance;
          }
        }

        transaction.update(gameRef, {
          'gameSettings.rematchAccepted': rematch,
        });

        if (!allAccepted) return null;

        final betAmount = game.betAmount ?? 0;
        final required = requiredBalance(betAmount);

        for (final pid in activePlayerIds) {
          if ((activeBalances[pid] ?? 0) < required) {
            transaction.update(gameRef, {
              'gameSettings.rematchFailed': true,
              'gameSettings.rematchFailedPlayer': pid,
            });
            return null;
          }
        }

        return 'CREATE_NEW';
      });
    } catch (e) {
      if (kDebugMode) print('Error requesting rematch: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createRematchGame({
    required DominoGameMatch previousGame,
  }) async {
    try {
      final abandoned = List<String>.from(
          previousGame.gameSettings?['abandonedPlayers'] ?? []);

      final activePlayers = <String, String>{};
      final hostId = previousGame.hostId;
      if (!abandoned.contains(hostId)) {
        activePlayers[hostId] = previousGame.hostName;
      }
      if (previousGame.guestId != null &&
          !abandoned.contains(previousGame.guestId!)) {
        activePlayers[previousGame.guestId!] =
            previousGame.guestName ?? 'Jugador 2';
      }
      if (previousGame.guest2Id != null &&
          !abandoned.contains(previousGame.guest2Id!)) {
        activePlayers[previousGame.guest2Id!] =
            previousGame.guest2Name ?? 'Jugador 3';
      }
      if (previousGame.guest3Id != null &&
          !abandoned.contains(previousGame.guest3Id!)) {
        activePlayers[previousGame.guest3Id!] =
            previousGame.guest3Name ?? 'Jugador 4';
      }

      if (activePlayers.length < 2) return null;

      final activeCount = activePlayers.length;
      final betAmount = previousGame.betAmount ?? 10;

      final newHostId = activePlayers.keys.first;
      final newHostName = activePlayers.values.first;

      final result = await createGame(
        hostId: newHostId,
        hostName: newHostName,
        hostPhotoUrl: newHostId == hostId ? previousGame.hostPhotoUrl : null,
        betAmount: betAmount,
        numberOfPlayers: activeCount,
        isOnlineMatchmaking:
            previousGame.gameSettings?['isOnlineMatchmaking'] == true,
      );

      if (result == null) return null;

      final newGameId = result['gameId'] as String;

      final guests = Map<String, String>.from(activePlayers)
        ..remove(newHostId);

      for (final entry in guests.entries) {
        final success = await joinGame(
          gameId: newGameId,
          guestId: entry.key,
          guestName: entry.value,
        );
        if (!success) return null;
      }

      return result;
    } catch (e) {
      if (kDebugMode) print('Error creating rematch game: $e');
      return null;
    }
  }

  Stream<DominoGameMatch?> getGameStream(String gameId) {
    return _firestore
        .collection(_collection)
        .doc(gameId)
        .snapshots()
        .map((s) => s.exists ? DominoGameMatch.fromFirestore(s) : null);
  }

  Future<List<DominoGameMatch>> findWaitingGames({
    int numberOfPlayers = 3,
    int? betAmount,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'waiting')
          .where('numberOfPlayers', isEqualTo: numberOfPlayers)
          .where('currencyType', isEqualTo: 'diamonds')
          .limit(20)
          .get();

      final cutoff = DateTime.now().subtract(const Duration(minutes: 3));
      final games = snap.docs
          .map((d) => DominoGameMatch.fromFirestore(d))
          .where((g) {
        if (g.isFullyJoined) return false;
        if (g.createdAt.isBefore(cutoff)) return false;
        if (betAmount != null && g.betAmount != betAmount) return false;
        return true;
      }).toList();

      games.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return games.take(10).toList();
    } catch (e) {
      if (kDebugMode) print('Error finding pase games: $e');
      return [];
    }
  }
}
