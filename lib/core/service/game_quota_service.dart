import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GameQuotaService {
  static final GameQuotaService _instance = GameQuotaService._internal();
  factory GameQuotaService() => _instance;
  GameQuotaService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> collectQuotas({
    required String gameId,
    required String hostId,
    required String guestId,
    required int quotaAmount,
    required String currencyType,
    String collectionName = 'multiplayer_games',
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final gameRef = _firestore.collection(collectionName).doc(gameId);

        final gameDoc = await transaction.get(gameRef);
        final hostDoc = await transaction.get(
          _firestore.collection('users').doc(hostId),
        );
        final guestDoc = await transaction.get(
          _firestore.collection('users').doc(guestId),
        );

        if (!hostDoc.exists || !guestDoc.exists) {
          throw Exception('Usuarios no encontrados');
        }

        final gameData = gameDoc.data();
        if (gameData != null && gameData['quotasCollected'] == true) {
          if (kDebugMode) print('⚠️ collectQuotas: ya cobradas (idempotente), retornando éxito');
          return {
            'success': true,
            'hostNewBalance': gameData['hostBalanceSnapshot'] ?? 0,
            'guestNewBalance': gameData['guestBalanceSnapshot'] ?? 0,
            'totalPot': gameData['totalPot'] ?? quotaAmount * 2,
            'alreadyCollected': true,
          };
        }

        final hostData = hostDoc.data()!;
        final guestData = guestDoc.data()!;

        final hostBalance = currencyType == 'coins'
            ? (hostData['coins'] ?? 0)
            : (hostData['diamonds'] ?? 0);
        final guestBalance = currencyType == 'coins'
            ? (guestData['coins'] ?? 0)
            : (guestData['diamonds'] ?? 0);

        if (hostBalance < quotaAmount) {
          throw Exception('Host no tiene fondos suficientes');
        }
        if (guestBalance < quotaAmount) {
          throw Exception('Guest no tiene fondos suficientes');
        }

        final hostNewBalance = hostBalance - quotaAmount;
        final guestNewBalance = guestBalance - quotaAmount;

        transaction.update(hostDoc.reference, {currencyType: hostNewBalance});
        transaction.update(guestDoc.reference, {currencyType: guestNewBalance});
        transaction.update(gameRef, {
          'hostQuota': quotaAmount,
          'guestQuota': quotaAmount,
          'totalPot': quotaAmount * 2,
          'quotasCollected': true,
          'currencyType': currencyType,
          'hostBalanceSnapshot': hostNewBalance,
          'guestBalanceSnapshot': guestNewBalance,
          'quotasCollectedAt': FieldValue.serverTimestamp(),
        });

        return {
          'success': true,
          'hostNewBalance': hostNewBalance,
          'guestNewBalance': guestNewBalance,
          'totalPot': quotaAmount * 2,
        };
      });
    } catch (e) {
      if (kDebugMode) {
        print('💥 Error cobrando cuotas: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Map<String, int> calculateDistribution({
    required int totalPot,
    required String winnerId,
    required String hostId,
    bool isBetMode = true,
  }) {
    final quotaAmount     = totalPot ~/ 2;
    final winnerPrize     = (totalPot * (isBetMode ? 0.90 : 0.70)).floor();
    final houseCommission = totalPot - winnerPrize;

    return {
      'winnerPrize':     winnerPrize,
      'loserLoss':       -quotaAmount,
      'houseCommission': houseCommission,
    };
  }
}