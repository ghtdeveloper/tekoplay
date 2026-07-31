import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });
}

class GameChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName;
  final String gameId;
  late final enc.Key _key;
  late final enc.IV _iv;

  GameChatService({required this.collectionName, required this.gameId}) {
    final keyBase = gameId.padRight(32, '0').substring(0, 32);
    _key = enc.Key.fromUtf8(keyBase);
    _iv = enc.IV.fromUtf8(gameId.padRight(16, '0').substring(0, 16));
  }

  String _encrypt(String plainText) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    return encrypter.encrypt(plainText, iv: _iv).base64;
  }

  String _decrypt(String encryptedText) {
    try {
      final encrypter = enc.Encrypter(enc.AES(_key));
      return encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (_) {
      return '???';
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final encrypted = _encrypt(text);
    await _firestore
        .collection(collectionName)
        .doc(gameId)
        .collection('chat')
        .add({
      'senderId': senderId,
      'senderName': _encrypt(senderName),
      'text': encrypted,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatMessage>> getMessages() {
    return _firestore
        .collection(collectionName)
        .doc(gameId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        return ChatMessage(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          senderName: _decrypt(data['senderName'] ?? ''),
          text: _decrypt(data['text'] ?? ''),
          timestamp: ts?.toDate() ?? DateTime.now(),
        );
      }).toList();
    });
  }
}
