import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de partida de Ludo multijugador
class LudoGameMatch {
  final String id;
  final String gameType; // 'Ludo'
  final String hostId;
  final String? guest2Id;
  final String? guest3Id;
  final String? guest4Id;

  final String hostName;
  final String? guest2Name;
  final String? guest3Name;
  final String? guest4Name;

  final String? hostPhotoUrl;
  final String? guest2PhotoUrl;
  final String? guest3PhotoUrl;
  final String? guest4PhotoUrl;

  final String status; // 'waiting', 'active', 'finished', 'abandoned', 'cancelled'
  final String currentTurn; // 'player1', 'player2', 'player3', 'player4'

  final LudoGameState gameState;
  final List<LudoMove> moveHistory;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  final String? winnerId;
  final String? abandonedBy;
  final DateTime? turnDeadline;
  final List<String> finishedPlayers; // IDs de jugadores que terminaron (en orden)
  final String? reason; // 'normal', 'timeout', 'abandoned'

  final bool isRanked;
  final int? betAmount;
  final String currencyType; // 'coins' o 'diamonds'

  // Sistema de cuotas
  final int? player1Quota;
  final int? player2Quota;
  final int? player3Quota;
  final int? player4Quota;
  final int? totalPot;
  final bool quotasCollected;
  final bool rewardsDistributed;

  // Configuración del juego
  final Map<String, dynamic>? gameSettings;

  // Actividad de jugadores
  final DateTime? lastPlayer1Activity;
  final DateTime? lastPlayer2Activity;
  final DateTime? lastPlayer3Activity;
  final DateTime? lastPlayer4Activity;

  // Colores asignados a cada jugador
  final String player1Color; // 'red', 'blue', 'green', 'yellow'
  final String? player2Color;
  final String? player3Color;
  final String? player4Color;

  // Dados activos (para sincronización multijugador)
  final int dice1;
  final int dice2;
  final bool hasUsedDice1;
  final bool hasUsedDice2;

  LudoGameMatch({
    required this.id,
    required this.gameType,
    required this.hostId,
    this.guest2Id,
    this.guest3Id,
    this.guest4Id,
    required this.hostName,
    this.guest2Name,
    this.guest3Name,
    this.guest4Name,
    this.hostPhotoUrl,
    this.guest2PhotoUrl,
    this.guest3PhotoUrl,
    this.guest4PhotoUrl,
    required this.status,
    required this.currentTurn,
    required this.gameState,
    required this.moveHistory,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.winnerId,
    this.abandonedBy,
    this.turnDeadline,
    this.finishedPlayers = const [],
    this.reason,
    this.isRanked = false,
    this.betAmount,
    required this.currencyType,
    this.player1Quota,
    this.player2Quota,
    this.player3Quota,
    this.player4Quota,
    this.totalPot,
    this.quotasCollected = false,
    this.rewardsDistributed = false,
    this.gameSettings,
    this.lastPlayer1Activity,
    this.lastPlayer2Activity,
    this.lastPlayer3Activity,
    this.lastPlayer4Activity,
    required this.player1Color,
    this.player2Color,
    this.player3Color,
    this.player4Color,
    this.dice1 = 0,
    this.dice2 = 0,
    this.hasUsedDice1 = false,
    this.hasUsedDice2 = false,
  });

  factory LudoGameMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LudoGameMatch(
      id: doc.id,
      gameType: data['gameType'] ?? 'Ludo',
      hostId: data['hostId'] ?? '',
      guest2Id: data['guest2Id'],
      guest3Id: data['guest3Id'],
      guest4Id: data['guest4Id'],
      hostName: data['hostName'] ?? '',
      guest2Name: data['guest2Name'],
      guest3Name: data['guest3Name'],
      guest4Name: data['guest4Name'],
      hostPhotoUrl: data['hostPhotoUrl'],
      guest2PhotoUrl: data['guest2PhotoUrl'],
      guest3PhotoUrl: data['guest3PhotoUrl'],
      guest4PhotoUrl: data['guest4PhotoUrl'],
      status: data['status'] ?? 'waiting',
      currentTurn: data['currentTurn'] ?? 'player1',
      gameState: LudoGameState.fromMap(data['gameState'] ?? {}),
      moveHistory: (data['moveHistory'] as List<dynamic>?)
          ?.map((m) => LudoMove.fromMap(m as Map<String, dynamic>))
          .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      finishedAt: data['finishedAt'] != null
          ? (data['finishedAt'] as Timestamp).toDate()
          : null,
      winnerId: data['winnerId'],
      abandonedBy: data['abandonedBy'],
      turnDeadline: data['turnDeadline'] != null
          ? (data['turnDeadline'] as Timestamp).toDate()
          : null,
      finishedPlayers: List<String>.from(data['finishedPlayers'] ?? []),
      reason: data['reason'],
      isRanked: data['isRanked'] ?? false,
      betAmount: data['betAmount'],
      currencyType: data['currencyType'] ?? 'coins',
      player1Quota: data['player1Quota'],
      player2Quota: data['player2Quota'],
      player3Quota: data['player3Quota'],
      player4Quota: data['player4Quota'],
      totalPot: data['totalPot'],
      quotasCollected: data['quotasCollected'] ?? false,
      rewardsDistributed: data['rewardsDistributed'] ?? false,
      gameSettings: data['gameSettings'],
      lastPlayer1Activity: data['lastPlayer1Activity'] != null
          ? (data['lastPlayer1Activity'] as Timestamp).toDate()
          : null,
      lastPlayer2Activity: data['lastPlayer2Activity'] != null
          ? (data['lastPlayer2Activity'] as Timestamp).toDate()
          : null,
      lastPlayer3Activity: data['lastPlayer3Activity'] != null
          ? (data['lastPlayer3Activity'] as Timestamp).toDate()
          : null,
      lastPlayer4Activity: data['lastPlayer4Activity'] != null
          ? (data['lastPlayer4Activity'] as Timestamp).toDate()
          : null,
      player1Color: data['player1Color'] ?? 'red',
      player2Color: data['player2Color'],
      player3Color: data['player3Color'],
      player4Color: data['player4Color'],
      dice1: (data['dice1'] as int?) ?? 0,
      dice2: (data['dice2'] as int?) ?? 0,
      hasUsedDice1: (data['hasUsedDice1'] as bool?) ?? false,
      hasUsedDice2: (data['hasUsedDice2'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameType': gameType,
      'hostId': hostId,
      'guest2Id': guest2Id,
      'guest3Id': guest3Id,
      'guest4Id': guest4Id,
      'hostName': hostName,
      'guest2Name': guest2Name,
      'guest3Name': guest3Name,
      'guest4Name': guest4Name,
      'hostPhotoUrl': hostPhotoUrl,
      'guest2PhotoUrl': guest2PhotoUrl,
      'guest3PhotoUrl': guest3PhotoUrl,
      'guest4PhotoUrl': guest4PhotoUrl,
      'status': status,
      'currentTurn': currentTurn,
      'gameState': gameState.toMap(),
      'moveHistory': moveHistory.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'winnerId': winnerId,
      'abandonedBy': abandonedBy,
      'turnDeadline': turnDeadline != null ? Timestamp.fromDate(turnDeadline!) : null,
      'finishedPlayers': finishedPlayers,
      'reason': reason,
      'isRanked': isRanked,
      'betAmount': betAmount,
      'currencyType': currencyType,
      'player1Quota': player1Quota,
      'player2Quota': player2Quota,
      'player3Quota': player3Quota,
      'player4Quota': player4Quota,
      'totalPot': totalPot,
      'quotasCollected': quotasCollected,
      'rewardsDistributed': rewardsDistributed,
      'gameSettings': gameSettings,
      'lastPlayer1Activity': lastPlayer1Activity != null
          ? Timestamp.fromDate(lastPlayer1Activity!)
          : null,
      'lastPlayer2Activity': lastPlayer2Activity != null
          ? Timestamp.fromDate(lastPlayer2Activity!)
          : null,
      'lastPlayer3Activity': lastPlayer3Activity != null
          ? Timestamp.fromDate(lastPlayer3Activity!)
          : null,
      'lastPlayer4Activity': lastPlayer4Activity != null
          ? Timestamp.fromDate(lastPlayer4Activity!)
          : null,
      'player1Color': player1Color,
      'player2Color': player2Color,
      'player3Color': player3Color,
      'player4Color': player4Color,
      'dice1': dice1,
      'dice2': dice2,
      'hasUsedDice1': hasUsedDice1,
      'hasUsedDice2': hasUsedDice2,
    };
  }

  bool get isWaitingForPlayers => status == 'waiting';
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';
  bool get isAbandoned => status == 'abandoned';

  int get playerCount {
    int count = 1; // host
    if (guest2Id != null) count++;
    if (guest3Id != null) count++;
    if (guest4Id != null) count++;
    return count;
  }

  String? getPlayerIdByNumber(int playerNumber) {
    switch (playerNumber) {
      case 1:
        return hostId;
      case 2:
        return guest2Id;
      case 3:
        return guest3Id;
      case 4:
        return guest4Id;
      default:
        return null;
    }
  }

  int? getPlayerNumber(String userId) {
    if (hostId == userId) return 1;
    if (guest2Id == userId) return 2;
    if (guest3Id == userId) return 3;
    if (guest4Id == userId) return 4;
    return null;
  }

  bool isPlayerTurn(String userId) {
    if (status != 'active') return false;
    final playerNum = getPlayerNumber(userId);
    if (playerNum == null) return false;
    return currentTurn == 'player$playerNum';
  }
}

/// Estado del juego de Ludo
class LudoGameState {
  final int lastDiceRoll;
  final bool canRollDice;
  final List<LudoPiece> redPieces;
  final List<LudoPiece> bluePieces;
  final List<LudoPiece> greenPieces;
  final List<LudoPiece> yellowPieces;
  final int consecutiveSixes; // Contador de 6s consecutivos

  LudoGameState({
    this.lastDiceRoll = 0,
    this.canRollDice = true,
    required this.redPieces,
    required this.bluePieces,
    required this.greenPieces,
    required this.yellowPieces,
    this.consecutiveSixes = 0,
  });

  factory LudoGameState.initial() {
    return LudoGameState(
      redPieces: List.generate(4, (i) => LudoPiece(id: i, color: 'red')),
      bluePieces: List.generate(4, (i) => LudoPiece(id: i, color: 'blue')),
      greenPieces: List.generate(4, (i) => LudoPiece(id: i, color: 'green')),
      yellowPieces: List.generate(4, (i) => LudoPiece(id: i, color: 'yellow')),
    );
  }

  factory LudoGameState.fromMap(Map<String, dynamic> map) {
    return LudoGameState(
      lastDiceRoll: map['lastDiceRoll'] ?? 0,
      canRollDice: map['canRollDice'] ?? true,
      redPieces: (map['redPieces'] as List<dynamic>?)
          ?.map((p) => LudoPiece.fromMap(p as Map<String, dynamic>))
          .toList() ??
          List.generate(4, (i) => LudoPiece(id: i, color: 'red')),
      bluePieces: (map['bluePieces'] as List<dynamic>?)
          ?.map((p) => LudoPiece.fromMap(p as Map<String, dynamic>))
          .toList() ??
          List.generate(4, (i) => LudoPiece(id: i, color: 'blue')),
      greenPieces: (map['greenPieces'] as List<dynamic>?)
          ?.map((p) => LudoPiece.fromMap(p as Map<String, dynamic>))
          .toList() ??
          List.generate(4, (i) => LudoPiece(id: i, color: 'green')),
      yellowPieces: (map['yellowPieces'] as List<dynamic>?)
          ?.map((p) => LudoPiece.fromMap(p as Map<String, dynamic>))
          .toList() ??
          List.generate(4, (i) => LudoPiece(id: i, color: 'yellow')),
      consecutiveSixes: map['consecutiveSixes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastDiceRoll': lastDiceRoll,
      'canRollDice': canRollDice,
      'redPieces': redPieces.map((p) => p.toMap()).toList(),
      'bluePieces': bluePieces.map((p) => p.toMap()).toList(),
      'greenPieces': greenPieces.map((p) => p.toMap()).toList(),
      'yellowPieces': yellowPieces.map((p) => p.toMap()).toList(),
      'consecutiveSixes': consecutiveSixes,
    };
  }

  List<LudoPiece> getPiecesByColor(String color) {
    switch (color) {
      case 'red':
        return redPieces;
      case 'blue':
        return bluePieces;
      case 'green':
        return greenPieces;
      case 'yellow':
        return yellowPieces;
      default:
        return [];
    }
  }
}

/// Ficha de Ludo
class LudoPiece {
  final int id; // 0-3
  final String color;
  int position; // -1 = home, 0-56 = en tablero, 57+ = finished
  bool isFinished;

  LudoPiece({
    required this.id,
    required this.color,
    this.position = -1,
    this.isFinished = false,
  });

  factory LudoPiece.fromMap(Map<String, dynamic> map) {
    return LudoPiece(
      id: map['id'] ?? 0,
      color: map['color'] ?? '',
      position: map['position'] ?? -1,
      isFinished: map['isFinished'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'color': color,
      'position': position,
      'isFinished': isFinished,
    };
  }

  bool get isHome => position == -1;
  bool get isOnBoard => position >= 0 && position < 57;
}

class LudoMove {
  final int diceRoll;
  final String playerColor;
  final int pieceId;
  final int fromPosition;
  final int toPosition;
  final bool capturedOpponent;
  final String? capturedColor;
  final DateTime timestamp;

  LudoMove({
    required this.diceRoll,
    required this.playerColor,
    required this.pieceId,
    required this.fromPosition,
    required this.toPosition,
    this.capturedOpponent = false,
    this.capturedColor,
    required this.timestamp,
  });

  factory LudoMove.fromMap(Map<String, dynamic> map) {
    return LudoMove(
      diceRoll: map['diceRoll'] ?? 0,
      playerColor: map['playerColor'] ?? '',
      pieceId: map['pieceId'] ?? 0,
      fromPosition: map['fromPosition'] ?? -1,
      toPosition: map['toPosition'] ?? 0,
      capturedOpponent: map['capturedOpponent'] ?? false,
      capturedColor: map['capturedColor'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diceRoll': diceRoll,
      'playerColor': playerColor,
      'pieceId': pieceId,
      'fromPosition': fromPosition,
      'toPosition': toPosition,
      'capturedOpponent': capturedOpponent,
      'capturedColor': capturedColor,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}