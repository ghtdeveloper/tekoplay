
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/games/chess/multiplayer_chess_screen.dart';
import '../../features/games/domino/multiplayer_domino_screen.dart';
import '../../features/games/domino_pase/multiplayer_domino_pase_screen.dart';
import '../../features/games/ludo/multiplayer_ludo_screen.dart';
import '../../generated/l10n.dart';

import '../models/multiplayer_game_match_chess.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    await _requestPermissions();
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
    await _saveDeviceToken();
  }

  Future<void> _requestPermissions() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _initializeFirebaseMessaging() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _saveDeviceToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('user_tokens').doc(currentUser.uid).set({
          'token': token,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('user_tokens').doc(currentUser.uid).update({
          'token': newToken,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving device token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {

    _showLocalNotification(
      title: message.notification?.title ?? 'Notificación',
      body: message.notification?.body ?? '',
      data: message.data,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    switch (type) {
      case 'game_invitation':
        _handleGameInvitationTap(data);
    }
  }

  void _onNotificationTapped(NotificationResponse details) {
    final payload = details.payload;
    if (payload != null) {
      if (kDebugMode) {
        print('Local notification tapped: $payload');
      }
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'game_notifications',
      'Notificaciones de Juego',
      channelDescription: 'Notificaciones para invitaciones y movimientos de juego',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: data?.toString(),
    );
  }

  void _handleGameInvitationTap(Map<String, dynamic> data) {
  }

  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  void handleGameInvitationNotification(BuildContext context, Map<String, dynamic> data) {
    final invitationId = data['invitationId'] as String?;
    final gameType = data['gameType'] as String?;
    final fromUserName = data['fromUserName'] as String?;

    if (invitationId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).gameInvitation),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$fromUserName ${S.of(context).invitesYouToPlay} $gameType',
                style: TextStyle(fontSize: 16),
                softWrap: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _declineInvitation(invitationId);
            },
            child: Text(S.of(context).reject, style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _acceptInvitation(context, invitationId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEC7A34),
              foregroundColor: Colors.white,
            ),
            child: Text(S.of(context).accept),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvitation(BuildContext context, String invitationId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Usuario no autenticado"), backgroundColor: Colors.red),
        );
        return;
      }
      final hasEnoughFunds = await _validateUserFundsForInvitation(context, currentUser.uid);
      if (!context.mounted) return;
      if (!hasEnoughFunds) {
        Navigator.of(context).pop();
        return;
      }
      final result = await GameInvitationService().respondToInvitation(invitationId, true);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (result != null && result['success'] == true && result['gameId'] != null) {
        if (result['isLudo'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerLudoScreen(
                gameId: result['gameId'],
                playerNumber: result['playerNumber'] ?? 2,
                matchType: result['matchType'] ?? '',
              ),
            ),
          );
        } else if (result['isDominoPase'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerDominoPaseScreen(
                gameId: result['gameId'],
                playerNumber: result['playerNumber'] ?? 2,
                matchType: result['matchType'] ?? '',
              ),
            ),
          );
        } else if (result['isDomino'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerDominoScreen(
                gameId: result['gameId'],
                playerNumber: result['playerNumber'] ?? 2,
                matchType: result['matchType'] ?? '',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerChessScreen(
                gameId: result['gameId'],
                isHost: false,
                matchType: result['matchType'] ?? "",
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).errorAcceptInvitation), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).errorProcessInvitation), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _validateUserFundsForInvitation(BuildContext context, String userId) async {
    try {
      final FirestoreService firestoreService = FirestoreService();
      final userDoc = await firestoreService.getUser(userId);

      if (!context.mounted) return false;
      if (userDoc == null) {
        _showInsufficientFundsDialog(context, "Error al cargar datos del usuario", "", 0, 0, Icons.error);
        return false;
      }

      final userCoins = userDoc.coins;
      final userDiamonds = userDoc.diamonds;

      if (userCoins < 100 && userDiamonds < 50) {
        _showInsufficientFundsDialog(
            context,
            S.of(context).insufficientFunds,
            "${S.of(context).notEnoughCurrencyForMultiplayer}.\n\n"
                "${S.of(context).funGamesRequirement}.\n"
                "${S.of(context).betGamesRequirement}\n\n"
                "T${S.of(context).youHave}: $userCoins ${S.of(context).coins} y $userDiamonds ${S.of(context).diamonds}",
            userCoins,
            userDiamonds,
            Icons.warning
        );
        return false;
      }

      return true;
    } catch (e) {
      _showInsufficientFundsDialog(context, "Error", "Error al validar fondos del usuario", 0, 0, Icons.error);
      return false;
    }
  }


  void _showInsufficientFundsDialog(
      BuildContext context,
      String title,
      String message,
      int coins,
      int diamonds,
      IconData icon
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Juega contra la computadora o compra más monedas/diamantes en la tienda.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back),
            label: Text("Entendido"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _declineInvitation(String invitationId) async {
    await GameInvitationService().respondToInvitation(invitationId, false);
  }

}

class NotificationsWidget extends StatelessWidget {
  const NotificationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationService().getUserNotifications(currentUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox();
        }

        final notifications = snapshot.data!;
        final unreadCount = notifications.where((n) => n['read'] != true).length;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                _showNotificationsDialog(context, notifications);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDialog(BuildContext context, List<Map<String, dynamic>> notifications) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
             S.of(context).invitations,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close, size: 24),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: notifications.isEmpty
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
               S.of(context).noInvitation,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          )
              : ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['read'] == true;
              final title = notification['title']?.toString() ?? 'Sin título';
              final body = notification['body']?.toString() ?? '';

              return Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRead ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getNotificationIcon(notification['type']),
                          color: isRead ? Colors.grey : Color(0xFFEC7A34),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              if (body.isNotEmpty) ...[
                                SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    body,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification['type'] == 'invitation') ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(S.of(context).reject),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFEC7A34),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(S.of(context).accept),
                            ),
                          ),
                        ],
                      ),
                    ],
                    GestureDetector(
                      onTap: () async {
                        if (!isRead) {
                          await NotificationService().markAsRead(notification['id']);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        height: 20,
                        color: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'game_invitation':
        return Icons.mail;
      case 'game_move':
        return Icons.sports_esports;
      case 'game_finished':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }
}