import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/multiplayer_game_match_chess.dart';

class OnlineMatchmakingChessService {
  static final OnlineMatchmakingChessService _instance =
  OnlineMatchmakingChessService._internal();

  factory OnlineMatchmakingChessService() => _instance;

  OnlineMatchmakingChessService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<MultiplayerGameMatch>> findWaitingGames({
    required String gameType,
    required int userRanking,
    required int? timeMinutes, int? betAmount,
  }) async {
    try {
      const int maxRankingDifference = 300;

      final query = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameType', isEqualTo: gameType)
          .where('gameSettings.timeMinutes', isEqualTo: timeMinutes)
          .where(
        'gameSettings.hostRanking',
        isGreaterThanOrEqualTo: userRanking - maxRankingDifference,
      )



          .where(
        'gameSettings.hostRanking',
        isLessThanOrEqualTo: userRanking + maxRankingDifference,
      )
          .orderBy('gameSettings.hostRanking')
          .orderBy('createdAt')
          .limit(5)
          .get();

      final games = query.docs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .toList();

      if (games.isNotEmpty) {
        games.sort((a, b) {
          final diffA = ((a.gameSettings!['hostRanking'] as int) - userRanking).abs();
          final diffB = ((b.gameSettings!['hostRanking'] as int) - userRanking).abs();
          return diffA.compareTo(diffB);
        });
      }

      return games;
    } catch (e) {
      print('Error finding waiting games: $e');
      return [];
    }
  }


  Future<List<MultiplayerGameMatch>> findWaitingGamesProgressive({
    required String gameType,
    required int userRanking,
    required int? timeMinutes,
    int searchTimeSeconds = 0,
  }) async {
    try {
      // Rangos progresivos basados en el tiempo de búsqueda
      int rankingRange;
      if (searchTimeSeconds < 15) {
        rankingRange = 100; // Primeros 15 segundos: rango de ±100 puntos
      } else if (searchTimeSeconds < 30) {
        rankingRange = 200; // 15-30 segundos: rango de ±200 puntos
      } else {
        rankingRange = 300; // Después de 30 segundos: rango de ±300 puntos
      }

      final int minRanking = userRanking - rankingRange;
      final int maxRanking = userRanking + rankingRange;

      final query = await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameType', isEqualTo: gameType)
          .where('gameSettings.timeMinutes', isEqualTo: timeMinutes)
          .where(
        'gameSettings.hostRanking',
        isGreaterThanOrEqualTo: minRanking,
      )
          .where(
        'gameSettings.hostRanking',
        isLessThanOrEqualTo: maxRanking,
      )
          .orderBy('gameSettings.hostRanking')
          .orderBy('createdAt')
          .limit(5)
          .get();

      final games = query.docs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .toList();

      if (games.isNotEmpty) {
        games.sort((a, b) {
          final hostRankingA = a.gameSettings!['hostRanking'] as int;
          final hostRankingB = b.gameSettings!['hostRanking'] as int;
          final diffA = (hostRankingA - userRanking).abs();
          final diffB = (hostRankingB - userRanking).abs();
          return diffA.compareTo(diffB);
        });
      }

      return games;
    } catch (e) {
      print('Error finding waiting games progressive: $e');
      return [];
    }
  }

  Future<String?> createOnlineGame({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    required String gameType,
    required int? timeMinutes,
    required int hostRanking,
    int? betAmount, // Agregar este parámetro
  }) async {
    try {
      final gameRef = _firestore.collection('multiplayer_games').doc();

      final game = MultiplayerGameMatch(
        id: gameRef.id,
        gameType: gameType,
        hostId: hostId,
        hostName: hostName,
        hostPhotoUrl: hostPhotoUrl,
        status: 'waiting',
        currentTurn: 'host',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        createdAt: DateTime.now(),
        isRanked: true,
        betAmount: betAmount, // Agregar esto
        gameSettings: {
          'timeMinutes': timeMinutes,
          'hostRanking': hostRanking,
          'isOnlineMatchmaking': true,
          'betAmount': betAmount, // Agregar esto también
        },
      );

      await gameRef.set(game.toFirestore());
      return gameRef.id;
    } catch (e) {
      print('Error creating online game: $e');
      return null;
    }
  }
}