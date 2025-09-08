
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
    required int? timeMinutes,
  }) async {
    try {
      final query =
      await _firestore
          .collection('multiplayer_games')
          .where('status', isEqualTo: 'waiting')
          .where('gameType', isEqualTo: gameType)
          .where('gameSettings.timeMinutes', isEqualTo: timeMinutes)
          .where(
        'gameSettings.hostRanking',
        isGreaterThanOrEqualTo: userRanking - 20,
      )
          .where(
        'gameSettings.hostRanking',
        isLessThanOrEqualTo: userRanking + 20,
      )
          .limit(1)
          .get();

      return query.docs
          .map((doc) => MultiplayerGameMatch.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error finding waiting games: $e');
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
        gameSettings: {
          'timeMinutes': timeMinutes,
          'hostRanking': hostRanking,
          'isOnlineMatchmaking': true,
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