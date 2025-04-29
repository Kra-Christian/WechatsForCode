import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String status;
  final DateTime lastSeen;
  final bool isOnline;
    final List<String> blockedUsers; 

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName, 
    required this.photoUrl,
    required this.status,
    required this.lastSeen,
    required this.isOnline,
    this.blockedUsers = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      status: data['status'] ?? 'Hey, I am using Chat App',
      lastSeen: data['lastSeen'] != null 
        ? (data['lastSeen'] as Timestamp).toDate() 
        : DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      blockedUsers: (data['blockedUsers'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'status': status,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
      'blockedUsers': blockedUsers,
    };
  }

   bool hasBlocked(String userId) {
    return blockedUsers.contains(userId);
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? status,
    DateTime? lastSeen,
    bool? isOnline,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}