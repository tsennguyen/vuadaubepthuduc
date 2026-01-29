import 'package:cloud_firestore/cloud_firestore.dart';

class UserSummary {
  const UserSummary({
    required this.uid,
    this.displayName,
    this.photoUrl,
    this.email,
  });

  final String uid;
  final String? displayName;
  final String? photoUrl;
  final String? email;

  factory UserSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserSummary(
      uid: doc.id,
      displayName:
          (data['displayName'] ?? data['fullName'] ?? data['name']) as String?,
      photoUrl: data['photoURL'] as String?,
      email: data['email'] as String?,
    );
  }
}
