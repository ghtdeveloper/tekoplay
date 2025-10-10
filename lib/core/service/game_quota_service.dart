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
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final hostDoc = await transaction.get(
          _firestore.collection('users').doc(hostId),
        );
        final guestDoc = await transaction.get(
          _firestore.collection('users').doc(guestId),
        );

        if (!hostDoc.exists || !guestDoc.exists) {
          throw Exception('Usuarios no encontrados');
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

        transaction.update(
          hostDoc.reference,
          {currencyType: hostNewBalance},
        );
        transaction.update(
          guestDoc.reference,
          {currencyType: guestNewBalance},
        );

        final gameRef = _firestore.collection('multiplayer_games').doc(gameId);
        transaction.update(gameRef, {
          'hostQuota': quotaAmount,
          'guestQuota': quotaAmount,
          'totalPot': quotaAmount * 2,
          'quotasCollected': true,
          'currencyType': currencyType,
          'hostBalanceSnapshot': hostBalance,
          'guestBalanceSnapshot': guestBalance,
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
  }) {
    final quotaAmount = totalPot ~/ 2;
    final winnerPrize = quotaAmount + (quotaAmount * 0.7).round();
    final houseCommission = quotaAmount - (quotaAmount * 0.7).round();

    return {
      'winnerPrize': winnerPrize,
      'loserLoss': -quotaAmount,
      'houseCommission': houseCommission,
    };
  }
}