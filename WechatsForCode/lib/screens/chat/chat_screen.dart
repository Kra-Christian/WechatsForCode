import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:record/record.dart' as audio_record;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:wecode_by_chat/screens/profile/view_profile_screen.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../widgets/message_bubble.dart';
import '../../config/theme.dart';
import '../profile/profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel receiverUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.receiverUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isShowEmojiPicker = false;
  bool _isSending = false;
  bool _isTyping = false;
  bool _wasConnected = true;
  bool _isUserBlocked = false;
  Timer? _reconnectionTimer;
  Timer? _typingTimer;
  Timer? _typingDebounceTimer;
    StreamSubscription? _messagesSubscription;
  
  List<MessageModel> _cachedMessages = [];
  bool _isLoadingMessages = true;
  
  int _messageLimit = 30;
  bool _hasMoreMessages = true;
  bool _isLoadingMoreMessages = false;
  DocumentSnapshot? _lastVisibleMessage;

final audio_record.AudioRecorder _recorder = audio_record.AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  late RtcEngine _engine;
  int? _remoteUid;
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupConnectionListener();
    _setupUserPresence();
    _checkBlockStatus();
    _loadInitialMessages();
    _setupMessagesListener();
    
    _scrollController.addListener(_scrollListener);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isShowEmojiPicker = false;
        });
      }
    });
    
    _messageController.addListener(_onTextChanged);
  }
  
  Future<void> _checkBlockStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser!.uid;
    
    final isBlocked = await _databaseService.isUserBlocked(
      currentUserId: currentUserId,
      otherUserId: widget.receiverUser.uid,
    );
    
    if (mounted) {
      setState(() {
        _isUserBlocked = isBlocked;
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser!.uid;
    
    if (state == AppLifecycleState.resumed) {
      _databaseService.updateUserStatus(currentUserId, true);
      _markMessagesAsRead();
      _checkBlockStatus();
    } else if (state == AppLifecycleState.paused) {
      _databaseService.updateUserStatus(
        currentUserId, 
        false,
        lastSeen: DateTime.now(),
      );
    }
  }
  
Future<void> _loadInitialMessages() async {
  setState(() {
    _isLoadingMessages = true;
  });
  
  try {
    final snapshot = await _databaseService.getMessagesWithPagination(
      widget.chatId,
      limit: _messageLimit,
    );
    
    final messages = snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
    
    if (snapshot.docs.isNotEmpty) {
      _lastVisibleMessage = snapshot.docs.last;
      _hasMoreMessages = snapshot.docs.length >= _messageLimit;
    } else {
      _hasMoreMessages = false;
    }
    
    setState(() {
      _cachedMessages = messages;
      _isLoadingMessages = false;
    });
    
    _markMessagesAsRead();
  } catch (e) {
    setState(() {
      _isLoadingMessages = false;
    });
    _handleError('Erreur lors du chargement des messages: ${e.toString()}');
  }
}
  
  void _scrollListener() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _startRecording() async {
  if (await Permission.microphone.request().isGranted) {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    _audioPath = path;

    await _recorder.start(
      const audio_record.RecordConfig(), 
      path: path,
    );
    setState(() => _isRecording = true);
  }
}

Future<void> _stopRecording() async {
  await _recorder.stop();
  setState(() => _isRecording = false);

  if (_audioPath != null) {
    final file = File(_audioPath!);
    if (await file.exists()) {
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser!.uid;
      
      final tempMessage = MessageModel(
        id: tempId,
        senderId: currentUserId,
        receiverId: widget.receiverUser.uid,
        content: _audioPath!,
        type: MessageType.audio,
        timestamp: DateTime.now(),
        isRead: false,
      );
      
      setState(() {
        _cachedMessages.insert(0, tempMessage);
      });
      
      try {
        final url = await StorageService().uploadChatAudio(widget.chatId, file);
        final msg = await DatabaseService().sendMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          receiverId: widget.receiverUser.uid,
          content: url,
          type: MessageType.audio,
        );
        
        if (mounted) {
          setState(() {
            final index = _cachedMessages.indexWhere((m) => m.id == tempId);
            if (index != -1) {
              _cachedMessages[index] = msg;
            }
          });
        }
      } catch (e) {
        _handleError('Erreur lors de l\'envoi du message audio: ${e.toString()}');
        
        if (mounted) {
          setState(() {
            _cachedMessages.removeWhere((m) => m.id == tempId);
          });
        }
      }
    }
  }
}

  
Future<void> _loadMoreMessages() async {
  if (!_hasMoreMessages || _isLoadingMoreMessages || _lastVisibleMessage == null) return;
  
  setState(() {
    _isLoadingMoreMessages = true;
  });
  
  try {
    final snapshot = await _databaseService.getMessagesWithPagination(
      widget.chatId,
      limit: _messageLimit,
      startAfterDocument: _lastVisibleMessage,
    );
    
    final moreMessages = snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
    
    if (snapshot.docs.isNotEmpty) {
      _lastVisibleMessage = snapshot.docs.last;
      _hasMoreMessages = snapshot.docs.length >= _messageLimit;
      
      setState(() {
        _cachedMessages.addAll(moreMessages);
        _isLoadingMoreMessages = false;
      });
    } else {
      setState(() {
        _hasMoreMessages = false;
        _isLoadingMoreMessages = false;
      });
    }
  } catch (e) {
    setState(() {
      _isLoadingMoreMessages = false;
    });
    _handleError('Erreur lors du chargement des messages: ${e.toString()}');
  }
}

  void _onTextChanged() {
    final text = _messageController.text;
    final shouldBeTyping = text.isNotEmpty;
    
    if (shouldBeTyping != _isTyping) {
      _typingDebounceTimer?.cancel();
      
      _typingDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && shouldBeTyping != _isTyping) {
          _isTyping = shouldBeTyping;
          
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUserId = authService.currentUser!.uid;
          
          _databaseService.updateTypingStatus(
            widget.chatId,
            currentUserId,
            _isTyping
          );
          
          _typingTimer?.cancel();
          if (_isTyping) {
            _typingTimer = Timer(const Duration(seconds: 3), () {
              if (mounted && _isTyping) {
                _isTyping = false;
                _databaseService.updateTypingStatus(
                  widget.chatId,
                  currentUserId,
                  false
                );
              }
            });
          }
        }
      });
    }
  }

void _setupMessagesListener() {
  _messagesSubscription = _databaseService.messagesStream(widget.chatId).listen((messagesFromStream) {
    if (mounted) {
      setState(() {
        Map<String, MessageModel> messagesMap = {
          for (var msg in _cachedMessages) msg.id: msg
        };
        
        for (var message in messagesFromStream) {
          if (!messagesMap.containsKey(message.id) || 
              messagesMap[message.id]!.isRead != message.isRead) {
            messagesMap[message.id] = message;
          }
        }
        
        _cachedMessages = messagesMap.values.toList();
        _cachedMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _isLoadingMessages = false;
      });
      
      _markMessagesAsRead();
    }
  }, onError: (error) {
    _handleError('Erreur lors de la récupération des messages: ${error.toString()}');
  });
}

  void _setupConnectionListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        if (_wasConnected) {
          _handleError('Connexion perdue');
          _wasConnected = false;
        }
      } else {
        if (!_wasConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion rétablie'),
              backgroundColor: Colors.green,
            ),
          );
          _wasConnected = true;
          _markMessagesAsRead();
        }
      }
    });
  }

  void _setupUserPresence() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _databaseService.updateUserStatus(
      authService.currentUser!.uid,
      true,
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    final messages = <MessageModel>[];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Rechercher dans la conversation'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Entrez votre recherche...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        setDialogState(() {
                          isSearching = true;
                        });
                        
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (searchController.text == value) {
                            _databaseService
                                .searchMessages(widget.chatId, value)
                                .then((results) {
                              if (mounted) {
                                setDialogState(() {
                                  messages.clear();
                                  messages.addAll(results);
                                  isSearching = false;
                                });
                              }
                            });
                          }
                        });
                      } else {
                        setDialogState(() {
                          messages.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isSearching && messages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Recherche en cours...'),
                    )
                  else if (!isSearching && messages.isEmpty && searchController.text.length >= 2)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Aucun résultat trouvé'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          
                          final content = message.content;
                          final query = searchController.text.toLowerCase();
                          final lowerContent = content.toLowerCase();
                          
                          final List<TextSpan> textSpans = [];
                          int currentIndex = 0;
                          
                          int searchIndex = lowerContent.indexOf(query);
                          while (searchIndex != -1) {
                            if (searchIndex > currentIndex) {
                              textSpans.add(TextSpan(
                                text: content.substring(currentIndex, searchIndex),
                              ));
                            }
                            
                            textSpans.add(TextSpan(
                              text: content.substring(searchIndex, searchIndex + query.length),
                              style: const TextStyle(
                                backgroundColor: Colors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ));
                            
                            currentIndex = searchIndex + query.length;
                            searchIndex = lowerContent.indexOf(query, currentIndex);
                          }
                          
                          if (currentIndex < content.length) {
                            textSpans.add(TextSpan(
                              text: content.substring(currentIndex),
                            ));
                          }
                          
                          return ListTile(
                            title: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: textSpans,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              timeago.format(message.timestamp, locale: 'fr'),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _scrollToMessage(message.id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectionTimer?.cancel();
    _typingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _messagesSubscription?.cancel();
    
    final authService = Provider.of<AuthService>(context, listen: false);
    _databaseService.updateUserStatus(
      authService.currentUser!.uid,
      false,
      lastSeen: DateTime.now(),
    ).catchError((e) {
      print('Erreur mise à jour statut: $e');
    });

    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleMuteNotifications() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser!.uid;
      
      final chatData = await _databaseService.getChatById(widget.chatId);
      final isMuted = chatData['mutedBy']?.contains(currentUserId) ?? false;
      
      await _databaseService.updateChatMuteStatus(
        widget.chatId,
        currentUserId,
        !isMuted,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMuted 
            ? 'Notifications réactivées' 
            : 'Conversation mise en sourdine'
          ),
        ),
      );
    } catch (e) {
      _handleError('Erreur lors de la mise à jour des notifications: ${e.toString()}');
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (!mounted) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser!.uid;
      
      final messagesToMark = _cachedMessages.isNotEmpty 
          ? _cachedMessages 
          : await _databaseService.messagesStream(widget.chatId).first;
      
      final unreadMessages = messagesToMark.where((message) => 
        message.receiverId == currentUserId && 
        !message.isRead && 
        message.senderId != currentUserId
      ).toList();
      
      if (unreadMessages.isEmpty) return;
      
      await _databaseService.markMessagesAsReadBatch(unreadMessages);
      
      if (_cachedMessages.isNotEmpty) {
        setState(() {
          for (final message in unreadMessages) {
            final index = _cachedMessages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              _cachedMessages[index] = message.copyWith(isRead: true);
            }
          }
        });
      }
    } catch (e) {
      _handleError('Erreur lors de la mise à jour des messages: ${e.toString()}');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isShowEmojiPicker = !_isShowEmojiPicker;
    });

    if (_isShowEmojiPicker) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }
  
  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search, color: Colors.blue),
              title: const Text('Rechercher dans la conversation'),
              onTap: () {
                Navigator.pop(context);
                _showSearchDialog();
              },
            ),
            StreamBuilder<Map<String, dynamic>>(
              stream: _databaseService.chatStream(widget.chatId),
              builder: (context, snapshot) {
                final isMuted = snapshot.data?['mutedBy']?.contains(
                  Provider.of<AuthService>(context, listen: false).currentUser!.uid,
                ) ?? false;
                
                return ListTile(
                  leading: Icon(
                    isMuted ? Icons.notifications_off : Icons.notifications,
                  ),
                  title: Text(
                    isMuted ? 'Réactiver les notifications' : 'Mettre en sourdine',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMuteNotifications();
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(
                _isUserBlocked ? Icons.person_add : Icons.block,
                color: _isUserBlocked ? Colors.green : Colors.orange,
              ),
              title: Text(
                _isUserBlocked 
                  ? 'Débloquer l\'utilisateur' 
                  : 'Bloquer l\'utilisateur'
              ),
              onTap: () {
                Navigator.pop(context);
                _showBlockUserDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer la conversation'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_isUserBlocked) {
      _handleError('Vous ne pouvez pas envoyer de messages à cet utilisateur car il est bloqué.');
      return;
    }

    PermissionStatus status;

    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.photos.request().isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = PermissionStatus.denied;
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      if (!mounted) return;
      _handleError('Permission d\'accès aux photos refusée');
      return;
    }

    try {
      setState(() {
        _isSending = true;
      });

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        await _sendImageMessage(File(image.path));
      }
    } catch (e) {
      _handleError('Erreur lors de la sélection de l\'image: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
  Future<void> _sendTextMessage() async {
  final text = _messageController.text.trim();
  if (text.isEmpty || _isSending) return;
  
  if (_isUserBlocked) {
    _handleError('Vous ne pouvez pas envoyer de messages à cet utilisateur car il est bloqué.');
    return;
  }

  _messageController.clear();

  bool wasSending = _isSending;
  _isSending = true;

  try {
    final result = await InternetConnectionChecker().hasConnection;
    if (!result) {
      throw Exception('Pas de connexion Internet');
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser!.uid;

    final newMessage = await _databaseService.sendMessage(
      chatId: widget.chatId,
      senderId: currentUserId,
      receiverId: widget.receiverUser.uid,
      content: text,
      type: MessageType.text,
    );
    
    if (mounted) {
      setState(() {
        if (!_cachedMessages.any((m) => m.id == newMessage.id)) {
          _cachedMessages.insert(0, newMessage);
        }
      });
    }

    _scrollToBottom();
  } catch (e) {
    _handleError('Erreur d\'envoi: ${e.toString()}');
    _messageController.text = text;
  } finally {
    if (mounted) {
      setState(() {
        _isSending = wasSending;
      });
    }
  }
}

  Future<void> _sendImageMessage(File imageFile) async {
  if (_isUserBlocked) {
    _handleError('Vous ne pouvez pas envoyer de messages à cet utilisateur car il est bloqué.');
    return;
  }
  
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('L\'image est trop volumineuse (max 5MB)');
      }
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);
      final currentUserId = authService.currentUser!.uid;

      final result = await InternetConnectionChecker().hasConnection;
      if (!result) {
        throw Exception('Pas de connexion Internet');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrl = await storageService.uploadChatImage(
        "${widget.chatId}_$timestamp",
        imageFile
      );
      
      final newMessage = await _databaseService.sendMessage(
        chatId: widget.chatId,
        senderId: currentUserId,
        receiverId: widget.receiverUser.uid,
        content: imageUrl,
        type: MessageType.image,
      );
      
      if (mounted) {
        setState(() {
          _cachedMessages.insert(0, newMessage);
        });
        _scrollToBottom();
      }
      
      break;
    } catch (e) {
      retryCount++;
      if (retryCount == maxRetries) {
        _handleError('Échec de l\'envoi de l\'image après $maxRetries tentatives: ${e.toString()}');
      } else {
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }
}


  void _showBlockUserDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser!.uid;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isUserBlocked ? 'Débloquer l\'utilisateur' : 'Bloquer l\'utilisateur'),
        content: Text(
          _isUserBlocked 
            ? 'Voulez-vous débloquer ${widget.receiverUser.displayName} ? Vous pourrez à nouveau échanger des messages.'
            : 'En bloquant ${widget.receiverUser.displayName}, vous ne recevrez plus ses messages. Continuer ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (_isUserBlocked) {
                  await _databaseService.unblockUser(
                    currentUserId: currentUserId,
                    blockedUserId: widget.receiverUser.uid,
                  );
                  if (!mounted) return;
                  
                  setState(() {
                    _isUserBlocked = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.receiverUser.displayName} a été débloqué')),
                  );
                } else {
                  await _databaseService.blockUser(
                    currentUserId: currentUserId,
                    blockedUserId: widget.receiverUser.uid,
                  );
                  if (!mounted) return;
                  
                  setState(() {
                    _isUserBlocked = true;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.receiverUser.displayName} a été bloqué')),
                  );
                }
              } catch (e) {
                _handleError('Erreur: ${e.toString()}');
              }
            },
            child: Text(
              _isUserBlocked ? 'Débloquer' : 'Bloquer',
              style: TextStyle(color: _isUserBlocked ? Colors.blue : Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: const Text(
          'Cette action supprimera définitivement tous les messages et fichiers partagés. Cette opération est irréversible. Voulez-vous continuer ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Suppression de la conversation en cours...'),
                    ],
                  ),
                ),
              );
              
              try {
                await _databaseService.deleteChat(widget.chatId);
                
                if (!mounted) return;
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation supprimée avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Supprimer', 
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCall() async {
  if (!await Permission.microphone.request().isGranted ||
      !await Permission.camera.request().isGranted) {
    _handleError('Permissions microphone et caméra requises');
    return;
  }
  
  if (_isUserBlocked) {
    _handleError('Utilisateur bloqué, appel impossible');
    return;
  }

  final auth = Provider.of<AuthService>(context, listen: false);
  final me = auth.currentUser!;
  
  if (me.uid == widget.receiverUser.uid) {
    _handleError('Vous ne pouvez pas vous appeler vous-même');
    return;
  }

  final callId = '${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}';

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoCallScreen(
        callId: callId,
        userId: me.uid,
        otherUserId: widget.receiverUser.uid,
        otherUserName: widget.receiverUser.displayName,
        otherUserPhoto: widget.receiverUser.photoUrl,
        isIncoming: false,
        isVideoCall: true,
      ),
    ),
  );
}

  Future<void> _endCall() async {
    await _engine.leaveChannel();
    await _engine.release();
    setState(() {
      _inCall = false;
      _remoteUid = null;
    });
  }

  void _showOutgoingCallUI(String callId, RtcEngine engine) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Appel vidéo vers ${widget.receiverUser.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: widget.receiverUser.photoUrl.isNotEmpty
                  ? NetworkImage(widget.receiverUser.photoUrl)
                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
            ),
            const SizedBox(height: 20),
            const Text('Appel en cours...'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(15),
                  ),
                  onPressed: () {
                    engine.leaveChannel();
                    _databaseService.updateCallStatus(callId, 'cancelled');
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  

  Future<void> _scrollToMessage(String messageId) async {
    final index = _cachedMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _scrollController.animateTo(
        index * 60.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      final messages = await _databaseService.messagesStream(widget.chatId).first;
      final dbIndex = messages.indexWhere((m) => m.id == messageId);
      if (dbIndex != -1) {
        _scrollController.animateTo(
          dbIndex * 60.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onMessageLongPress(MessageModel message) {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (message.senderId != authService.currentUser!.uid) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer le message'),
              onTap: () async {
                Navigator.pop(context);
                
                try {
                  if (message.type == MessageType.image) {
                    final storageService = Provider.of<StorageService>(context, listen: false);
                    await storageService.deleteFile(message.content);
                  }
                  
                  await _databaseService.deleteMessage(message.id);
                  
                  if (mounted) {
                    setState(() {
                      _cachedMessages.removeWhere((m) => m.id == message.id);
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _getDateText(date),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Aujourd\'hui';
    } else if (dateToCheck == yesterday) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUser: widget.receiverUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser!.uid;


     if (_inCall) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
          if (_remoteUid != null)
            Positioned(
              right: 20,
              top: 20,
              width: 120,
              height: 160,
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: _remoteUid!),
                  connection: const RtcConnection(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end),
                onPressed: _endCall,
              ),
            ),
          ),
        ],
      ),
    );
  }
    
    return PopScope(
      canPop: !_isShowEmojiPicker,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _isShowEmojiPicker) {
          setState(() {
            _isShowEmojiPicker = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leadingWidth: 30,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
         title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewProfileScreen(user: widget.receiverUser),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.receiverUser.photoUrl.isNotEmpty
                    ? NetworkImage(widget.receiverUser.photoUrl)
                    : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
              ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.receiverUser.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: _databaseService.userOnlineStream(
                          widget.receiverUser.uid
                        ),
                        builder: (context, snapshot) {
                          final isOnline = snapshot.data ?? false;
                          return Text(
                            isOnline 
                              ? 'En ligne'
                              : 'Vu ${timeago.format(
                                  widget.receiverUser.lastSeen,
                                  locale: 'fr_short'
                                )}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.grey),
              onPressed: _showSearchDialog,
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: AppTheme.primaryColor),
              onPressed: _handleCall,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onPressed: _showChatOptions,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isUserBlocked)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vous avez bloqué ${widget.receiverUser.displayName}. Vous ne pouvez pas échanger de messages.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showBlockUserDialog(),
                      child: const Text('Débloquer'),
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _cachedMessages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun message',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Envoyez un message pour démarrer la conversation',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _cachedMessages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _cachedMessages.length) {
                          return _isLoadingMoreMessages
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const SizedBox.shrink();
                        }
                        
                        final message = _cachedMessages[index];
                        final isMe = message.senderId == currentUserId;
                        
                        if (_isUserBlocked && !isMe) {
                          return const SizedBox.shrink();
                        }
                        
                        final showDateHeader = index == 0 || 
                          !_isSameDay(_cachedMessages[index].timestamp, _cachedMessages[index - 1].timestamp);
                        
                        return Column(
                          children: [
                            if (showDateHeader)
                              _buildDateHeader(message.timestamp),
                            MessageBubble(
                              message: message,
                              isMe: isMe,
                              onLongPress: () => _onMessageLongPress(message),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            
            if (!_isUserBlocked)
              StreamBuilder<Map<String, dynamic>>(
                stream: _databaseService.chatStream(widget.chatId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final typingData = snapshot.data?['typing'] as Map<String, dynamic>? ?? {};
                  final isReceiverTyping = typingData[widget.receiverUser.uid] == true;

                  if (isReceiverTyping) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${widget.receiverUser.displayName} est en train d\'écrire...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            
            _isUserBlocked
              ? Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade200,
                  child: const Text(
                    'Vous ne pouvez pas envoyer de messages à cet utilisateur car il est bloqué',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isShowEmojiPicker 
                              ? Icons.keyboard 
                              : Icons.emoji_emotions_outlined,
                            color: AppTheme.primaryColor,
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                        IconButton(
                          icon: const Icon(Icons.image, color: AppTheme.primaryColor),
                          onPressed: _pickImage,
                        ),
                        IconButton(
                                icon: Icon(
                                  _isRecording ? Icons.mic_off : Icons.mic,
                                  color: AppTheme.primaryColor,
                                ),
                                onPressed: () async {
                                  if (_isRecording) {
                                    await _stopRecording();
                                  } else {
                                    await _startRecording();
                                  }
                                },
                              ),

                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                hintText: 'Tapez un message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                              onSubmitted: (_) => _sendTextMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendTextMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            
            if (_isShowEmojiPicker && !_isUserBlocked)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      final text = _messageController.text;
                      
                      final selection = _messageController.selection.isValid 
                          ? _messageController.selection 
                          : TextSelection.collapsed(offset: text.length);
                          
                      final start = selection.start;
                      final end = selection.end;
                      
                      final newText = text.replaceRange(start, end, emoji.emoji);
                      
                      _messageController.text = newText;
                      _messageController.selection = TextSelection.collapsed(
                        offset: start + emoji.emoji.length,
                      );
                      
                      _onTextChanged();
                    },
                  config: const Config(
                    columns: 7,
                    emojiSizeMax: 32,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    initCategory: Category.RECENT,
                    bgColor: Color(0xFFF2F2F2),
                    indicatorColor: AppTheme.primaryColor,
                    iconColor: Colors.grey,
                    iconColorSelected: AppTheme.primaryColor,
                    backspaceColor: AppTheme.primaryColor,
                    skinToneDialogBgColor: Colors.white,
                    skinToneIndicatorColor: Colors.grey,
                    recentsLimit: 28,
                    noRecents: Text('Pas de récents'),
                    tabIndicatorAnimDuration: Duration(milliseconds: 200),
                    categoryIcons: CategoryIcons(),
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
