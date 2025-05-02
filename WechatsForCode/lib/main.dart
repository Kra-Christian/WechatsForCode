import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:wecode_by_chat/screens/auth/login_screen.dart';
import 'package:wecode_by_chat/screens/auth/signup_screen.dart';
import 'package:wecode_by_chat/screens/home/home_screen.dart';
import 'package:wecode_by_chat/screens/profile/profile_screen.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/storage_service.dart';
import 'config/theme.dart';

late final AuthService _authService;
late final DatabaseService _databaseService;
late final StorageService _storageService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAppCheck.instance.activate(
    appleProvider: AppleProvider.debug,
    androidProvider: AndroidProvider.playIntegrity,
  );
  
  if (Platform.isAndroid) {
    await FacebookAuth.i.autoLogAppEventsEnabled(true);
  }
  
  _authService = AuthService();
  _databaseService = DatabaseService();
  _storageService = StorageService();
  
  _databaseService.createRequiredIndexes().catchError((error) {
    debugPrint('Failed to create indexes: $error');
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(
          value: _authService,
        ),
        StreamProvider<User?>(
          create: (_) => _authService.authStateChanges,
          initialData: null,
        ),
        Provider<DatabaseService>.value(
          value: _databaseService,
        ),
        Provider<StorageService>.value(
          value: _storageService,
        ),
      ],
      child: MaterialApp(
        title: 'Wecode For Chat',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}