import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/game_type.dart';
import '../utils/game_result.dart';

class GameMatch {
  final String id;
  final String userId;
  final GameTypeModel gameType;
  final GameResultModel result;
  final int pointsEarned;
  final int durationMinutes;
  final DateTime playedAt;
  final String? opponentId;
  final String? opponentName;
  final Map<String, dynamic>? additionalData;

  GameMatch({
    required this.id,
    required this.userId,
    required this.gameType,
    required this.result,
    required this.pointsEarned,
    required this.durationMinutes,
    required this.playedAt,
    this.opponentId,
    this.opponentName,
    this.additionalData,
  });

  factory GameMatch.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GameMatch(
      id: doc.id,
      userId: data['userId'] ?? '',
      gameType: GameTypeModel.values.firstWhere(
            (type) => type.id == data['gameType'],
        orElse: () => GameTypeModel.chess,
      ),
      result: GameResultModel.values.firstWhere(
            (result) => result.id == data['result'],
        orElse: () => GameResultModel.loss,
      ),
      pointsEarned: data['pointsEarned'] ?? 0,
      durationMinutes: data['durationMinutes'] ?? 0,
      playedAt: (data['playedAt'] as Timestamp).toDate(),
      opponentId: data['opponentId'],
      opponentName: data['opponentName'],
      additionalData: data['additionalData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'gameType': gameType.id,
      'result': result.id,
      'pointsEarned': pointsEarned,
      'durationMinutes': durationMinutes,
      'playedAt': Timestamp.fromDate(playedAt),
      'opponentId': opponentId,
      'opponentName': opponentName,
      'additionalData': additionalData,
    };
  }
}