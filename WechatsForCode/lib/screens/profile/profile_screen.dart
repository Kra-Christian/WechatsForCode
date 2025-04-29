import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wecode_by_chat/models/user_model.dart';
import 'package:wecode_by_chat/services/database_service.dart';

import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_button.dart';
import '../../config/theme.dart';
import '../../widgets/loading_indicator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final UserModel? currentUser;

  const ProfileScreen({
    Key? key,
    this.currentUser,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isInitialLoading = false;
  bool _isUpdatingProfile = false;
  bool _isUpdatingImage = false;
  bool _isSigningOut = false;
  
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _statusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_nameController.text.isNotEmpty) return;
    
    try {
      setState(() => _isInitialLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        final userData = await _databaseService.getUserById(user.uid);
        if (userData != null && mounted) {
          setState(() {
            _nameController.text = userData.displayName;
            _statusController.text = userData.status;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur de chargement: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }
  
  Future<void> _updateProfileImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _isUpdatingImage = true);

        final auth = Provider.of<AuthService>(context, listen: false);
        final user = auth.currentUser;

        if (user != null) {
          final imageUrl = await _storageService.uploadProfileImage(
            user.uid,
            File(pickedFile.path),
          );

          await user.updatePhotoURL(imageUrl);

          final userData = await _databaseService.getUserById(user.uid);
          if (userData != null) {
            final updatedUser = userData.copyWith(photoUrl: imageUrl);
            await _databaseService.updateUser(updatedUser);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo de profil mise à jour')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erreur: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingImage = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Le nom ne peut pas être vide';
      });
      return;
    }

    setState(() {
      _isUpdatingProfile = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        final updatedUser = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: _nameController.text.trim(),
          photoUrl: user.photoURL ?? '',
          status: _statusController.text,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        await _databaseService.updateUser(updatedUser);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors de la mise à jour: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Une erreur est survenue'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProfile = false;
        });
      }
    }
  }
  
  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signOut();
            },
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    try {
      setState(() => _isSigningOut = true);

      final authService = Provider.of<AuthService>(context, listen: false);

      final String? userId = authService.currentUser?.uid;

      if (userId != null) {
        try {
          await _databaseService.updateUserStatus(
            userId,
            false,
            lastSeen: DateTime.now(),
          );
        } catch (e) {
          print('Erreur mise à jour statut: $e');
        }
      }

      final navigator = Navigator.of(context);

      await authService.signOutFromAllProviders();

      if (!mounted) return;

      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de déconnexion: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _handleUpdateProfile() {
    if (!_isUpdatingProfile) {
      _updateProfile();
    }
  }

  void _handleUpdateImage() {
    if (!_isUpdatingImage) {
      _updateProfileImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Chargement du profil...'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (_isSigningOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showSignOutConfirmation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  if (_isUpdatingImage)
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.1),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 64,
                      backgroundImage: Provider.of<AuthService>(context).currentUser?.photoURL != null
                          ? NetworkImage(Provider.of<AuthService>(context).currentUser!.photoURL!)
                          : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                    ).animate()
                        .fadeIn(duration: 600.ms)
                        .scale(delay: 200.ms),
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: _isUpdatingImage
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                        onPressed: _isUpdatingImage ? null : _handleUpdateImage,
                        tooltip: 'Changer la photo',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ).animate().shake(),

            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom d\'affichage',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ).animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideX(begin: -0.2, end: 0),

            const SizedBox(height: 16),

            TextField(
              controller: _statusController,
              decoration: InputDecoration(
                labelText: 'Statut',
                prefixIcon: const Icon(Icons.info_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ).animate()
                .fadeIn(delay: 400.ms, duration: 500.ms)
                .slideX(begin: 0.2, end: 0),

            const SizedBox(height: 32),

            CustomButton(
              text: 'Mettre à jour le profil',
              onPressed: _isUpdatingProfile ? () {} : _handleUpdateProfile,
              type: ButtonType.primary,
              icon: _isUpdatingProfile ? null : Icons.save,
              isLoading: _isUpdatingProfile,
            ).animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .scale(),
          ],
        ),
      ),
    );
  }
}