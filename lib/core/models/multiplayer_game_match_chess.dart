import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tekoplay/core/models/user.dart';
import '../service/multiplayer_game_service.dart';
import '../utils/game_result.dart';

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
  final String? reason;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final DateTime? lastHostActivity;
  final DateTime? lastGuestActivity;
  final String? abandonedBy;
  final DateTime? endTime;
  final String? drawOffer;
  final DateTime? drawOfferTime;
  final int? hostQuota;
  final int? guestQuota;
  final int? totalPot;
  final bool quotasCollected;
  final bool rewardsDistributed;
  final String currencyType;
  final int? hostBalanceSnapshot;
  final int? guestBalanceSnapshot;

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
    this.reason,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.lastHostActivity,
    this.lastGuestActivity,
    this.abandonedBy,
    this.endTime,
    this.drawOffer,
    this.drawOfferTime,
    this.hostQuota,
    this.guestQuota,
    this.totalPot,
    this.quotasCollected = false,
    this.rewardsDistributed = false,
    this.currencyType = 'coins',
    this.hostBalanceSnapshot,
    this.guestBalanceSnapshot,
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
      currentFen:
          data['currentFen'] ??
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: List<String>.from(data['moves'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt:
          data['startedAt'] != null
              ? (data['startedAt'] as Timestamp).toDate()
              : null,
      finishedAt:
          data['finishedAt'] != null
              ? (data['finishedAt'] as Timestamp).toDate()
              : null,
      winnerId: data['winnerId'],
      result:
          data['result'] != null
              ? GameResultModel.values.firstWhere(
                (e) => e.toString().split('.').last == data['result'],
              )
              : null,
      gameSettings: data['gameSettings'],
      lastMoveNotation: data['lastMoveNotation'],
      isRanked: data['isRanked'] ?? false,
      betAmount: data['betAmount'],
      reason: data['reason'],
      lastMoveFrom: data['lastMoveFrom'],
      lastMoveTo: data['lastMoveTo'],
      lastHostActivity:
          data['lastHostActivity'] != null
              ? (data['lastHostActivity'] as Timestamp).toDate()
              : null,
      lastGuestActivity:
          data['lastGuestActivity'] != null
              ? (data['lastGuestActivity'] as Timestamp).toDate()
              : null,
      abandonedBy: data['abandonedBy'],
      endTime:
          data['endTime'] != null
              ? (data['endTime'] as Timestamp).toDate()
              : null,
      drawOffer: data['drawOffer'],
      drawOfferTime:
          data['drawOfferTime'] != null
              ? (data['drawOfferTime'] as Timestamp).toDate()
              : null,
      hostQuota: data['hostQuota'],
      guestQuota: data['guestQuota'],
      totalPot: data['totalPot'],
      quotasCollected: data['quotasCollected'] ?? false,
      rewardsDistributed: data['rewardsDistributed'] ?? false,
      currencyType: data['currencyType'] ?? 'coins',
      hostBalanceSnapshot: data['hostBalanceSnapshot'],
      guestBalanceSnapshot: data['guestBalanceSnapshot'],
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
      'reason': reason,
      'lastMoveFrom': lastMoveFrom,
      'lastMoveTo': lastMoveTo,
      'lastHostActivity':
          lastHostActivity != null
              ? Timestamp.fromDate(lastHostActivity!)
              : null,
      'lastGuestActivity':
          lastGuestActivity != null
              ? Timestamp.fromDate(lastGuestActivity!)
              : null,
      'abandonedBy': abandonedBy,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'drawOffer': drawOffer,
      'drawOfferTime':
          drawOfferTime != null ? Timestamp.fromDate(drawOfferTime!) : null,
      'hostQuota': hostQuota,
      'guestQuota': guestQuota,
      'totalPot': totalPot,
      'quotasCollected': quotasCollected,
      'rewardsDistributed': rewardsDistributed,
      'currencyType': currencyType,
      'hostBalanceSnapshot': hostBalanceSnapshot,
      'guestBalanceSnapshot': guestBalanceSnapshot,
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
    String? reason,
    String? lastMoveFrom,
    String? lastMoveTo,
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
      reason: reason ?? this.reason,
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
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

  bool get isAbandoned => status == 'abandoned';

  bool didIAbandon(String currentUserId) {
    return isAbandoned && abandonedBy == currentUserId;
  }

  bool didOpponentAbandon(String currentUserId) {
    return isAbandoned && abandonedBy != null && abandonedBy != currentUserId;
  }
}

class GameInvitationService {
  static final GameInvitationService _instance =
      GameInvitationService._internal();

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
      final usersQuery =
          await _firestore
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
      if (kDebugMode) {
        print('Error creating invitation: $e');
      }
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
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
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

  Future<Map<String, dynamic>?> respondToInvitation(
    String invitationId,
    bool accept,
  ) async {
    try {
      final invitationRef = _firestore
          .collection(_invitationsCollection)
          .doc(invitationId);
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

        return {'success': true, 'declined': true};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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

enum TimeResult { normal, timeout, aborted }

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
