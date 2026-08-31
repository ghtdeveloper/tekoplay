import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ludo_game_match.dart';
import 'bot_name_service.dart';
import 'game_quota_service.dart';

class LudoGameService {
  static final LudoGameService _instance = LudoGameService._internal();
  factory LudoGameService() => _instance;
  LudoGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _gamesCollection = 'ludo_games';
  final Random _random = Random();

  Future<String?> createGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required String currencyType,
    int? betAmount,
    int numberOfPlayers = 4,
    bool isOnlineMatchmaking = false,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc();

      int quotaAmount = 0;
      if (betAmount != null) {
        quotaAmount = betAmount;
      } else {
        quotaAmount = currencyType == 'diamonds' ? 25 : 100;
      }

      List<String> colors;
      if (numberOfPlayers == 2) {
        final oppositePairs = [['red', 'yellow'], ['blue', 'green']];
        colors = List<String>.from(oppositePairs[_random.nextInt(2)])..shuffle(_random);
      } else {
        const ccwOrder = ['green', 'red', 'blue', 'yellow'];
        final startIdx = _random.nextInt(4);
        colors = List.generate(numberOfPlayers, (i) => ccwOrder[(startIdx + i) % 4]);
      }

      final game = LudoGameMatch(
        id: gameRef.id,
        gameType: 'Ludo',
        hostId: hostId,
        hostName: hostName,
        hostPhotoUrl: hostPhotoUrl,
        status: 'waiting',
        currentTurn: 'player1',
        gameState: LudoGameState.initial(),
        moveHistory: [],
        createdAt: DateTime.now(),
        currencyType: currencyType,
        player1Quota: quotaAmount,
        player1Color: colors[0],
        player2Color: numberOfPlayers >= 2 ? colors[1] : null,
        player3Color: numberOfPlayers >= 3 ? colors[2] : null,
        player4Color: numberOfPlayers == 4 ? colors[3] : null,
        betAmount: quotaAmount,
        gameSettings: {
          'numberOfPlayers': numberOfPlayers,
          'isOnlineMatchmaking': isOnlineMatchmaking,
          'hostRanking': 1000,
        },
      );

      await gameRef.set(game.toFirestore());

      if (kDebugMode) {
        print('✅ Juego Ludo creado: ${gameRef.id}');
        print('   Jugadores: $numberOfPlayers');
        print('   Apuesta: $betAmount');
        print('   Moneda: $currencyType');
      }

      return gameRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error creando juego Ludo: $e');
      }
      return null;
    }
  }

  Future<bool> joinGame({
    required String gameId,
    required String playerId,
    required String playerName,
    String? playerPhotoUrl,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = LudoGameMatch.fromFirestore(gameDoc);

      if (game.status != 'waiting') return false;
      if (game.playerCount >= 4) return false;
      if (game.hostId == playerId) return false;

      Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      int playerNumber = 0;
      if (game.guest2Id == null) {
        updates['guest2Id'] = playerId;
        updates['guest2Name'] = playerName;
        updates['guest2PhotoUrl'] = playerPhotoUrl;
        updates['player2Quota'] = game.player1Quota;
        playerNumber = 2;
      } else if (game.guest3Id == null) {
        updates['guest3Id'] = playerId;
        updates['guest3Name'] = playerName;
        updates['guest3PhotoUrl'] = playerPhotoUrl;
        updates['player3Quota'] = game.player1Quota;
        playerNumber = 3;
      } else if (game.guest4Id == null) {
        updates['guest4Id'] = playerId;
        updates['guest4Name'] = playerName;
        updates['guest4PhotoUrl'] = playerPhotoUrl;
        updates['player4Quota'] = game.player1Quota;
        playerNumber = 4;
      }

      if (playerNumber == 0) return false;

      final expectedPlayers = game.gameSettings?['numberOfPlayers'] ?? 4;
      final newPlayerCount = game.playerCount + 1;

      if (newPlayerCount >= expectedPlayers) {
        updates['status'] = 'active';
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      await gameRef.update(updates);

      final isBetGame = (game.betAmount ?? 0) > 0 && newPlayerCount >= expectedPlayers;
      if (isBetGame) {
        final updatedDoc = await gameRef.get();
        final updatedGame = LudoGameMatch.fromFirestore(updatedDoc);
        final allPlayerIds = <String>[
          updatedGame.hostId,
          if (updatedGame.guest2Id != null) updatedGame.guest2Id!,
          if (updatedGame.guest3Id != null) updatedGame.guest3Id!,
          if (updatedGame.guest4Id != null) updatedGame.guest4Id!,
        ];

        final quotaService = GameQuotaService();
        final result = await quotaService.collectMultiPlayerQuotas(
          gameId: gameId,
          playerIds: allPlayerIds,
          quotaAmount: game.betAmount!,
          currencyType: game.currencyType,
        );

        if (result['success'] != true) {
          final rollback = <String, dynamic>{
            'status': 'waiting',
            'startedAt': null,
          };
          if (playerNumber == 2) {
            rollback['guest2Id'] = null;
            rollback['guest2Name'] = null;
            rollback['guest2PhotoUrl'] = null;
            rollback['player2Quota'] = null;
          } else if (playerNumber == 3) {
            rollback['guest3Id'] = null;
            rollback['guest3Name'] = null;
            rollback['guest3PhotoUrl'] = null;
            rollback['player3Quota'] = null;
          } else if (playerNumber == 4) {
            rollback['guest4Id'] = null;
            rollback['guest4Name'] = null;
            rollback['guest4PhotoUrl'] = null;
            rollback['player4Quota'] = null;
          }
          await gameRef.update(rollback);
          if (kDebugMode) print('Fallo al cobrar cuotas Ludo: ${result['error']}');
          return false;
        }
      }

      if (kDebugMode) {
        print('✅ Jugador unido al juego Ludo: $playerName');
        print('   Posición: player$playerNumber');
        print('   Jugadores actuales: $newPlayerCount/$expectedPlayers');
        if (isBetGame) print('   Cuotas cobradas: ${game.betAmount} ${game.currencyType} c/u');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error uniéndose al juego Ludo: $e');
      }
      return false;
    }
  }

  Future<bool> fillBotsAndStart(String gameId) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();
      if (!gameDoc.exists) return false;

      final game = LudoGameMatch.fromFirestore(gameDoc);
      if (game.status != 'waiting') return false;

      final expectedPlayers = game.gameSettings?['numberOfPlayers'] ?? 4;
      final Map<String, dynamic> updates = {
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      };

      final rng = Random();
      int botNum = 1;
      if (game.guest2Id == null && expectedPlayers >= 2) {
        final p = await BotNameService.pickUnseenProfile(rng);
        updates['guest2Id'] = 'bot_$botNum';
        updates['guest2Name'] = p['name'];
        botNum++;
      }
      if (game.guest3Id == null && expectedPlayers >= 3) {
        final p = await BotNameService.pickUnseenProfile(rng);
        updates['guest3Id'] = 'bot_$botNum';
        updates['guest3Name'] = p['name'];
        botNum++;
      }
      if (game.guest4Id == null && expectedPlayers >= 4) {
        final p = await BotNameService.pickUnseenProfile(rng);
        updates['guest4Id'] = 'bot_$botNum';
        updates['guest4Name'] = p['name'];
        botNum++;
      }

      await gameRef.update(updates);

      final isBetGame = (game.betAmount ?? 0) > 0;
      if (isBetGame) {
        final updatedDoc = await gameRef.get();
        final updatedGame = LudoGameMatch.fromFirestore(updatedDoc);
        final allPlayerIds = <String>[
          updatedGame.hostId,
          if (updatedGame.guest2Id != null) updatedGame.guest2Id!,
          if (updatedGame.guest3Id != null) updatedGame.guest3Id!,
          if (updatedGame.guest4Id != null) updatedGame.guest4Id!,
        ];

        final quotaService = GameQuotaService();
        final result = await quotaService.collectMultiPlayerQuotas(
          gameId: gameId,
          playerIds: allPlayerIds,
          quotaAmount: game.betAmount!,
          currencyType: game.currencyType,
        );

        if (result['success'] != true) {
          if (kDebugMode) print('Fallo al cobrar cuotas en fillBotsAndStart: ${result['error']}');
        }
      }

      if (kDebugMode) print('Bots añadidos al juego $gameId, partida iniciada');
      return true;
    } catch (e) {
      if (kDebugMode) print('Error añadiendo bots: $e');
      return false;
    }
  }


  Future<bool> finishGame({
    required String gameId,
    required String winnerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();
      if (!gameDoc.exists) return false;

      await gameRef.update({
        'status': 'finished',
        'winnerId': winnerId,
        'result': 'win',
        'finishedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ [Ludo] Juego finalizado: $gameId');
        print('   Ganador: $winnerId');
        print('   Cloud Function distribuirá las recompensas automáticamente');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('💥 Error finalizando juego Ludo: $e');
      return false;
    }
  }

  Future<int?> rollDice({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      return await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) throw Exception('Game not found');

        final game = LudoGameMatch.fromFirestore(gameDoc);

        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        if (!game.gameState.canRollDice) {
          throw Exception('Cannot roll dice');
        }

        final diceRoll = _random.nextInt(6) + 1;

        int newConsecutiveSixes = game.gameState.consecutiveSixes;
        if (diceRoll == 6) {
          newConsecutiveSixes++;
        } else {
          newConsecutiveSixes = 0;
        }

        bool skipTurn = newConsecutiveSixes >= 3;

        Map<String, dynamic> updates = {
          'gameState.lastDiceRoll': diceRoll,
          'gameState.canRollDice': false,
          'gameState.consecutiveSixes': skipTurn ? 0 : newConsecutiveSixes,
        };

        if (skipTurn) {
          updates['currentTurn'] = _getNextPlayer(game);
          updates['gameState.canRollDice'] = true;
        }

        transaction.update(gameRef, updates);

        return diceRoll;
      });
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error tirando el dado: $e');
      }
      return null;
    }
  }

  Future<bool> movePiece({
    required String gameId,
    required String playerId,
    required int pieceId,
    required String playerColor,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      return await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) throw Exception('Game not found');

        final game = LudoGameMatch.fromFirestore(gameDoc);

        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        final pieces = game.gameState.getPiecesByColor(playerColor);
        if (pieceId >= pieces.length) throw Exception('Invalid piece');

        final piece = pieces[pieceId];
        final diceRoll = game.gameState.lastDiceRoll;

        if (diceRoll == 0) throw Exception('Must roll dice first');

        int newPosition = piece.position;

        if (piece.isHome) {
          if (diceRoll == 6) {
            newPosition = _getStartPosition(playerColor);
          } else {
            throw Exception('Need 6 to leave home');
          }
        } else {
          newPosition = piece.position + diceRoll;

          final homeStretchStart = _getHomeStretchStart(playerColor);
          if (piece.position >= homeStretchStart) {
            if (newPosition > 57) {
              throw Exception('Exact roll needed to finish');
            }
          } else if (newPosition >= homeStretchStart) {
            newPosition = homeStretchStart + (newPosition - homeStretchStart);
          }
        }

        bool captured = false;
        String? capturedColor;

        if (!_isSafePosition(newPosition)) {
          final allPieces = [
            ...game.gameState.redPieces,
            ...game.gameState.bluePieces,
            ...game.gameState.greenPieces,
            ...game.gameState.yellowPieces,
          ];

          for (final otherPiece in allPieces) {
            if (otherPiece.color != playerColor &&
                otherPiece.position == newPosition &&
                !otherPiece.isHome &&
                !otherPiece.isFinished) {
              captured = true;
              capturedColor = otherPiece.color;
              otherPiece.position = -1;
              break;
            }
          }
        }

        piece.position = newPosition;
        if (newPosition >= 57) {
          piece.isFinished = true;
        }

        final move = LudoMove(
          diceRoll: diceRoll,
          playerColor: playerColor,
          pieceId: pieceId,
          fromPosition: piece.position - diceRoll,
          toPosition: newPosition,
          capturedOpponent: captured,
          capturedColor: capturedColor,
          timestamp: DateTime.now(),
        );

        final newGameState = game.gameState;
        final moveHistory = [...game.moveHistory, move];

        Map<String, dynamic> updates = {
          'gameState': newGameState.toMap(),
          'moveHistory': moveHistory.map((m) => m.toMap()).toList(),
          'gameState.lastDiceRoll': 0,
        };

        if (diceRoll == 6 || captured) {
          updates['gameState.canRollDice'] = true;
        } else {
          updates['currentTurn'] = _getNextPlayer(game);
          updates['gameState.canRollDice'] = true;
          updates['gameState.consecutiveSixes'] = 0;
        }

        final allFinished = pieces.every((p) => p.isFinished);
        if (allFinished) {
          final finishedPlayers = [...game.finishedPlayers, playerId];
          updates['finishedPlayers'] = finishedPlayers;

          if (finishedPlayers.length == 1) {
            updates['winnerId'] = playerId;
          }

          if (finishedPlayers.length >= game.playerCount - 1) {
            updates['status'] = 'finished';
            updates['finishedAt'] = FieldValue.serverTimestamp();
          }
        }

        transaction.update(gameRef, updates);

        return true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error moviendo ficha: $e');
      }
      return false;
    }
  }

  Stream<LudoGameMatch?> getGameStream(String gameId) {
    return _firestore
        .collection(_gamesCollection)
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return LudoGameMatch.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<bool> abandonGame({
    required String gameId,
    required String playerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = LudoGameMatch.fromFirestore(gameDoc);

      if (game.status != 'active') return false;

      String? winnerId;
      final activePlayers = [
        game.hostId,
        if (game.guest2Id != null) game.guest2Id!,
        if (game.guest3Id != null) game.guest3Id!,
        if (game.guest4Id != null) game.guest4Id!,
      ].where((id) => id != playerId).toList();

      if (activePlayers.length == 1) {
        winnerId = activePlayers.first;
      }

      if (kDebugMode) {
        print('🚪 Abandonando juego Ludo: $gameId');
        print('   Abandonado por: $playerId');
        print('   Ganador determinado: $winnerId');
        print('   Moneda: ${game.currencyType}');
        print('   Apuesta: ${game.betAmount}');
      }

      await gameRef.update({
        'status': 'abandoned',
        'abandonedBy': playerId,
        'winnerId': winnerId,
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


  String _getNextPlayer(LudoGameMatch game) {
    final currentPlayerNum = int.parse(game.currentTurn.replaceAll('player', ''));
    int nextPlayerNum = currentPlayerNum + 1;

    while (nextPlayerNum <= 4) {
      if (game.getPlayerIdByNumber(nextPlayerNum) != null) {
        return 'player$nextPlayerNum';
      }
      nextPlayerNum++;
    }

    return 'player1';
  }

  int _getStartPosition(String color) {
    switch (color) {
      case 'red':
        return 0;
      case 'blue':
        return 13;
      case 'yellow':
        return 26;
      case 'green':
        return 39;
      default:
        return 0;
    }
  }

  int _getHomeStretchStart(String color) {
    switch (color) {
      case 'red':
        return 51;
      case 'blue':
        return 12;
      case 'yellow':
        return 25;
      case 'green':
        return 38;
      default:
        return 51;
    }
  }

  bool _isSafePosition(int position) {
    final safePositions = [0, 8, 13, 21, 26, 34, 39, 47];
    return safePositions.contains(position);
  }

  Stream<List<LudoGameMatch>> getActiveGames(String userId) {
    return _firestore
        .collection(_gamesCollection)
        .where('hostId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((hostSnapshot) async {
          final guest2Snapshot = await _firestore
              .collection(_gamesCollection)
              .where('guest2Id', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .get();

          final seen = <String>{};
          final allDocs = [...hostSnapshot.docs, ...guest2Snapshot.docs];
          return allDocs
              .where((doc) => seen.add(doc.id))
              .map((doc) => LudoGameMatch.fromFirestore(doc))
              .toList();
        });
  }

  Future<List<LudoGameMatch>> findWaitingGames({
    required int numberOfPlayers,
    String? currencyType,
  }) async {
    try {
      var query = _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'waiting')
          .limit(20);

      final snapshot = await query.get();
      final results = snapshot.docs
          .map((doc) => LudoGameMatch.fromFirestore(doc))
          .where((g) {
            if ((g.gameSettings?['numberOfPlayers'] ?? 4) != numberOfPlayers) return false;
            if (currencyType != null && g.currencyType != currencyType) return false;
            return true;
          })
          .toList();

      results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return results.take(10).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error finding waiting games: $e');
      }
      return [];
    }
  }
}