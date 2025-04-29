import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _groupImage;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isSearching = false;
  
  List<UserModel> _searchResults = [];
  final List<UserModel> _selectedUsers = [];
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    if (_searchController.text.length >= 2) {
      _searchUsers(_searchController.text);
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }
  
  Future<void> _searchUsers(String query) async {
    if (query.length < 2) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      final results = await _databaseService.searchUsers(query);
      if (mounted) {
        final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser!.uid;
        
        final filteredResults = results.where((user) => 
          user.uid != currentUserId && 
          !_selectedUsers.any((selected) => selected.uid == user.uid)
        ).toList();
        
        setState(() {
          _searchResults = filteredResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Erreur de recherche: ${e.toString()}';
        });
      }
    }
  }
  
  Future<void> _pickGroupImage() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission d\'accès aux photos refusée')),
      );
      return;
    }
    
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _groupImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de la sélection de l\'image: ${e.toString()}';
        });
      }
    }
  }
  
  void _addUser(UserModel user) {
    if (!_selectedUsers.any((selected) => selected.uid == user.uid)) {
      setState(() {
        _selectedUsers.add(user);
        _searchResults.removeWhere((result) => result.uid == user.uid);
        _searchController.clear();
      });
    }
  }
  
  void _removeUser(UserModel user) {
    setState(() {
      _selectedUsers.removeWhere((selected) => selected.uid == user.uid);
    });
  }
  
  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer un nom pour le groupe';
      });
      return;
    }
    
    if (_selectedUsers.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner au moins un membre pour le groupe';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser!.uid;
      
      String? groupImageUrl;
      if (_groupImage != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        groupImageUrl = await _storageService.uploadChatImage(
          "group_$timestamp",
          _groupImage!
        );
      }
      
      final memberIds = _selectedUsers.map((user) => user.uid).toList();
      await _databaseService.createGroup(
        name: _nameController.text.trim(),
        creatorId: currentUserId,
        memberIds: memberIds,
        description: _descriptionController.text.trim(),
        photoUrl: groupImageUrl,
      );
      
      if (!mounted) return;
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Groupe créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors de la création du groupe: ${e.toString()}';
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _groupImage != null
                          ? FileImage(_groupImage!)
                          : null,
                      child: _groupImage == null
                          ? const Icon(Icons.group, size: 50, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickGroupImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).scale(delay: 100.ms),
              
              const SizedBox(height: 24),
              
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ).animate().shake(),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du groupe',
                  hintText: 'Entrez le nom du groupe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.group),
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  hintText: 'Entrez une description pour le groupe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 2,
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
              
              const SizedBox(height: 24),
              
              Text(
                'Ajouter des membres',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher des utilisateurs...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 16),
              
              if (_searchResults.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'Résultats de recherche',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ...List.generate(
                        _searchResults.length,
                        (index) => ListTile(
                          leading: CircleAvatar(
                            backgroundImage: _searchResults[index].photoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(_searchResults[index].photoUrl)
                                : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                          ),
                          title: Text(_searchResults[index].displayName),
                          subtitle: Text(
                            _searchResults[index].status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                            onPressed: () => _addUser(_searchResults[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 200.ms),
              
              const SizedBox(height: 24),
              
              if (_selectedUsers.isNotEmpty) ...[
                Text(
                  'Membres sélectionnés (${_selectedUsers.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _selectedUsers.map((user) => ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.photoUrl)
                            : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                      ),
                      title: Text(user.displayName),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeUser(user),
                      ),
                    )).toList(),
                  ),
                ).animate().fadeIn(duration: 200.ms),
              ],
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Créer le groupe',
                onPressed: _isLoading ? () {} : () => _createGroup(),
                type: ButtonType.primary,
                icon: Icons.group_add,
                isLoading: _isLoading,
              ).animate().fadeIn(delay: 500.ms).scale(),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
