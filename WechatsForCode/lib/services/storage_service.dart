import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadChatImage(String chatId, File imageFile) async {
  try {
    final String imageId = _uuid.v4();
    final ref = _storage.ref().child('chat_images').child(chatId).child('$imageId.jpg');
   
    final uploadTask = ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
   
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
   
    return downloadUrl;
  } catch (e) {
    print('Erreur lors du téléchargement: $e');
    rethrow;
  }
}

Future<String> uploadChatAudio(String name, File file) async {
    final ref = _storage.ref().child('chat_audios/$name.m4a');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }


  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      rethrow;
    }
  }
}