import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  
  CollectionReference get groupsCollection  => _firestore.collection('groups');
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _chatsCollection => _firestore.collection('chats');
  CollectionReference get _messagesCollection => _firestore.collection('messages');
  CollectionReference get _groupsCollection => _firestore.collection('groups');
  

  Future<void> createUserProfile(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      rethrow;
    }
  }



  Future<T> withRetry<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 1 * attempts));
      }
    }
    throw Exception("Max retries reached");
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).update(user.toMap());
    } catch (e) {
      rethrow;
    }
  }
  
  Future<QuerySnapshot> getMessagesWithPagination(
    String chatId, {
    int limit = 30,
    DocumentSnapshot? startAfterDocument,
  }) async {
    try {
      Query query = _messagesCollection
          .where('chatId', isEqualTo: chatId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
          
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }
      
      return await query.get();
    } catch (e) {
      print('Error getting paginated messages: $e');
      rethrow;
    }
  }
  
  Future<void> markMessagesAsReadBatch(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    
    try {
      final batch = _firestore.batch();
      
      for (final message in messages) {
        batch.update(_messagesCollection.doc(message.id), {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
      rethrow;
    }
  }
  
  Future<void> createRequiredIndexes() async {
    try {
      await _firestore.collection('messages')
          .where('chatId', isEqualTo: 'placeholder')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      await _firestore.collection('users')
          .where('displayName', isGreaterThanOrEqualTo: '')
          .get();
    } catch (e) {
      print('Index creation initiated: $e');
    }
  }
  
  Future<void> createCall({
    required String callId,
    required String callerId,
    required String receiverId,
    required String callerName,
    required String callerPhoto,
    bool isVideoCall = false,
  }) async {
    await _firestore.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'duration': 0,
      'isVideoCall': isVideoCall,
    });
  }

  Future<void> updateCallStatus(String callId, String status) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCallDuration(String callId, int durationInSeconds) async {
    await _firestore.collection('calls').doc(callId).update({
      'duration': durationInSeconds,
      'endTime': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>?> callStream(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() as Map<String, dynamic> : null);
  }

  Stream<List<Map<String, dynamic>>> userCallsStream(String userId) {
    return _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data())
              .toList();
        });
  }

  Future<String> createGroup({
    required String name,
    required String creatorId,
    required List<String> memberIds,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final groupId = _uuid.v4();
      
      if (!memberIds.contains(creatorId)) {
        memberIds.add(creatorId);
      }
      
      await _groupsCollection.doc(groupId).set({
        'id': groupId,
        'name': name,
        'description': description ?? '',
        'photoUrl': photoUrl ?? '',
        'creatorId': creatorId,
        'members': memberIds,
        'admins': [creatorId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return groupId;
    } catch (e) {
      print('Erreur lors de la création du groupe: $e');
      rethrow;
    }
  }
  
  Stream<List<Map<String, dynamic>>> userGroupsStream(String userId) {
    return _groupsCollection
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
  }
  
  Future<void> addGroupMember(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> removeGroupMember(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
        'admins': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

Future<MessageModel> sendGroupMessage({
  required String groupId,
  required String senderId,
  required String content,
  required MessageType type,
}) async {
  final messageId = _uuid.v4();
  final timestamp = DateTime.now();
  final message = MessageModel(
    id: messageId,
    senderId: senderId,
    receiverId: '',
    content: content,
    type: type,
    timestamp: timestamp,
    isRead: false,
  );
  final coll = _firestore
      .collection('group_messages')
      .doc(groupId)
      .collection('messages');
  await coll.doc(messageId).set({
    ...message.toMap(),
    'groupId': groupId,
  });
  await _groupsCollection.doc(groupId).update({
    'updatedAt': timestamp,
    'lastMessage': content,
  });
  return message;
}


Stream<List<MessageModel>> groupMessagesStream(String groupId) {
  return _firestore
      .collection('group_messages')
      .doc(groupId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => MessageModel.fromMap(d.data()))
          .toList());
}

Future<QuerySnapshot> getGroupMessagesWithPagination(
  String groupId, {
  int limit = 30,
  DocumentSnapshot? startAfter,
}) {
  var q = _firestore
      .collection('group_messages')
      .doc(groupId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .limit(limit);
  if (startAfter != null) q = q.startAfterDocument(startAfter);
  return q.get();
}

Future<void> leaveGroup(String groupId, String userId) {
  return _groupsCollection.doc(groupId).update({
    'members': FieldValue.arrayRemove([userId]),
    'admins': FieldValue.arrayRemove([userId]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteGroup(String groupId) async {
  final batch = _firestore.batch();
  final msgsSnap = await _firestore
      .collection('group_messages')
      .doc(groupId)
      .collection('messages')
      .get();
  for (var doc in msgsSnap.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
  await _groupsCollection.doc(groupId).delete();
  await _firestore.collection('group_messages').doc(groupId).delete();
}

Future<void> markGroupMessagesAsReadBatch(
  String groupId,
  List<MessageModel> messages,
) async {
  if (messages.isEmpty) return;
  final batch = _firestore.batch();
  final coll = _firestore
      .collection('group_messages')
      .doc(groupId)
      .collection('messages');
  for (final m in messages) {
    batch.update(coll.doc(m.id), {'isRead': true});
  }
  await batch.commit();
}

Future<void> updateGroupTypingStatus(
  String groupId,
  String userId,
  bool isTyping,
) async {
  await _groupsCollection.doc(groupId).update({
    'typing.$userId': isTyping,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}


  Future<bool> checkConnection() async {
    try {
      await _firestore.collection('users').limit(1).get(GetOptions(source: Source.server));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateUserStatus(String uid, bool isOnline, {DateTime? lastSeen}) async {
    try {
      final Map<String, dynamic> data = {
        'isOnline': isOnline,
        'lastSeen': lastSeen ?? DateTime.now(),
      };

      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Erreur mise à jour statut: $e');
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de l\'utilisateur: $e');
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).update(user.toMap());
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'utilisateur: $e');
      rethrow;
    }
  }

  Future<void> blockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.update(_usersCollection.doc(currentUserId), {
          'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
        });
        
        final chatQuery = await _chatsCollection
            .where('participants', arrayContains: currentUserId)
            .get();
        
        for (final chatDoc in chatQuery.docs) {
          final participants = (chatDoc.data() as Map<String, dynamic>)['participants'] as List<dynamic>;
          if (participants.contains(blockedUserId)) {
            transaction.update(chatDoc.reference, {
              'blockedBy': FieldValue.arrayUnion([currentUserId]),
            });
          }
        }
      });
    } catch (e) {
      print('Erreur lors du blocage de l\'utilisateur: $e');
      rethrow;
    }
  }

  Future<void> unblockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.update(_usersCollection.doc(currentUserId), {
          'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
        });
        
        final chatQuery = await _chatsCollection
            .where('participants', arrayContains: currentUserId)
            .get();
        
        for (final chatDoc in chatQuery.docs) {
          final participants = (chatDoc.data() as Map<String, dynamic>)['participants'] as List<dynamic>;
          if (participants.contains(blockedUserId)) {
            transaction.update(chatDoc.reference, {
              'blockedBy': FieldValue.arrayRemove([currentUserId]),
            });
          }
        }
      });
    } catch (e) {
      print('Erreur lors du déblocage de l\'utilisateur: $e');
      rethrow;
    }
  }

  Future<bool> isUserBlocked({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final userDoc = await _usersCollection.doc(currentUserId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final blockedUsers = userData['blockedUsers'] as List<dynamic>? ?? [];
      
      return blockedUsers.contains(otherUserId);
    } catch (e) {
      print('Erreur lors de la vérification du blocage: $e');
      return false;
    }
  }

  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return [];
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final blockedUsers = userData['blockedUsers'] as List<dynamic>? ?? [];
      
      return blockedUsers.cast<String>();
    } catch (e) {
      print('Erreur lors de la récupération des utilisateurs bloqués: $e');
      return [];
    }
  }

  Future<List<MessageModel>> searchMessages(String chatId, String query) async {
    try {
      if (query.length < 2) return [];
      
      final searchQuery = query.toLowerCase();
      
      final snapshot = await _messagesCollection
          .where('chatId', isEqualTo: chatId)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final results = snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((message) => 
              message.content.toLowerCase().contains(searchQuery) &&
              message.type == MessageType.text)
          .toList();
      
      results.sort((a, b) {
        final aStartsWith = a.content.toLowerCase().startsWith(searchQuery);
        final bStartsWith = b.content.toLowerCase().startsWith(searchQuery);
        
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });
      
      return results.take(20).toList();
    } catch (e) {
      print('Erreur lors de la recherche de messages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getChatById(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) {
        throw Exception('Chat not found');
      }
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error getting chat: $e');
      rethrow;
    }
  }

  Future<void> updateChatMuteStatus(
    String chatId,
    String userId,
    bool isMuted,
  ) async {
    try {
      await _chatsCollection.doc(chatId).update({
        'mutedBy': isMuted 
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print('Error updating mute status: $e');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> chatStream(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception('Chat not found');
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String chatId,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId) async {
    int deletedMessages = 0;
    int totalMessages = 0;
    
    try {
      final messages = await _messagesCollection
          .where('chatId', isEqualTo: chatId)
          .get();
      
      totalMessages = messages.docs.length;
      
      final imageUrls = <String>[];
      for (var doc in messages.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['type'] == MessageType.image.index) {
          imageUrls.add(data['content'] as String);
        }
      }
      
      const batchSize = 500;
      
      for (var i = 0; i < messages.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < messages.docs.length) ? i + batchSize : messages.docs.length;
        
        for (var j = i; j < end; j++) {
          batch.delete(messages.docs[j].reference);
        }
        
        await batch.commit();
        deletedMessages += (end - i);
      }
      
      await _chatsCollection.doc(chatId).delete();
      
      if (imageUrls.isNotEmpty) {
        final storageService = StorageService();
        for (final url in imageUrls) {
          try {
            await storageService.deleteFile(url);
          } catch (e) {
            print('Erreur suppression image $url: $e');
          }
        }
      }
      
      print('Conversation supprimée avec succès: $deletedMessages messages sur $totalMessages');
    } catch (e) {
      print('Erreur suppression conversation: $e');
      throw Exception('La suppression de la conversation a échoué. Veuillez réessayer.');
    }
  }

  Stream<bool> userOnlineStream(String userId) {
    return _usersCollection
        .doc(userId)
        .snapshots()
        .map((snap) => (snap.data() as Map<String, dynamic>?)?['isOnline'] ?? false);
  }

  Stream<UserModel?> userStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  Stream<List<ChatModel>> userChatsStream(String userId) {
    return _chatsCollection
      .where('participants', arrayContains: userId)
      .snapshots()
      .asyncMap((snapshot) async {
        final chats = <ChatModel>[];
        
        for (final doc in snapshot.docs) {
          final chatData = doc.data() as Map<String, dynamic>;
          
          final lastMessageQuery = await _messagesCollection
              .where('chatId', isEqualTo: doc.id)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
          
          if (lastMessageQuery.docs.isNotEmpty) {
            final lastMessageData = lastMessageQuery.docs.first.data() as Map<String, dynamic>;
            final lastMessage = MessageModel.fromMap(lastMessageData);
            chats.add(ChatModel.fromMap(chatData, lastMessage));
          }
        }
        
        chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return chats;
      });
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final snapshot = await _usersCollection
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
        
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }

  Future<String> createOrGetChatId(String userId1, String userId2) async {
    try {
      final users = [userId1, userId2]..sort();
      
      final query = await _chatsCollection
          .where('participants', isEqualTo: users)
          .limit(1)
          .get();
        
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      
      final chatId = _uuid.v4();
      await _chatsCollection.doc(chatId).set({
        'id': chatId,
        'participants': users,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'mutedBy': [],
        'blockedBy': [],
      });
      
      return chatId;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _chatsCollection.doc(chatId).update({
        'typing.$userId': isTyping,
      });
    } catch (e) {
      print('Error updating typing status: $e');
      rethrow;
    }
  }

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _messagesCollection
      .where('chatId', isEqualTo: chatId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      });
  }

  Future<MessageModel> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    required MessageType type,
  }) async {
    try {
      final messageId = _uuid.v4();
      final timestamp = DateTime.now();
    
      final message = MessageModel(
        id: messageId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        type: type,
        timestamp: timestamp,
        isRead: false,
      );
    
      await _messagesCollection.doc(messageId).set({
        ...message.toMap(),
        'chatId': chatId,
      });
    
      await _chatsCollection.doc(chatId).update({
        'lastMessageId': messageId,
        'updatedAt': timestamp,
      });
    
      return message;
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesCollection.doc(messageId).delete();
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }
}
