import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wecode_by_chat/screens/chat/group_chat_screen.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import 'chat_screen.dart';
import '../profile/profile_screen.dart';
import 'create_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  late AuthService _authService;
  late DatabaseService _databaseService;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  
  final Map<String, UserModel> _userCache = {};
  
  Timer? _searchDebounce;
  
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _groupsSubscription;
  List<ChatModel> _chats = [];
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addObserver(this);
    
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('fr_short', timeago.FrShortMessages());
    
    _searchController.addListener(_onSearchChanged);
    
    _setupChatListener();
    _setupGroupsListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    if (_chatsSubscription == null || _groupsSubscription == null) {
      _setupChatListener();
      _setupGroupsListener();
    }
  }

  void _setupChatListener() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    _isLoading = true;
    if (mounted) setState(() {});
    
    _chatsSubscription?.cancel();
    
    _chatsSubscription = _databaseService.userChatsStream(currentUser.uid).listen(
      (chats) {
        if (mounted) {
          setState(() {
            _chats = chats;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Erreur: $error';
            _isLoading = false;
          });
        }
      },
    );
  }

  void _setupGroupsListener() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    _groupsSubscription?.cancel();
    
    _groupsSubscription = _databaseService.userGroupsStream(currentUser.uid).listen(
      (groups) {
        if (mounted) {
          setState(() {
            _groups = groups;
          });
        }
      },
      onError: (error) {
        print('Erreur lors du chargement des groupes: $error');
      },
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_searchController.text != _searchQuery) {
        _searchUsers(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _searchDebounce?.cancel();
    
    _chatsSubscription?.cancel();
    _groupsSubscription?.cancel();
    
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchQuery = '';
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searchQuery = query);

    try {
      final results = await _databaseService.searchUsers(query);
      final currentUserId = _authService.currentUser?.uid;

      if (mounted) {
        setState(() {
          _searchResults = results.where((user) => user.uid != currentUserId).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e')),
        );
      }
    }
  }

  void _navigateToChat(UserModel user) async {
    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) return;

      final chatId = await _databaseService.createOrGetChatId(
        currentUserId,
        user.uid,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              receiverUser: user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToUserProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          currentUser: user,
        ),
      ),
    );
  }

  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }

  Future<UserModel?> _getCachedUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    
    try {
      final user = await _databaseService.getUserById(userId);
      if (user != null) {
        _userCache[userId] = user;
      }
      return user;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Veuillez vous connecter'),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          _stopSearch();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Rechercher des utilisateurs...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                )
              : const Text(
                  'Chats',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          leading: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                  onPressed: _stopSearch,
                )
              : null,
          actions: [
            _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _stopSearch,
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: AppTheme.primaryColor),
                  onPressed: _startSearch,
                ),
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.group_add, color: AppTheme.primaryColor),
                onPressed: _navigateToCreateGroup,
                tooltip: 'Créer un groupe',
              ),
          ],
        ),
        body: _isSearching
            ? _buildSearchResults()
            : _buildChatsList(currentUser.uid),
      ),
    );
  }

  Widget _buildChatsList(String currentUserId) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!),
      );
    }

    if (_chats.isEmpty && _groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/empty_chat.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _startSearch,
              child: const Text('Rechercher des utilisateurs'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _setupChatListener();
        _setupGroupsListener();
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 10),
        children: [
          if (_groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Groupes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
            ..._groups.map((group) => _buildGroupListItem(group, currentUserId)),
            const Divider(height: 24),
          ],
          
          if (_chats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Conversations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
            ..._chats.map((chat) => _buildChatListItem(chat, currentUserId)),
          ],
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildGroupListItem(Map<String, dynamic> group, String currentUserId) {
    return ListTile(
      leading: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: group['photoUrl'] != null && group['photoUrl'].isNotEmpty
            ? CachedNetworkImageProvider(group['photoUrl'])
            : null,
        child: group['photoUrl'] == null || group['photoUrl'].isEmpty
            ? const Icon(Icons.group, color: Colors.grey)
            : null,
      ),
      title: Text(
        group['name'] ?? 'Groupe sans nom',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '${(group['members'] as List).length} membres',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: group['id'] as String,
            groupName: group['name'] as String? ?? '',
            groupPhoto: group['photoUrl'] as String? ?? '',
          ),
        ),
        );
      },
    ).animate().fadeIn(duration: 200.ms).slideX(
          begin: 0.05,
          end: 0,
          duration: 200.ms,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return const Center(
        child: Text('Tapez pour rechercher des utilisateurs'),
      );
    }

    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun utilisateur trouvé pour "$_searchQuery"',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: GestureDetector(
            onTap: () => _navigateToUserProfile(user),
            child: CircleAvatar(
              radius: 25,
              backgroundImage: user.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(user.photoUrl)
                  : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
            ),
          ),
          title: Text(
            user.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            user.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: user.isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          onTap: () => _navigateToChat(user),
        ).animate().fadeIn(duration: 300.ms).slideX(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOutQuad,
            );
      },
    );
  }

  Widget _buildChatListItem(
      ChatModel chat,
      String currentUserId,
      ) {
    final otherUserId = chat.participants.firstWhere((id) => id != currentUserId);

    return FutureBuilder<UserModel?>(
      future: _getCachedUser(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 72);
        }

        final otherUser = snapshot.data!;

        return ListTile(
          leading: GestureDetector(
            onTap: () => _navigateToUserProfile(otherUser),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: otherUser.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(otherUser.photoUrl)
                      : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                ),
                if (otherUser.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Text(
            otherUser.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Row(
            children: [
              if (chat.lastMessage.senderId == currentUserId)
                const Icon(
                  Icons.done_all,
                  size: 14,
                  color: Colors.blue,
                ),
              if (chat.lastMessage.senderId == currentUserId)
                const SizedBox(width: 4),
              Expanded(
                child: Text(
                  chat.lastMessage.type == MessageType.text
                      ? chat.lastMessage.content
                      : (chat.lastMessage.type == MessageType.image
                          ? '📷 Image'
                          : '😊 Emoji'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeago.format(chat.lastMessage.timestamp, locale: 'fr'),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              if (!chat.lastMessage.isRead &&
                  chat.lastMessage.senderId != currentUserId)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chat.id,
                  receiverUser: otherUser,
                ),
              ),
            );
          },
        ).animate().fadeIn(duration: 200.ms).slideX(
              begin: 0.05,
              end: 0,
              duration: 200.ms,
              curve: Curves.easeOutQuad,
            );
      },
    );
  }
}