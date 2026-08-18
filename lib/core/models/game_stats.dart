import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/game_type.dart';

class GameStats {
  final GameTypeModel gameType;
  final int points;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int totalPlayTimeMinutes;
  final DateTime lastPlayed;

  GameStats({
    required this.gameType,
    this.points = 0,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalPlayTimeMinutes = 0,
    DateTime? lastPlayed,
  }) : lastPlayed = lastPlayed ?? DateTime.now();

  static int getInitialPoints(GameTypeModel gameType) {
    switch (gameType) {
      case GameTypeModel.chess:
        return 1000;
      case GameTypeModel.domino:
        return 1000;
      case GameTypeModel.ludo:
        return 1000;
      case GameTypeModel.dominoPase:
        return 1000;
    }
  }

  factory GameStats.initial(GameTypeModel gameType) {
    return GameStats(
      gameType: gameType,
      points: getInitialPoints(gameType),
      lastPlayed: DateTime.now(),
    );
  }

  factory GameStats.fromFirestore(
    Map<String, dynamic> data,
    GameTypeModel gameType,
  ) {
    return GameStats(
      gameType: gameType,
      points: data['points'] ?? getInitialPoints(gameType),
      gamesPlayed: data['gamesPlayed'] ?? 0,
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      draws: data['draws'] ?? 0,
      totalPlayTimeMinutes: data['totalPlayTimeMinutes'] ?? 0,
      lastPlayed:
          data['lastPlayed'] != null
              ? (data['lastPlayed'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'points': points,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'totalPlayTimeMinutes': totalPlayTimeMinutes,
      'lastPlayed': Timestamp.fromDate(lastPlayed),
    };
  }

  GameStats copyWith({
    int? points,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    int? coinsEarned,
    int? diamondsEarned,
    int? totalPlayTimeMinutes,
    DateTime? lastPlayed,
  }) {
    return GameStats(
      gameType: gameType,
      points: points ?? this.points,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalPlayTimeMinutes: totalPlayTimeMinutes ?? this.totalPlayTimeMinutes,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  double get winRate {
    if (gamesPlayed == 0) return 0.0;
    return (wins / gamesPlayed) * 100;
  }

  double get averageGameTimeMinutes {
    if (gamesPlayed == 0) return 0.0;
    return totalPlayTimeMinutes / gamesPlayed;
  }
}
