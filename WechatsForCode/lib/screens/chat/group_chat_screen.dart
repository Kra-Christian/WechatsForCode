import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupPhoto;

  const GroupChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupPhoto,
  }) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final DatabaseService _db = DatabaseService();
  final StorageService _storage = StorageService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<MessageModel> _messages = [];
  Map<String, UserModel> _members = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _subscribeMessages();
  }

  Future<void> _loadMembers() async {
    final doc = await _db.groupsCollection.doc(widget.groupId).get();
    final ids = List<String>.from((doc.data() as Map<String, dynamic>?)?['members'] ?? []);
    for (var uid in ids) {
      final user = await _db.getUserById(uid);
      if (user != null) _members[uid] = user;
    }
    setState(() {});
  }

  void _subscribeMessages() {
    _db.groupMessagesStream(widget.groupId).listen((msgs) {
      setState(() => _messages = msgs);
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    await _db.sendGroupMessage(
      groupId: widget.groupId,
      senderId: user.uid,
      content: text,
      type: MessageType.text,
    );
    _controller.clear();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _isSending = false);
  }

  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _isSending = true);
    final file = File(picked.path);
    final url = await _storage.uploadChatImage(widget.groupId, file);
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    await _db.sendGroupMessage(
      groupId: widget.groupId,
      senderId: user.uid,
      content: url,
      type: MessageType.image,
    );
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _isSending = false);
  }

  Future<void> _startGroupCall() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser!;
    final channelId = widget.groupId;

    await Permission.camera.request();
    await Permission.microphone.request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: 'a1cf0c0d00c244b99997769e9c730540'));
    await engine.enableVideo();
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    await engine.joinChannel(
      token: '007eJxTYFD67Zu8Z/pOh3X+n013LVc8wOP/QS+Jm+OSg1PRXVXu/zoKDImGyWkGyQYpBgbJRiYmSZZAYG5uZplqmWxubGBqYlBSwJXREMjIcI2tmpGRAQJBfH6GlMzi5NKSzPy8osSCzJRUBgYANqghjw==',
      channelId: channelId,
      uid: user.uid.hashCode,
      options: const ChannelMediaOptions(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Appel vidéo: ${widget.groupName}'),
        content: SizedBox(
          height: 300,
          child: Center(child: Text('Vous êtes connecté au canal $channelId')),
        ),
        actions: [
          TextButton(
            child: const Text('Quitter'),
            onPressed: () async {
              await engine.leaveChannel();
              await engine.release();
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = Provider.of<AuthService>(context).currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.groupPhoto.isNotEmpty
                  ? NetworkImage(widget.groupPhoto)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.groupName)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startGroupCall,
          ),
          PopupMenuButton<String>(
            onSelected: (cmd) async {
              if (cmd == 'leave') {
                await _db.leaveGroup(widget.groupId, currentUid);
                Navigator.pop(context);
              } else if (cmd == 'delete') {
                await _db.deleteGroup(widget.groupId);
                Navigator.pop(context);
              }
            },
            itemBuilder: (_) {
              final isAdmin = (_members[currentUid]?.uid ?? '') == _members[currentUid]?.uid;
              return [
                const PopupMenuItem(value: 'leave', child: Text('Quitter le groupe')),
                if (isAdmin)
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer le groupe')),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final sender = _members[msg.senderId];
                final isMe = msg.senderId == currentUid;
                return Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (sender != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: sender.photoUrl.isNotEmpty
                                  ? NetworkImage(sender.photoUrl)
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sender.displayName,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    MessageBubble(
                      message: msg,
                      isMe: isMe,
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.photo), onPressed: _sendImage),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(hintText: 'Message...'),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send),
                  onPressed: _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
