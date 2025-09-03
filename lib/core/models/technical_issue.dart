import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicalIssue {
  final String id;
  final String? issueUserId;
  final String message;
  final DateTime createdAt;
  final String status;

  TechnicalIssue({
    required this.id,
    required this.issueUserId,
    required this.message,
    required this.createdAt,
    required this.status,
  });

  factory TechnicalIssue.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TechnicalIssue(
      id: doc.id,
      issueUserId: data['issueUserId'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "id": id,
      "issueUserId": issueUserId,
      "message": message,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}
