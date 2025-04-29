import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _resetSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resetPassword(_emailController.text.trim());
      
      if (!mounted) return;
      
      setState(() {
        _resetSent = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send reset email: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _resetSent ? _buildSuccessContent() : _buildResetForm(),
        ),
      ),
    );
  }
  
  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reset Password Text
        Text(
          'Reset Password',
          style: AppTheme.headingStyle.copyWith(color: AppTheme.primaryColor),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2, end: 0, duration: 600.ms),
        
        const SizedBox(height: 10),
        
        Text(
          'Enter your email address and we\'ll send you a link to reset your password',
          style: AppTheme.captionStyle.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 100.ms, duration: 600.ms),
        
        const SizedBox(height: 30),
        
        // Error Message
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
          ).animate().shake(delay: 100.ms, duration: 300.ms),
        
        if (_errorMessage != null) const SizedBox(height: 20),
        
        // Reset Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
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
                label: 'champs disponible',
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              
              const SizedBox(height: 32),
              
              // Reset Button
              CustomButton(
                text: 'Send Reset Link',
                onPressed: _resetPassword,
                type: ButtonType.primary,
                icon: Icons.send_outlined,
                isLoading: _isLoading,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              
              const SizedBox(height: 24),
              
              // Back to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Remember your password? ',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 100,
        ).animate()
          .fadeIn(duration: 600.ms)
          .scale(delay: 200.ms, duration: 400.ms),
          
        const SizedBox(height: 24),
        
        Text(
          'Reset Link Sent',
          style: AppTheme.headingStyle.copyWith(color: AppTheme.primaryColor),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 300.ms, duration: 500.ms),
          
        const SizedBox(height: 16),
        
        Text(
          'We\'ve sent a password reset link to ${_emailController.text}. Please check your email inbox.',
          style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 400.ms, duration: 500.ms),
          
        const SizedBox(height: 40),
        
        CustomButton(
          text: 'Back to Login',
          onPressed: () => Navigator.pop(context),
          type: ButtonType.outline,
          icon: Icons.arrow_back,
        ).animate()
          .fadeIn(delay: 500.ms, duration: 500.ms),
      ],
    );
  }
}