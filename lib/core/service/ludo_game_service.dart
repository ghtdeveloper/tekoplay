import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ludo_game_match.dart';

class LudoGameService {
  static final LudoGameService _instance = LudoGameService._internal();
  factory LudoGameService() => _instance;
  LudoGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _gamesCollection = 'ludo_games';
  final Random _random = Random();

  /// Crea una nueva partida de Ludo
  Future<String?> createGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required String currencyType,
    int? betAmount,
    int numberOfPlayers = 4, // 2, 3 o 4 jugadores
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

      // Asignar colores aleatoriamente
      final colors = ['red', 'blue', 'green', 'yellow'];
      colors.shuffle(_random);

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
        betAmount: betAmount,
        gameSettings: {
          'numberOfPlayers': numberOfPlayers,
          'isOnlineMatchmaking': isOnlineMatchmaking,
          'hostRanking': 1000, // Se actualizará con el ranking real
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

  /// Unirse a una partida existente
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

      // Verificar si hay espacio
      if (game.playerCount >= 4) return false;
      if (game.hostId == playerId) return false;

      // Determinar qué slot de jugador usar
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

      // Verificar si se completa el número de jugadores esperado
      final expectedPlayers = game.gameSettings?['numberOfPlayers'] ?? 4;
      final newPlayerCount = game.playerCount + 1;

      if (newPlayerCount >= expectedPlayers) {
        updates['status'] = 'active';
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      await gameRef.update(updates);

      if (kDebugMode) {
        print('✅ Jugador unido al juego Ludo: $playerName');
        print('   Posición: player$playerNumber');
        print('   Jugadores actuales: $newPlayerCount/$expectedPlayers');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error uniéndose al juego Ludo: $e');
      }
      return false;
    }
  }

  /// Tirar el dado
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

        // Verificar que es el turno del jugador
        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        // Verificar que puede tirar el dado
        if (!game.gameState.canRollDice) {
          throw Exception('Cannot roll dice');
        }

        // Tirar el dado
        final diceRoll = _random.nextInt(6) + 1;

        // Actualizar contador de 6s consecutivos
        int newConsecutiveSixes = game.gameState.consecutiveSixes;
        if (diceRoll == 6) {
          newConsecutiveSixes++;
        } else {
          newConsecutiveSixes = 0;
        }

        // Si son 3 seises consecutivos, pierde el turno
        bool skipTurn = newConsecutiveSixes >= 3;

        Map<String, dynamic> updates = {
          'gameState.lastDiceRoll': diceRoll,
          'gameState.canRollDice': false,
          'gameState.consecutiveSixes': skipTurn ? 0 : newConsecutiveSixes,
        };

        if (skipTurn) {
          // Pasar al siguiente jugador
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

  /// Mover una ficha
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

        // Verificar turno
        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        final pieces = game.gameState.getPiecesByColor(playerColor);
        if (pieceId >= pieces.length) throw Exception('Invalid piece');

        final piece = pieces[pieceId];
        final diceRoll = game.gameState.lastDiceRoll;

        if (diceRoll == 0) throw Exception('Must roll dice first');

        // Calcular nueva posición
        int newPosition = piece.position;

        if (piece.isHome) {
          // Sacar de casa solo con 6
          if (diceRoll == 6) {
            newPosition = _getStartPosition(playerColor);
          } else {
            throw Exception('Need 6 to leave home');
          }
        } else {
          newPosition = piece.position + diceRoll;

          // Verificar si llega a la meta
          final homeStretchStart = _getHomeStretchStart(playerColor);
          if (piece.position >= homeStretchStart) {
            // Ya está en la recta final
            if (newPosition > 57) {
              throw Exception('Exact roll needed to finish');
            }
          } else if (newPosition >= homeStretchStart) {
            // Entra en la recta final
            newPosition = homeStretchStart + (newPosition - homeStretchStart);
          }
        }

        // Verificar si captura una ficha
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
              // Enviar ficha capturada a casa
              otherPiece.position = -1;
              break;
            }
          }
        }

        // Actualizar posición
        piece.position = newPosition;
        if (newPosition >= 57) {
          piece.isFinished = true;
        }

        // Crear movimiento
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

        // Actualizar estado del juego
        final newGameState = game.gameState;
        final moveHistory = [...game.moveHistory, move];

        Map<String, dynamic> updates = {
          'gameState': newGameState.toMap(),
          'moveHistory': moveHistory.map((m) => m.toMap()).toList(),
          'gameState.lastDiceRoll': 0,
        };

        // Determinar siguiente turno
        // Si sacó 6 o capturó, tira de nuevo
        if (diceRoll == 6 || captured) {
          updates['gameState.canRollDice'] = true;
        } else {
          updates['currentTurn'] = _getNextPlayer(game);
          updates['gameState.canRollDice'] = true;
          updates['gameState.consecutiveSixes'] = 0;
        }

        // Verificar si el jugador ganó
        final allFinished = pieces.every((p) => p.isFinished);
        if (allFinished) {
          final finishedPlayers = [...game.finishedPlayers, playerId];
          updates['finishedPlayers'] = finishedPlayers;

          // Si es el primer jugador en terminar, es el ganador
          if (finishedPlayers.length == 1) {
            updates['winnerId'] = playerId;
          }

          // Si todos menos uno terminaron, el juego termina
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

  /// Obtener stream de una partida
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

  /// Abandonar partida
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

      await gameRef.update({
        'status': 'abandoned',
        'abandonedBy': playerId,
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

  /// Helpers

  String _getNextPlayer(LudoGameMatch game) {
    final currentPlayerNum = int.parse(game.currentTurn.replaceAll('player', ''));
    int nextPlayerNum = currentPlayerNum + 1;

    // Buscar el siguiente jugador activo
    while (nextPlayerNum <= 4) {
      if (game.getPlayerIdByNumber(nextPlayerNum) != null) {
        return 'player$nextPlayerNum';
      }
      nextPlayerNum++;
    }

    // Volver al primer jugador
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
    // Posiciones seguras en el tablero de Ludo
    final safePositions = [0, 8, 13, 21, 26, 34, 39, 47];
    return safePositions.contains(position);
  }

  /// Buscar partidas disponibles para matchmaking
  Future<List<LudoGameMatch>> findWaitingGames({
    required int numberOfPlayers,
  }) async {
    try {
      final query = await _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'waiting')
          .where('gameSettings.numberOfPlayers', isEqualTo: numberOfPlayers)
          .orderBy('createdAt', descending: false)
          .limit(10)
          .get();

      return query.docs
          .map((doc) => LudoGameMatch.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error finding waiting games: $e');
      }
      return [];
    }
  }
}