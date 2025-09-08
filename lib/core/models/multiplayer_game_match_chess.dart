
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tekoplay/core/models/user.dart';

import '../service/firestore_service.dart';
import '../utils/game_result.dart';
import '../utils/game_type.dart';

class MultiplayerGameMatch {
  final String id;
  final String gameType;
  final String hostId;
  final String? guestId;
  final String hostName;
  final String? guestName;
  final String? hostPhotoUrl;
  final String? guestPhotoUrl;
  final String status;
  final String currentTurn;
  final String currentFen;
  final List<String> moves;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? winnerId;
  final GameResultModel? result;
  final Map<String, dynamic>? gameSettings;
  final String? lastMoveNotation;
  final bool isRanked;
  final int? betAmount;

  MultiplayerGameMatch({
    required this.id,
    required this.gameType,
    required this.hostId,
    this.guestId,
    required this.hostName,
    this.guestName,
    this.hostPhotoUrl,
    this.guestPhotoUrl,
    required this.status,
    required this.currentTurn,
    required this.currentFen,
    required this.moves,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.winnerId,
    this.result,
    this.gameSettings,
    this.lastMoveNotation,
    this.isRanked = false,
    this.betAmount,
  });

  factory MultiplayerGameMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MultiplayerGameMatch(
      id: doc.id,
      gameType: data['gameType'] ?? '',
      hostId: data['hostId'] ?? '',
      guestId: data['guestId'],
      hostName: data['hostName'] ?? '',
      guestName: data['guestName'],
      hostPhotoUrl: data['hostPhotoUrl'],
      guestPhotoUrl: data['guestPhotoUrl'],
      status: data['status'] ?? 'waiting',
      currentTurn: data['currentTurn'] ?? 'host',
      currentFen: data['currentFen'] ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: List<String>.from(data['moves'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      finishedAt: data['finishedAt'] != null ? (data['finishedAt'] as Timestamp).toDate() : null,
      winnerId: data['winnerId'],
      result: data['result'] != null ? GameResultModel.values.firstWhere(
            (e) => e.toString().split('.').last == data['result'],
      ) : null,
      gameSettings: data['gameSettings'],
      lastMoveNotation: data['lastMoveNotation'],
      isRanked: data['isRanked'] ?? false,
      betAmount: data['betAmount'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gameType': gameType,
      'hostId': hostId,
      'guestId': guestId,
      'hostName': hostName,
      'guestName': guestName,
      'hostPhotoUrl': hostPhotoUrl,
      'guestPhotoUrl': guestPhotoUrl,
      'status': status,
      'currentTurn': currentTurn,
      'currentFen': currentFen,
      'moves': moves,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finishedAt': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'winnerId': winnerId,
      'result': result?.toString().split('.').last,
      'gameSettings': gameSettings,
      'lastMoveNotation': lastMoveNotation,
      'isRanked': isRanked,
      'betAmount': betAmount,
    };
  }

  MultiplayerGameMatch copyWith({
    String? status,
    String? guestId,
    String? guestName,
    String? guestPhotoUrl,
    String? currentTurn,
    String? currentFen,
    List<String>? moves,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? winnerId,
    GameResultModel? result,
    String? lastMoveNotation,
    Map<String, dynamic>? gameSettings,
  }) {
    return MultiplayerGameMatch(
      id: id,
      gameType: gameType,
      hostId: hostId,
      guestId: guestId ?? this.guestId,
      hostName: hostName,
      guestName: guestName ?? this.guestName,
      hostPhotoUrl: hostPhotoUrl,
      guestPhotoUrl: guestPhotoUrl ?? this.guestPhotoUrl,
      status: status ?? this.status,
      currentTurn: currentTurn ?? this.currentTurn,
      currentFen: currentFen ?? this.currentFen,
      moves: moves ?? this.moves,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      winnerId: winnerId ?? this.winnerId,
      result: result ?? this.result,
      gameSettings: gameSettings ?? this.gameSettings,
      lastMoveNotation: lastMoveNotation ?? this.lastMoveNotation,
      isRanked: isRanked,
      betAmount: betAmount,
    );
  }

  bool get isWaitingForPlayer => status == 'waiting' && guestId == null;
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  String? getOpponentId(String currentUserId) {
    if (hostId == currentUserId) return guestId;
    if (guestId == currentUserId) return hostId;
    return null;
  }

  String? getOpponentName(String currentUserId) {
    if (hostId == currentUserId) return guestName;
    if (guestId == currentUserId) return hostName;
    return null;
  }

  bool isPlayerTurn(String currentUserId) {
    if (status != 'active') return false;
    if (currentTurn == 'host' && hostId == currentUserId) return true;
    if (currentTurn == 'guest' && guestId == currentUserId) return true;
    return false;
  }
}

class GameInvitationService {
  static final GameInvitationService _instance = GameInvitationService._internal();
  factory GameInvitationService() => _instance;
  GameInvitationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _invitationsCollection = 'game_invitations';

  Future<String?> createInvitation({
    required String fromUserId,
    required String fromUserName,
    required String toUserEmail,
    required String gameType,
    bool isRanked = false,
    int? betAmount,
  }) async {
    try {

      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: toUserEmail.trim().toLowerCase())
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        return 'Usuario no encontrado';
      }

      final toUser = UserModel.fromFirestore(usersQuery.docs.first);

      if (toUser.id == fromUserId) {
        return 'No puedes invitarte a ti mismo';
      }


      final invitationRef = _firestore.collection(_invitationsCollection).doc();

      await invitationRef.set({
        'id': invitationRef.id,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUser.id,
        'toUserName': toUser.name,
        'toUserEmail': toUserEmail.trim().toLowerCase(),
        'gameType': gameType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isRanked': isRanked,
        'betAmount': betAmount,
      });


      await _sendInvitationNotification(
        toUserId: toUser.id,
        fromUserName: fromUserName,
        gameType: gameType,
        invitationId: invitationRef.id,
      );

      return null;
    } catch (e) {
      print('Error creating invitation: $e');
      return 'Error al enviar invitación';
    }
  }

  Future<void> _sendInvitationNotification({
    required String toUserId,
    required String fromUserName,
    required String gameType,
    required String invitationId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': toUserId,
        'type': 'game_invitation',
        'title': 'Nueva invitación de juego',
        'message': '$fromUserName te invita a jugar $gameType',
        'data': {
          'invitationId': invitationId,
          'gameType': gameType,
          'fromUserName': fromUserName,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getPendingInvitations(String userId) {
    return _firestore
        .collection(_invitationsCollection)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<Map<String, dynamic>?> respondToInvitation(String invitationId, bool accept) async {
    try {
      final invitationRef = _firestore.collection(_invitationsCollection).doc(invitationId);
      final invitationDoc = await invitationRef.get();

      if (!invitationDoc.exists) return null;

      final invitationData = invitationDoc.data()!;

      if (accept) {
        final gameId = await MultiplayerGameService().createGame(
          hostId: invitationData['fromUserId'],
          hostName: invitationData['fromUserName'],
          guestId: invitationData['toUserId'],
          guestName: invitationData['toUserName'],
          gameType: invitationData['gameType'],
          isRanked: invitationData['isRanked'] ?? false,
          betAmount: invitationData['betAmount'],
        );

        await invitationRef.update({
          'status': 'accepted',
          'gameId': gameId,
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'gameId': gameId,
          'isHost': false,
          'gameType': invitationData['gameType'],
        };
      } else {
        await invitationRef.update({
          'status': 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'declined': true,
        };
      }
    } catch (e) {
      print('Error responding to invitation: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

class MultiplayerGameService {
  static final MultiplayerGameService _instance = MultiplayerGameService._internal();
  factory MultiplayerGameService() => _instance;
  MultiplayerGameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _gamesCollection = 'multiplayer_games';

  Future<String?> createGame({
    required String hostId,
    required String hostName,
    String? guestId,
    String? guestName,
    required String gameType,
    bool isRanked = false,
    int? betAmount,
    String? hostPhotoUrl,
    String? guestPhotoUrl,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc();

      final game = MultiplayerGameMatch(
        id: gameRef.id,
        gameType: gameType,
        hostId: hostId,
        hostName: hostName,
        guestId: guestId,
        guestName: guestName,
        hostPhotoUrl: hostPhotoUrl,
        guestPhotoUrl: guestPhotoUrl,
        status: guestId != null ? 'active' : 'waiting',
        currentTurn: 'host',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        createdAt: DateTime.now(),
        startedAt: guestId != null ? DateTime.now() : null,
        isRanked: isRanked,
        betAmount: betAmount,
      );

      await gameRef.set(game.toFirestore());

      return gameRef.id;
    } catch (e) {
      print('Error creating game: $e');
      return null;
    }
  }

  Future<bool> joinGame(String gameId, String playerId, String playerName, String? playerPhotoUrl) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = MultiplayerGameMatch.fromFirestore(gameDoc);

      if (game.guestId != null || game.hostId == playerId) return false;

      await gameRef.update({
        'guestId': playerId,
        'guestName': playerName,
        'guestPhotoUrl': playerPhotoUrl,
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error joining game: $e');
      return false;
    }
  }

  Stream<MultiplayerGameMatch?> getGameStream(String gameId) {
    return _firestore.collection(_gamesCollection).doc(gameId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return MultiplayerGameMatch.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Future<bool> makeMove({
    required String gameId,
    required String playerId,
    required String from,
    required String to,
    String? promotion,
    required String newFen,
    required String moveNotation,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      await _firestore.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);

        if (!gameDoc.exists) throw Exception('Game not found');

        final game = MultiplayerGameMatch.fromFirestore(gameDoc);

        if (!game.isPlayerTurn(playerId)) {
          throw Exception('Not player turn');
        }

        final newMoves = List<String>.from(game.moves);

        if (from != "xx" && to != "xx" && from != "player" && to != "move") {
          final moveUci = promotion != null ? '$from$to$promotion' : '$from$to';
          newMoves.add(moveUci);
        } else {
          newMoves.add("move${newMoves.length + 1}");
        }

        final newTurn = game.currentTurn == 'host' ? 'guest' : 'host';

        transaction.update(gameRef, {
          'currentFen': newFen,
          'currentTurn': newTurn,
          'moves': newMoves,
          'lastMoveNotation': moveNotation,
        });
      });

      return true;
    } catch (e) {
      print('Error making move: $e');
      return false;
    }
  }

  Future<bool> finishGame({
    required String gameId,
    required GameResultModel result,
    String? winnerId,
  }) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);

      await gameRef.update({
        'status': 'finished',
        'result': result.toString().split('.').last,
        'winnerId': winnerId,
        'finishedAt': FieldValue.serverTimestamp(),
      });

      final gameDoc = await gameRef.get();
      if (gameDoc.exists) {
        final game = MultiplayerGameMatch.fromFirestore(gameDoc);
        await _updatePlayerStats(game, result);
      }

      return true;
    } catch (e) {
      print('Error finishing game: $e');
      return false;
    }
  }

  Future<void> _updatePlayerStats(MultiplayerGameMatch game, GameResultModel result) async {
    try {
      final firestoreService = FirestoreService();
      final batch = _firestore.batch();


      GameResultModel hostResult = result;
      GameResultModel guestResult = result;

      if (result == GameResultModel.win) {
        if (game.winnerId == game.hostId) {
          hostResult = GameResultModel.win;
          guestResult = GameResultModel.loss;
        } else if (game.winnerId == game.guestId) {
          hostResult = GameResultModel.loss;
          guestResult = GameResultModel.win;
        }
      }

      int hostPoints = _calculatePoints(hostResult);
      int guestPoints = _calculatePoints(guestResult);


      final gameDuration = game.finishedAt != null && game.startedAt != null
          ? game.finishedAt!.difference(game.startedAt!).inMinutes
          : 1;

      await firestoreService.recordGameMatch(
        userId: game.hostId,
        gameType: GameTypeModel.chess,
        result: hostResult,
        pointsEarned: hostPoints,
        durationMinutes: gameDuration,
        opponentId: game.guestId,
        opponentName: game.guestName,
        additionalData: {
          'isMultiplayer': true,
          'gameId': game.id,
          'finalFEN': game.currentFen,
          'isRanked': game.isRanked,
          'betAmount': game.betAmount,
        },
      );

      // Guest
      if (game.guestId != null) {
        await firestoreService.recordGameMatch(
          userId: game.guestId!,
          gameType: GameTypeModel.chess,
          result: guestResult,
          pointsEarned: guestPoints,
          durationMinutes: gameDuration,
          opponentId: game.hostId,
          opponentName: game.hostName,
          additionalData: {
            'isMultiplayer': true,
            'gameId': game.id,
            'finalFEN': game.currentFen,
            'isRanked': game.isRanked,
            'betAmount': game.betAmount,
          },
        );
      }
    } catch (e) {
      print('Error updating player stats: $e');
    }
  }

  int _calculatePoints(GameResultModel result) {
    switch (result) {
      case GameResultModel.win:
        return 15;
      case GameResultModel.loss:
        return -5;
      case GameResultModel.draw:
        return 5;
    }
  }

  Stream<List<MultiplayerGameMatch>> getActiveGames(String userId) {
    return _firestore
        .collection(_gamesCollection)
        .where('status', isEqualTo: 'active')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .asyncMap((hostSnapshot) async {
      final guestSnapshot = await _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'active')
          .where('guestId', isEqualTo: userId)
          .get();

      final allDocs = [...hostSnapshot.docs, ...guestSnapshot.docs];

      return allDocs.map((doc) => MultiplayerGameMatch.fromFirestore(doc)).toList();
    });
  }

  Future<List<MultiplayerGameMatch>> getWaitingGames({String? gameType, int limit = 10}) async {
    try {
      Query query = _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt', descending: true);

      if (gameType != null) {
        query = query.where('gameType', isEqualTo: gameType);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) => MultiplayerGameMatch.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting waiting games: $e');
      return [];
    }
  }

  Future<bool> cancelGame(String gameId, String userId) async {
    try {
      final gameRef = _firestore.collection(_gamesCollection).doc(gameId);
      final gameDoc = await gameRef.get();

      if (!gameDoc.exists) return false;

      final game = MultiplayerGameMatch.fromFirestore(gameDoc);

      if (game.status == 'waiting' && game.hostId == userId) {
        await gameRef.update({
          'status': 'cancelled',
          'finishedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      return false;
    } catch (e) {
      print('Error canceling game: $e');
      return false;
    }
  }
}

enum OnlineMatchmakingState {
  idle,
  searching,
  found,
  connecting,
  connected,
  playing,
  finished,
  error,
}

enum TimeResult {
  normal,
  timeout,
  aborted,
}

class GameTimePreset {
  final int? minutes;
  final String displayName;
  final String description;

  const GameTimePreset({
    required this.minutes,
    required this.displayName,
    required this.description,
  });

  static const List<GameTimePreset> presets = [
    GameTimePreset(
      minutes: null,
      displayName: 'Sin tiempo',
      description: 'Partida sin límite de tiempo',
    ),
    GameTimePreset(
      minutes: 1,
      displayName: '1 minuto',
      description: 'Partida rápida de 1 minuto',
    ),
    GameTimePreset(
      minutes: 3,
      displayName: '3 minutos',
      description: 'Partida blitz de 3 minutos',
    ),
    GameTimePreset(
      minutes: 5,
      displayName: '5 minutos',
      description: 'Partida rápida de 5 minutos',
    ),
    GameTimePreset(
      minutes: 10,
      displayName: '10 minutos',
      description: 'Partida estándar de 10 minutos',
    ),
  ];
}