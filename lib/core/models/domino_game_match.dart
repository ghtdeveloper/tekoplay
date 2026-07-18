import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DominoChainTile {
  final String id;
  final int displayLeft;
  final int displayRight;
  bool get isDouble => displayLeft == displayRight;

  DominoChainTile({
    required this.id,
    required this.displayLeft,
    required this.displayRight,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayLeft': displayLeft,
        'displayRight': displayRight,
      };

  factory DominoChainTile.fromMap(Map<String, dynamic> map) {
    return DominoChainTile(
      id: map['id'] as String,
      displayLeft: (map['displayLeft'] as num).toInt(),
      displayRight: (map['displayRight'] as num).toInt(),
    );
  }
}

class DominoGameState {
  final List<DominoChainTile> chain;
  final int? leftOpen;
  final int? rightOpen;
  final List<String> player1Hand;
  final List<String> player2Hand;
  final List<String> player3Hand;
  final List<String> player4Hand;
  final List<String> boneyard;
  final Map<String, Map<String, int>> tiles;
  final int player1Score;
  final int player2Score;
  final int player3Score;
  final int player4Score;
  final int roundNumber;
  final int consecutivePasses;

  DominoGameState({
    required this.chain,
    this.leftOpen,
    this.rightOpen,
    required this.player1Hand,
    required this.player2Hand,
    this.player3Hand = const [],
    this.player4Hand = const [],
    required this.boneyard,
    required this.tiles,
    this.player1Score = 0,
    this.player2Score = 0,
    this.player3Score = 0,
    this.player4Score = 0,
    this.roundNumber = 1,
    this.consecutivePasses = 0,
  });

  static Map<String, dynamic> _buildInitialDeal(Random rng, {int numberOfPlayers = 2}) {
    final allTiles = <String, Map<String, int>>{};
    final allIds = <String>[];
    int idx = 0;
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        final id = 'tile_$idx';
        allTiles[id] = {'left': i, 'right': j};
        allIds.add(id);
        idx++;
      }
    }
    allIds.shuffle(rng);

    final hands = <String, List<String>>{};
    for (int p = 1; p <= numberOfPlayers; p++) {
      hands['player${p}Hand'] = allIds.sublist((p - 1) * 7, p * 7);
    }
    final boneyard = allIds.sublist(numberOfPlayers * 7);

    String? firstTurn;
    int highestDouble = -1;
    for (int p = 1; p <= numberOfPlayers; p++) {
      for (final id in hands['player${p}Hand']!) {
        final t = allTiles[id]!;
        if (t['left'] == t['right'] && t['left']! > highestDouble) {
          highestDouble = t['left']!;
          firstTurn = 'player$p';
        }
      }
    }
    if (firstTurn == null) {
      int bestMax = -1;
      for (int p = 1; p <= numberOfPlayers; p++) {
        final pMax = hands['player${p}Hand']!.fold(0, (m, id) {
          final total = allTiles[id]!['left']! + allTiles[id]!['right']!;
          return total > m ? total : m;
        });
        if (pMax > bestMax) { bestMax = pMax; firstTurn = 'player$p'; }
      }
      firstTurn ??= 'player1';
    }

    return {'tiles': allTiles, ...hands, 'boneyard': boneyard, 'firstTurn': firstTurn};
  }

  static Map<String, dynamic> initialDeal(Random rng, {int numberOfPlayers = 2}) =>
      _buildInitialDeal(rng, numberOfPlayers: numberOfPlayers);

  factory DominoGameState.fromDeal({
    required Map<String, dynamic> deal,
    int player1Score = 0,
    int player2Score = 0,
    int player3Score = 0,
    int player4Score = 0,
    int roundNumber = 1,
  }) {
    final rawTiles = deal['tiles'] as Map<String, dynamic>;
    final tiles = rawTiles.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {'left': (m['left'] as num).toInt(), 'right': (m['right'] as num).toInt()});
    });
    return DominoGameState(
      chain: [],
      player1Hand: List<String>.from(deal['player1Hand'] as List),
      player2Hand: List<String>.from(deal['player2Hand'] as List),
      player3Hand: List<String>.from((deal['player3Hand'] as List?) ?? []),
      player4Hand: List<String>.from((deal['player4Hand'] as List?) ?? []),
      boneyard: List<String>.from(deal['boneyard'] as List),
      tiles: tiles,
      player1Score: player1Score,
      player2Score: player2Score,
      player3Score: player3Score,
      player4Score: player4Score,
      roundNumber: roundNumber,
    );
  }

  List<String> handOf(int playerNumber) {
    switch (playerNumber) {
      case 1: return player1Hand;
      case 2: return player2Hand;
      case 3: return player3Hand;
      case 4: return player4Hand;
      default: return [];
    }
  }

  int scoreOf(int playerNumber) {
    switch (playerNumber) {
      case 1: return player1Score;
      case 2: return player2Score;
      case 3: return player3Score;
      case 4: return player4Score;
      default: return 0;
    }
  }

  int handPipCount(List<String> hand) {
    return hand.fold(0, (acc, id) {
      final t = tiles[id];
      if (t == null) return acc;
      return acc + t['left']! + t['right']!;
    });
  }

  bool canPlay(String tileId, {bool checkLeft = true, bool checkRight = true}) {
    final t = tiles[tileId];
    if (t == null) return false;
    if (chain.isEmpty) return true;
    final l = t['left']!;
    final r = t['right']!;
    if (checkLeft && leftOpen != null && (l == leftOpen || r == leftOpen)) return true;
    if (checkRight && rightOpen != null && (l == rightOpen || r == rightOpen)) return true;
    return false;
  }

  bool canPlayAny(List<String> hand) => hand.any((id) => canPlay(id));

  Map<String, dynamic> toMap() {
    return {
      'chain': chain.map((t) => t.toMap()).toList(),
      'leftOpen': leftOpen,
      'rightOpen': rightOpen,
      'player1Hand': player1Hand,
      'player2Hand': player2Hand,
      'player3Hand': player3Hand,
      'player4Hand': player4Hand,
      'boneyard': boneyard,
      'tiles': tiles.map((k, v) => MapEntry(k, v)),
      'player1Score': player1Score,
      'player2Score': player2Score,
      'player3Score': player3Score,
      'player4Score': player4Score,
      'roundNumber': roundNumber,
      'consecutivePasses': consecutivePasses,
    };
  }

  factory DominoGameState.fromMap(Map<String, dynamic> map) {
    final rawTiles = (map['tiles'] as Map<String, dynamic>?) ?? {};
    final tiles = rawTiles.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {'left': (m['left'] as num).toInt(), 'right': (m['right'] as num).toInt()});
    });

    return DominoGameState(
      chain: ((map['chain'] as List<dynamic>?) ?? [])
          .map((e) => DominoChainTile.fromMap(e as Map<String, dynamic>))
          .toList(),
      leftOpen: (map['leftOpen'] as num?)?.toInt(),
      rightOpen: (map['rightOpen'] as num?)?.toInt(),
      player1Hand: List<String>.from(map['player1Hand'] ?? []),
      player2Hand: List<String>.from(map['player2Hand'] ?? []),
      player3Hand: List<String>.from(map['player3Hand'] ?? []),
      player4Hand: List<String>.from(map['player4Hand'] ?? []),
      boneyard: List<String>.from(map['boneyard'] ?? []),
      tiles: tiles,
      player1Score: (map['player1Score'] as num?)?.toInt() ?? 0,
      player2Score: (map['player2Score'] as num?)?.toInt() ?? 0,
      player3Score: (map['player3Score'] as num?)?.toInt() ?? 0,
      player4Score: (map['player4Score'] as num?)?.toInt() ?? 0,
      roundNumber: (map['roundNumber'] as num?)?.toInt() ?? 1,
      consecutivePasses: (map['consecutivePasses'] as num?)?.toInt() ?? 0,
    );
  }
}

class DominoGameMatch {
  final String id;
  final String gameType;
  final String hostId;
  final String? guestId;
  final String? guest2Id;
  final String? guest3Id;
  final String hostName;
  final String? guestName;
  final String? guest2Name;
  final String? guest3Name;
  final String? hostPhotoUrl;
  final String? guestPhotoUrl;
  final String status;
  final String currentTurn;
  final DominoGameState gameState;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? winnerId;
  final String? reason;
  final bool isRanked;
  final int? betAmount;
  final String currencyType;
  final bool quotasCollected;
  final bool rewardsDistributed;
  final int? hostQuota;
  final int? guestQuota;
  final int? totalPot;
  final Map<String, dynamic>? gameSettings;
  final int targetScore;
  final int numberOfPlayers;

  DominoGameMatch({
    required this.id,
    required this.gameType,
    required this.hostId,
    this.guestId,
    this.guest2Id,
    this.guest3Id,
    required this.hostName,
    this.guestName,
    this.guest2Name,
    this.guest3Name,
    this.hostPhotoUrl,
    this.guestPhotoUrl,
    required this.status,
    required this.currentTurn,
    required this.gameState,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.winnerId,
    this.reason,
    this.isRanked = false,
    this.betAmount,
    required this.currencyType,
    this.quotasCollected = false,
    this.rewardsDistributed = false,
    this.hostQuota,
    this.guestQuota,
    this.totalPot,
    this.gameSettings,
    this.targetScore = 100,
    this.numberOfPlayers = 2,
  });

  bool get isWaitingForOpponent => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';
  bool get isAbandoned => status == 'abandoned';

  int get currentPlayerCount {
    int count = 1;
    if (guestId != null) count++;
    if (guest2Id != null) count++;
    if (guest3Id != null) count++;
    return count;
  }

  bool get isFullyJoined => currentPlayerCount >= numberOfPlayers;

  String? playerIdOf(int playerNumber) {
    switch (playerNumber) {
      case 1: return hostId;
      case 2: return guestId;
      case 3: return guest2Id;
      case 4: return guest3Id;
      default: return null;
    }
  }

  String playerNameOf(int playerNumber) {
    switch (playerNumber) {
      case 1: return hostName;
      case 2: return guestName ?? 'Jugador 2';
      case 3: return guest2Name ?? 'Jugador 3';
      case 4: return guest3Name ?? 'Jugador 4';
      default: return 'Jugador';
    }
  }

  bool isPlayerTurn(String userId) {
    if (status != 'active') return false;
    if (hostId == userId) return currentTurn == 'player1';
    if (guestId == userId) return currentTurn == 'player2';
    if (guest2Id == userId) return currentTurn == 'player3';
    if (guest3Id == userId) return currentTurn == 'player4';
    return false;
  }

  int getPlayerNumber(String userId) {
    if (hostId == userId) return 1;
    if (guestId == userId) return 2;
    if (guest2Id == userId) return 3;
    if (guest3Id == userId) return 4;
    return 0;
  }

  List<String> getHand(int playerNumber) => gameState.handOf(playerNumber);

  Map<String, int> getPlayerScores() {
    final scores = <String, int>{'player1': gameState.player1Score, 'player2': gameState.player2Score};
    if (numberOfPlayers >= 3) scores['player3'] = gameState.player3Score;
    if (numberOfPlayers >= 4) scores['player4'] = gameState.player4Score;
    return scores;
  }

  String nextTurnAfter(String current) {
    final num = int.parse(current.replaceAll('player', ''));
    final next = (num % numberOfPlayers) + 1;
    return 'player$next';
  }

  factory DominoGameMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DominoGameMatch(
      id: doc.id,
      gameType: data['gameType'] ?? 'Domino',
      hostId: data['hostId'] ?? '',
      guestId: data['guestId'],
      guest2Id: data['guest2Id'],
      guest3Id: data['guest3Id'],
      hostName: data['hostName'] ?? '',
      guestName: data['guestName'],
      guest2Name: data['guest2Name'],
      guest3Name: data['guest3Name'],
      hostPhotoUrl: data['hostPhotoUrl'],
      guestPhotoUrl: data['guestPhotoUrl'],
      status: data['status'] ?? 'waiting',
      currentTurn: data['currentTurn'] ?? 'player1',
      gameState: DominoGameState.fromMap(data['gameState'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      finishedAt: data['finishedAt'] != null ? (data['finishedAt'] as Timestamp).toDate() : null,
      winnerId: data['winnerId'],
      reason: data['reason'],
      isRanked: data['isRanked'] ?? false,
      betAmount: data['betAmount'],
      currencyType: data['currencyType'] ?? 'coins',
      quotasCollected: data['quotasCollected'] ?? false,
      rewardsDistributed: data['rewardsDistributed'] ?? false,
      hostQuota: data['hostQuota'],
      guestQuota: data['guestQuota'],
      totalPot: data['totalPot'],
      gameSettings: data['gameSettings'],
      targetScore: (data['targetScore'] as num?)?.toInt() ?? 100,
      numberOfPlayers: (data['numberOfPlayers'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameType': gameType,
      'hostId': hostId,
      'guestId': guestId,
      'guest2Id': guest2Id,
      'guest3Id': guest3Id,
      'hostName': hostName,
      'guestName': guestName,
      'guest2Name': guest2Name,
      'guest3Name': guest3Name,
      'hostPhotoUrl': hostPhotoUrl,
      'guestPhotoUrl': guestPhotoUrl,
      'status': status,
      'currentTurn': currentTurn,
      'gameState': gameState.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'winnerId': winnerId,
      'reason': reason,
      'isRanked': isRanked,
      'betAmount': betAmount,
      'currencyType': currencyType,
      'quotasCollected': quotasCollected,
      'rewardsDistributed': rewardsDistributed,
      'hostQuota': hostQuota,
      'guestQuota': guestQuota,
      'totalPot': totalPot,
      'gameSettings': gameSettings,
      'targetScore': targetScore,
      'numberOfPlayers': numberOfPlayers,
    };
  }
}
