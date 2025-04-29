import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_indicator.dart';
import '../../config/theme.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfAlreadyLoggedIn();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _checkIfAlreadyLoggedIn() {
    final user = Provider.of<User?>(context, listen: false);
    if (user != null) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: AppTheme.mediumAnimationDuration,
      ),
    );
  }

  Future<void> _signInWithMethod(
      Future<void> Function() signInMethod,
      {String errorPrefix = 'Failed to sign in'}
      ) async {
    if (_isLoading) return;

    if (signInMethod == _emailPasswordSignIn && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await signInMethod();
      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$errorPrefix: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _emailPasswordSignIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  Future<void> _googleSignIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInWithGoogle();
  }

  Future<void> _facebookSignIn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInWithFacebook();
  }

  Future<void> _login() => _signInWithMethod(_emailPasswordSignIn);
  Future<void> _loginWithGoogle() => _signInWithMethod(_googleSignIn, errorPrefix: 'Failed to sign in with Google');
  Future<void> _loginWithFacebook() => _signInWithMethod(_facebookSignIn, errorPrefix: 'Failed to sign in with Facebook');

  void _navigateToSignUp() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: AppTheme.mediumAnimationDuration,
      ),
    );
  }

  void _navigateToResetPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const ResetPasswordScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: AppTheme.mediumAnimationDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Connexion en cours...'),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Animate(
                controller: _animationController,
                effects: [
                  FadeEffect(duration: Duration(milliseconds: 600)),
                  ScaleEffect(delay: 200.ms, duration: 400.ms),
                ],
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 60,
                ),
              ),

              const SizedBox(height: 20),

              Animate(
                controller: _animationController,
                effects: [
                  FadeEffect(delay: 300.ms, duration: 600.ms),
                  SlideEffect(begin: const Offset(0, 0.2), end: const Offset(0, 0), delay: 300.ms, duration: 600.ms),
                ],
                child: Text(
                  'Welcome Back!',
                  style: AppTheme.headingStyle.copyWith(color: AppTheme.primaryColor),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 10),

              Animate(
                controller: _animationController,
                effects: [
                  FadeEffect(delay: 400.ms, duration: 600.ms),
                ],
                child: Text(
                  'Sign in to continue',
                  style: AppTheme.captionStyle.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),

              if (_errorMessage != null)
                Animate(
                  effects: const [ShakeEffect(duration: Duration(milliseconds: 300))],
                  child: Container(
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
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 20),

              Form(
                key: _formKey,
                child: Animate(
                  controller: _animationController,
                  effects: const [
                    FadeEffect(duration: Duration(milliseconds: 600)),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _emailController,
                        hint: 'Email Address',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        label: 'Veuillez entrer votre email',
                      ),

                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        label: 'Veuillez entrer votre mot de passe',
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _navigateToResetPassword,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Hero(
                        tag: 'login_button',
                        child: CustomButton(
                          text: 'Login',
                          onPressed: _login,
                          type: ButtonType.primary,
                          icon: Icons.login,
                          isLoading: _isLoading,
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: Colors.grey.shade300, thickness: 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Or continue with',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: Colors.grey.shade300, thickness: 1),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'google_login',
                            child: ElevatedButton(
                              onPressed: _loginWithGoogle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                                elevation: 2,
                              ),
                              child: Image.asset(
                                'assets/images/google_logo.png',
                                height: 24,
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          Hero(
                            tag: 'facebook_login',
                            child: ElevatedButton(
                              onPressed: _loginWithFacebook,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(16),
                                elevation: 2,
                              ),
                              child: Image.asset(
                                'assets/images/facebook_logo.png',
                                height: 24,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account? ',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          GestureDetector(
                            onTap: _navigateToSignUp,
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}