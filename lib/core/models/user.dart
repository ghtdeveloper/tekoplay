import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tekoplay/core/utils/game_result.dart';

import '../utils/game_type.dart';
import 'game_stats.dart';
import 'game_match.dart';

class UserModel {
  final String id;
  final String name;
  final String urlPhoto;
  final String email;
  final DateTime createdAt;
  final int coins;
  final int diamonds;
  final int diamondsEarned;
  final Map<GameTypeModel, GameStats> gameStats;

  UserModel({
    required this.id,
    required this.name,
    required this.urlPhoto,
    required this.email,
    required this.createdAt,
    this.coins = 500,
    this.diamonds = 0,
    this.diamondsEarned = 0,
    Map<GameTypeModel, GameStats>? gameStats,
  }) : gameStats = gameStats ?? _initializeGameStats();

  static Map<GameTypeModel, GameStats> _initializeGameStats() {
    Map<GameTypeModel, GameStats> stats = {};
    for (GameTypeModel gameType in GameTypeModel.values) {
      stats[gameType] = GameStats.initial(gameType);
    }
    return stats;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<GameTypeModel, GameStats> gameStats = {};
    Map<String, dynamic>? gameStatsData = data['gameStats'];

    for (GameTypeModel gameType in GameTypeModel.values) {
      if (gameStatsData != null && gameStatsData.containsKey(gameType.id)) {
        gameStats[gameType] = GameStats.fromFirestore(
          gameStatsData[gameType.id],
          gameType,
        );
      } else {
        gameStats[gameType] = GameStats.initial(gameType);
      }
    }

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      urlPhoto: data['urlPhoto']??'',
      email: data['email']??'',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      coins: data['coins'] ?? 500,
      diamonds: data['diamonds'] ?? 25,
      diamondsEarned: data['diamondsEarned'] ?? 25,
      gameStats: gameStats,
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> gameStatsData = {};
    gameStats.forEach((gameType, stats) {
      gameStatsData[gameType.id] = stats.toFirestore();
    });

    return {
      'name': name,
      'urlPhoto':urlPhoto,
      'email':email,
      'createdAt': Timestamp.fromDate(createdAt),
      'coins': coins,
      'diamonds': diamonds,
      'diamondsEarned': diamondsEarned,
      'gameStats': gameStatsData,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? urlPhoto,
    String? email,
    DateTime? createdAt,
    int? coins,
    int? diamonds,
    int? diamondsEarned,
    Map<GameTypeModel, GameStats>? gameStats,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      urlPhoto: urlPhoto ?? this.urlPhoto,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      diamondsEarned: diamondsEarned ?? this.diamondsEarned,
      gameStats: gameStats ?? this.gameStats,
    );
  }

  int get totalPoints {
    return gameStats.values.fold(0, (sum, stats) => sum + stats.points);
  }

  GameStats getGameStats(GameTypeModel gameType) {
    return gameStats[gameType] ?? GameStats.initial(gameType);
  }

  UserModel updateAfterMatch(GameMatch match) {
    final currentStats = getGameStats(match.gameType);
    final updatedStats = currentStats.copyWith(
      points: currentStats.points + match.pointsEarned,
      gamesPlayed: currentStats.gamesPlayed + 1,
      wins:
          match.result == GameResultModel.win
              ? currentStats.wins + 1
              : currentStats.wins,
      losses:
          match.result == GameResultModel.loss
              ? currentStats.losses + 1
              : currentStats.losses,
      draws:
          match.result == GameResultModel.draw
              ? currentStats.draws + 1
              : currentStats.draws,
      totalPlayTimeMinutes:
          currentStats.totalPlayTimeMinutes + match.durationMinutes,
      lastPlayed: match.playedAt,
    );

    final newGameStats = Map<GameTypeModel, GameStats>.from(gameStats);
    newGameStats[match.gameType] = updatedStats;

    return copyWith(gameStats: newGameStats);
  }
}
