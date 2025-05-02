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
        _errorMessage = 'Échec de l\'envoi de l\'email de réinitialisation: ${e.toString()}';
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
        Text(
          'Réinitialiser le mot de passe',
          style: AppTheme.headingStyle.copyWith(color: AppTheme.primaryColor),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: 0.2, end: 0, duration: 600.ms),
        
        const SizedBox(height: 10),
        
        Text(
          'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe',
          style: AppTheme.captionStyle.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 100.ms, duration: 600.ms),
        
        const SizedBox(height: 30),
        
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
        
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _emailController,
                hint: 'Adresse email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir votre email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Veuillez saisir une adresse email valide';
                  }
                  return null;
                },
                label: 'Champs disponible',
              ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              
              const SizedBox(height: 32),
              
              CustomButton(
                text: 'Envoyer le lien de réinitialisation',
                onPressed: _resetPassword,
                type: ButtonType.primary,
                icon: Icons.send_outlined,
                isLoading: _isLoading,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'le mot de passe est revenue ? ',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Connexion',
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
          'Lien de réinitialisation envoyé',
          style: AppTheme.headingStyle.copyWith(color: AppTheme.primaryColor),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 300.ms, duration: 500.ms),
          
        const SizedBox(height: 16),
        
        Text(
          'Nous avons envoyé un lien de réinitialisation de mot de passe à ${_emailController.text}. Veuillez vérifier votre boîte de réception.',
          style: AppTheme.bodyStyle.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ).animate()
          .fadeIn(delay: 400.ms, duration: 500.ms),
          
        const SizedBox(height: 40),
        
        CustomButton(
          text: 'Retour à la connexion',
          onPressed: () => Navigator.pop(context),
          type: ButtonType.outline,
          icon: Icons.arrow_back,
        ).animate()
          .fadeIn(delay: 500.ms, duration: 500.ms),
      ],
    );
  }
}