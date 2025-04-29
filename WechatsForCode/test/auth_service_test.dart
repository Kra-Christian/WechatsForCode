import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wecode_by_chat/services/auth_service.dart';
import 'package:wecode_by_chat/services/database_service.dart';

// Créer les mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockDatabaseService mockDatabaseService;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockDatabaseService = MockDatabaseService();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    authService = AuthService();
    
    // Configurer les mocks
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-uid');
    when(mockUser.email).thenReturn('test@example.com');
  });

  group('AuthService', () {
    test('signInWithEmailAndPassword should succeed with valid credentials', () async {
      // Arrange
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockUserCredential);

      // Act
      final result = await authService.signInWithEmailAndPassword(
        'test@example.com',
        'password123',
      );

      // Assert
      expect(result, mockUserCredential);
      verify(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });

    test('signInWithEmailAndPassword should throw with invalid credentials', () {
      // Arrange
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'invalid@example.com',
        password: 'wrongpassword',
      )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      // Act & Assert
      expect(
        () => authService.signInWithEmailAndPassword(
          'invalid@example.com',
          'wrongpassword',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('signOut should update user status and sign out', () async {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async => null);

      // Act
      await authService.signOut();

      // Assert
      verify(mockDatabaseService.updateUserStatus(
        mockUser.uid,
        false,
        lastSeen: DateTime.now(),
      )).called(1);
      verify(mockFirebaseAuth.signOut()).called(1);
    });
  });
}