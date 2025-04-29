import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<Widget> _screens;
  UserModel? _currentUser;
  bool _isLoading = true;
  final _pageController = PageController();
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initializeBasicScreens();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _updateUserStatusOffline();
    super.dispose();
  }

  void _initializeBasicScreens() {
    _screens = [
      const ChatListScreen(),
      const ProfileScreen(),
    ];
  }

  void _updateScreens() {
    if (_currentUser != null) {
      _screens = [
        const ChatListScreen(),
        ProfileScreen(currentUser: _currentUser!),
      ];
    }
  }

  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      if (authService.currentUser != null) {
        final userId = authService.currentUser!.uid;

        databaseService.updateUserStatus(userId, true, lastSeen: DateTime.now())
            .catchError((e) => print('Error updating online status: $e'));

        final user = await databaseService.getUserById(userId);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _updateScreens();
            _isLoading = false;
          });

          _fadeController.forward();
          _slideController.forward();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _fadeController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        _fadeController.forward();
        _slideController.forward();
      }
    }
  }

  Future<void> _updateUserStatusOffline() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      if (authService.currentUser != null) {
        await databaseService.updateUserStatus(
          authService.currentUser!.uid,
          false,
          lastSeen: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error updating offline status: $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 80,
              ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),

              const SizedBox(height: 24),

              const LoadingIndicator(message: 'Chargement...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeController,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
              physics: const BouncingScrollPhysics(),
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutQuart,
            )),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              backgroundColor: Colors.white,
              selectedItemColor: AppTheme.primaryColor,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              elevation: 10,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Discussions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}