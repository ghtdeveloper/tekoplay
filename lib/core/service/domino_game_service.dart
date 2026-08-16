import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/domino_game_match.dart';
import 'bot_name_service.dart';

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

      final joinResult = await _firestore.runTransaction<Map<String, dynamic>?>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return null;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'waiting') return null;
        if (game.hostId == guestId) return null;
        if (game.guestId == guestId || game.guest2Id == guestId || game.guest3Id == guestId) return null;

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

        final newPlayerCount = game.currentPlayerCount + 1;
        final willBeActive = newPlayerCount >= game.numberOfPlayers;
        if (willBeActive) {
          updates['status'] = 'active';
          updates['startedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(gameRef, updates);
        return {
          'willBeActive': willBeActive,
          'slotField': slotField,
          'hostId': game.hostId,
          'betAmount': game.betAmount,
          'currencyType': game.currencyType,
        };
      });

      if (joinResult == null) return false;

      final willBeActive = joinResult['willBeActive'] as bool;
      final betAmount = joinResult['betAmount'] as int?;
      final currencyType = joinResult['currencyType'] as String;
      final slotField = joinResult['slotField'] as String;

      if (willBeActive && (betAmount ?? 0) > 0) {
        try {
          await _firestore.runTransaction((transaction) async {
            final doc = await transaction.get(gameRef);
            if (!doc.exists) throw Exception('Game not found');
            final game = DominoGameMatch.fromFirestore(doc);
            if (game.quotasCollected) {
              if (kDebugMode) print('⚠️ Quotas already collected (idempotent)');
              return;
            }

            final playerIds = <String>[
              game.hostId,
              if (game.guestId != null && !game.guestId!.startsWith('bot_')) game.guestId!,
              if (game.guest2Id != null && !game.guest2Id!.startsWith('bot_')) game.guest2Id!,
              if (game.guest3Id != null && !game.guest3Id!.startsWith('bot_')) game.guest3Id!,
            ];

            final field = currencyType == 'coins' ? 'coins' : 'diamonds';

            final playerDocs = <DocumentSnapshot>[];
            for (final pid in playerIds) {
              playerDocs.add(await transaction.get(_firestore.collection('users').doc(pid)));
            }

            for (int i = 0; i < playerIds.length; i++) {
              final data = playerDocs[i].data() as Map<String, dynamic>?;
              final balance = data?[field] ?? 0;
              if (balance < betAmount!) {
                throw Exception('Player ${playerIds[i]} has insufficient funds');
              }
            }

            for (int i = 0; i < playerIds.length; i++) {
              transaction.update(playerDocs[i].reference, {
                field: FieldValue.increment(-betAmount!),
              });
            }

            transaction.update(gameRef, {
              'quotasCollected': true,
              'quotasCollectedAt': FieldValue.serverTimestamp(),
              'totalPot': betAmount! * playerIds.length,
            });
          });
        } catch (e) {
          if (kDebugMode) print('💥 Error collecting quotas: $e');
          await _firestore.runTransaction((transaction) async {
            final doc = await transaction.get(gameRef);
            if (!doc.exists) return;
            final slotValue = doc.data()?[slotField];
            if (slotValue != guestId) return;

            final rollbackUpdates = <String, dynamic>{
              'status': 'waiting',
              'startedAt': null,
              slotField: null,
              slotField.replaceAll('Id', 'Name'): null,
            };
            if (slotField == 'guestId') {
              rollbackUpdates['guestPhotoUrl'] = null;
              rollbackUpdates['guestQuota'] = null;
            }
            transaction.update(gameRef, rollbackUpdates);
          });
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
      final profile = await BotNameService.pickUnseenProfile(_random);
      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'waiting') return false;
        if (game.guestId != null) return false;

        final updates = <String, dynamic>{
          'guestId': 'bot_1',
          'guestName': profile['name'],
          'guestPhotoUrl': null,
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
        };

        final betAmount = game.betAmount ?? 0;
        if (betAmount > 0 && game.currencyType == 'diamonds') {
          Map<String, dynamic>? bestDeal;
          int worstHumanScore = 999999;
          final rng = Random();
          for (int attempt = 0; attempt < 20; attempt++) {
            final deal = DominoGameState.initialDeal(rng, numberOfPlayers: 2);
            final p1Hand = deal['player1Hand'] as List;
            final tiles = deal['tiles'] as Map<String, dynamic>;
            int humanScore = 0;
            int doubles = 0;
            for (final tileId in p1Hand) {
              final t = tiles[tileId] as Map<String, dynamic>;
              final l = (t['left'] as num).toInt();
              final r = (t['right'] as num).toInt();
              humanScore += l + r;
              if (l == r) doubles += 1;
            }
            humanScore += doubles * 15;
            if (humanScore < worstHumanScore) {
              worstHumanScore = humanScore;
              bestDeal = deal;
            }
          }
          if (bestDeal != null) {
            final riggedState = DominoGameState.fromDeal(
              deal: bestDeal,
              player1Score: game.gameState.player1Score,
              player2Score: game.gameState.player2Score,
              roundNumber: game.gameState.roundNumber,
            );
            updates['gameState'] = riggedState.toMap();
            final firstTurn = bestDeal['firstTurn'] as String;
            updates['currentTurn'] = firstTurn != 'player1' ? firstTurn : 'player2';
          }
        }

        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error adding bot: $e');
      return false;
    }
  }


  Future<bool> fillRemainingWithBots(String gameId) async {
    try {
      final profiles = <Map<String, dynamic>>[];
      for (int i = 0; i < 3; i++) {
        profiles.add(await BotNameService.pickUnseenProfile(_random));
      }

      final gameRef = _firestore.collection(_collection).doc(gameId);

      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'waiting') return false;
        if (game.quotasCollected) return false;

        final updates = <String, dynamic>{};
        int botIndex = 1;
        int profileIdx = 0;

        if (game.guestId == null) {
          updates['guestId'] = 'bot_$botIndex';
          updates['guestName'] = profiles[profileIdx]['name'];
          updates['guestPhotoUrl'] = null;
          botIndex++;
          profileIdx++;
        }
        if (game.numberOfPlayers >= 3 && game.guest2Id == null) {
          updates['guest2Id'] = 'bot_$botIndex';
          updates['guest2Name'] = profiles[profileIdx]['name'];
          botIndex++;
          profileIdx++;
        }
        if (game.numberOfPlayers >= 4 && game.guest3Id == null) {
          updates['guest3Id'] = 'bot_$botIndex';
          updates['guest3Name'] = profiles[profileIdx]['name'];
          botIndex++;
        }

        if (updates.isEmpty) return false;

        final betAmount = game.betAmount ?? 0;
        final currencyType = game.currencyType;
        if (betAmount > 0) {
          final realPlayerIds = <String>[
            game.hostId,
            if (game.guestId != null && !game.guestId!.startsWith('bot_')) game.guestId!,
            if (game.guest2Id != null && !game.guest2Id!.startsWith('bot_')) game.guest2Id!,
            if (game.guest3Id != null && !game.guest3Id!.startsWith('bot_')) game.guest3Id!,
          ];

          final field = currencyType == 'coins' ? 'coins' : 'diamonds';

          final playerDocs = <DocumentSnapshot>[];
          for (final pid in realPlayerIds) {
            playerDocs.add(await transaction.get(_firestore.collection('users').doc(pid)));
          }

          for (int i = 0; i < realPlayerIds.length; i++) {
            final data = playerDocs[i].data() as Map<String, dynamic>?;
            final balance = (data?[field] as num?)?.toInt() ?? 0;
            if (balance < betAmount) {
              throw Exception('Player ${realPlayerIds[i]} has insufficient funds');
            }
          }

          for (int i = 0; i < realPlayerIds.length; i++) {
            transaction.update(playerDocs[i].reference, {
              field: FieldValue.increment(-betAmount),
            });
          }

          updates['quotasCollected'] = true;
          updates['quotasCollectedAt'] = FieldValue.serverTimestamp();
          updates['totalPot'] = betAmount * game.numberOfPlayers;
        }


        final afterPlayerIds = <int, String>{
          1: game.hostId,
          2: (updates['guestId'] as String?) ?? game.guestId ?? '',
          3: (updates['guest2Id'] as String?) ?? game.guest2Id ?? '',
          4: (updates['guest3Id'] as String?) ?? game.guest3Id ?? '',
        };
        final nPlayers = game.numberOfPlayers;
        final hasAnyBot = Iterable.generate(nPlayers, (i) => i + 1)
            .any((p) => afterPlayerIds[p]?.startsWith('bot_') == true);
        final isBetMode = (betAmount > 0) && (game.currencyType == 'diamonds');

        if (hasAnyBot && isBetMode) {
          final realPlayerNums = <int>[];
          final botPlayerNums = <int>[];
          for (int p = 1; p <= nPlayers; p++) {
            final pid = afterPlayerIds[p] ?? '';
            if (pid.startsWith('bot_')) {
              botPlayerNums.add(p);
            } else if (pid.isNotEmpty) {
              realPlayerNums.add(p);
            }
          }

          Map<String, dynamic>? bestDeal;
          int bestBotAdvantage = -999999;
          final rng = Random();
          final handKeys = ['', 'player1Hand', 'player2Hand', 'player3Hand', 'player4Hand'];

          for (int attempt = 0; attempt < 20; attempt++) {
            final deal = DominoGameState.initialDeal(rng, numberOfPlayers: nPlayers);
            final tiles = deal['tiles'] as Map<String, dynamic>;

            int botScore = 0;
            int humanScore = 0;

            for (final p in botPlayerNums) {
              final hand = deal[handKeys[p]] as List;
              for (final tileId in hand) {
                final t = tiles[tileId] as Map<String, dynamic>;
                final l = (t['left'] as num).toInt();
                final r = (t['right'] as num).toInt();
                botScore += l + r;
                if (l == r) botScore += 15;
              }
            }
            for (final p in realPlayerNums) {
              final hand = deal[handKeys[p]] as List;
              for (final tileId in hand) {
                final t = tiles[tileId] as Map<String, dynamic>;
                final l = (t['left'] as num).toInt();
                final r = (t['right'] as num).toInt();
                humanScore += l + r;
                if (l == r) humanScore += 15;
              }
            }

            final advantage = botScore - humanScore;
            if (advantage > bestBotAdvantage) {
              bestBotAdvantage = advantage;
              bestDeal = deal;
            }
          }

          if (bestDeal != null) {
            final riggedState = DominoGameState.fromDeal(
              deal: bestDeal,
              player1Score: game.gameState.player1Score,
              player2Score: game.gameState.player2Score,
              player3Score: game.gameState.player3Score,
              player4Score: game.gameState.player4Score,
              roundNumber: game.gameState.roundNumber,
            );
            updates['gameState'] = riggedState.toMap();
            // Force a bot to go first if possible
            final firstTurn = bestDeal['firstTurn'] as String;
            final firstTurnNum = int.tryParse(firstTurn.replaceAll('player', '')) ?? 1;
            if (botPlayerNums.contains(firstTurnNum)) {
              updates['currentTurn'] = firstTurn;
            } else {
              updates['currentTurn'] = 'player${botPlayerNums.first}';
            }
          }
        }

        updates['status'] = 'active';
        updates['startedAt'] = FieldValue.serverTimestamp();
        transaction.update(gameRef, updates);
        return true;
      });
    } catch (e) {
      if (kDebugMode) print('Error filling bots: $e');
      return false;
    }
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
        final roundNum = game.gameState.roundNumber;
        final targetScore = game.targetScore;

        final hands = <int, List<String>>{};
        for (int p = 1; p <= nPlayers; p++) {
          hands[p] = p == playerNum ? hand : List<String>.from(game.gameState.handOf(p));
        }

        final Map<String, dynamic> updates = {};

        if (hand.isEmpty) {
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
            final serverDeal = DominoGameState.initialDeal(_random, numberOfPlayers: nPlayers);
            final nextRoundState = DominoGameState.fromDeal(
              deal: serverDeal,
              player1Score: newScores[1]!,
              player2Score: newScores[2]!,
              player3Score: newScores[3] ?? 0,
              player4Score: newScores[4] ?? 0,
              roundNumber: roundNum + 1,
            );
            final newFirstTurn = serverDeal['firstTurn'] as String? ?? game.nextTurnAfter(game.currentTurn);
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
          if (game.gameState.chain.isEmpty) {
            updates['gameState.openingTileId'] = tileId;
          }
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
          final pipCounts = <int, int>{};
          for (int p = 1; p <= nPlayers; p++) {
            pipCounts[p] = game.gameState.handPipCount(game.gameState.handOf(p));
          }
          final minPips = pipCounts.values.reduce((a, b) => a < b ? a : b);
          final roundWinnerNum = pipCounts.entries.firstWhere((e) => e.value == minPips).key;

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
            final serverDeal = DominoGameState.initialDeal(_random, numberOfPlayers: nPlayers);
            final nextRoundState = DominoGameState.fromDeal(
              deal: serverDeal,
              player1Score: newScores[1]!,
              player2Score: newScores[2]!,
              player3Score: newScores[3] ?? 0,
              player4Score: newScores[4] ?? 0,
              roundNumber: game.gameState.roundNumber + 1,
            );
            final newFirstTurn = serverDeal['firstTurn'] as String? ?? 'player$roundWinnerNum';
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
      final gameRef = _firestore.collection(_collection).doc(gameId);
      return await _firestore.runTransaction<bool>((transaction) async {
        final doc = await transaction.get(gameRef);
        if (!doc.exists) return false;

        final game = DominoGameMatch.fromFirestore(doc);
        if (game.status != 'active') return false;

        final playerNum = game.getPlayerNumber(playerId);
        if (playerNum == 0) return false;

        if (game.numberOfPlayers == 2) {
          final winnerId = game.hostId == playerId ? game.guestId : game.hostId;
          transaction.update(gameRef, {
            'status': 'abandoned',
            'abandonedBy': playerId,
            'winnerId': winnerId,
            'finishedAt': FieldValue.serverTimestamp(),
            'reason': 'abandoned',
          });
          return true;
        }

        bool shouldDeductOnAbandon = !game.quotasCollected && (game.betAmount ?? 0) > 0;
        if (shouldDeductOnAbandon) {
          bool allBotOpponents = true;
          for (int p = 1; p <= game.numberOfPlayers; p++) {
            if (p == playerNum) continue;
            final pid = game.playerIdOf(p);
            if (pid != null && !pid.startsWith('bot_')) {
              allBotOpponents = false;
              break;
            }
          }
          if (allBotOpponents) shouldDeductOnAbandon = false;
        }

        if (shouldDeductOnAbandon) {
          final userRef = _firestore.collection('users').doc(playerId);
          final userDoc = await transaction.get(userRef);
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final currentBalance = game.currencyType == 'coins'
                ? (userData['coins'] as num? ?? 0).toInt()
                : (userData['diamonds'] as num? ?? 0).toInt();
            final newBalance = (currentBalance - game.betAmount!).clamp(0, currentBalance);
            transaction.update(userRef, {game.currencyType: newBalance});
          }
        }

        final botId = 'bot_$playerNum';
        final updates = <String, dynamic>{};

        switch (playerNum) {
          case 1:
            updates['hostId'] = botId;
            updates['hostPhotoUrl'] = null;
            break;
          case 2:
            updates['guestId'] = botId;
            updates['guestPhotoUrl'] = null;
            break;
          case 3:
            updates['guest2Id'] = botId;
            break;
          case 4:
            updates['guest3Id'] = botId;
            break;
        }

        if (game.currentTurn == 'player$playerNum') {
          updates['currentTurn'] = game.nextTurnAfter(game.currentTurn);
        }

        transaction.update(gameRef, updates);
        return true;
      });
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

  Future<DominoGameMatch?> findActiveGameForUser(String userId) async {
    try {
      final futures = [
        _firestore.collection(_collection).where('status', isEqualTo: 'active').where('hostId', isEqualTo: userId).limit(1).get(),
        _firestore.collection(_collection).where('status', isEqualTo: 'active').where('guestId', isEqualTo: userId).limit(1).get(),
        _firestore.collection(_collection).where('status', isEqualTo: 'active').where('guest2Id', isEqualTo: userId).limit(1).get(),
        _firestore.collection(_collection).where('status', isEqualTo: 'active').where('guest3Id', isEqualTo: userId).limit(1).get(),
      ];
      final results = await Future.wait(futures);
      for (final snap in results) {
        if (snap.docs.isNotEmpty) {
          return DominoGameMatch.fromFirestore(snap.docs.first);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error finding active game for user: $e');
      return null;
    }
  }

  Future<List<DominoGameMatch>> findWaitingGames({
    String? currencyType,
    int numberOfPlayers = 2,
    bool? isOnlineMatchmaking,
  }) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'waiting')
          .where('numberOfPlayers', isEqualTo: numberOfPlayers)
          .limit(20)
          .get();

      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      final games = snap.docs
          .map((d) => DominoGameMatch.fromFirestore(d))
          .where((g) {
        if (currencyType != null && g.currencyType != currencyType) return false;
        if (g.isFullyJoined) return false;
        if (g.createdAt.isBefore(cutoff)) return false;
        if (isOnlineMatchmaking != null) {
          final gIsOnline = g.gameSettings?['isOnlineMatchmaking'] == true;
          if (gIsOnline != isOnlineMatchmaking) return false;
        }
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
