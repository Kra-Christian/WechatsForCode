import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    final user = Provider.of<User?>(context, listen: false);
    
    if (user != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'app_logo',
              child: SizedBox(
                height: 200,
                width: 200,
                child: Lottie.asset(
                  'assets/animations/chat_animation.json',
                  animate: true,
                  repeat: true,
                ),
              ),
            ).animate()
              .fadeIn(duration: 400.ms)
              .scale(delay: 100.ms, duration: 300.ms),
            
            const SizedBox(height: 40),
            
            Text(
              'Chat App',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                letterSpacing: 1.2,
              ),
            ).animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.3, end: 0, delay: 300.ms, duration: 400.ms)
              .then()
              .shimmer(delay: 100.ms, duration: 600.ms),
            
            const SizedBox(height: 16),
            
            Text(
              'Connect with friends easily',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ).animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),
              
            const SizedBox(height: 60),
            
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 3,
            ).animate()
              .fadeIn(delay: 500.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}